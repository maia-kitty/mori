import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "./theme"

// Mori's lock screen. lock(): screenshot every monitor (grim, at most
// 500 ms), lock the session, and dissolve the screenshots into Kiri fog.
// The right password plays the fog backwards and only then unlocks.
// preview(): the same screen in an overlay that locks nothing (Escape closes).
// If the session lock isn't confirmed within 2 s, swaylock takes over, so a
// failure here never leaves the session unlocked. A marker file in the runtime
// dir survives shell restarts: a reload or crash while locked leaves Niri
// locked with nothing to unlock it, so the next shell locks again at once.
Scope {
    id: root

    required property var settings

    property string state: "idle"   // idle, capturing, locked, unlocking
    property bool previewing: false
    property real progress: 0
    property real seed: 0
    property bool arcs: false
    property string password: ""
    property bool checking: false
    property bool failed: false
    property string message: ""
    property int serial: 0
    // The clock and password field show on one monitor: the focused one at
    // lock time; clicking another monitor moves them there.
    property string cardScreen: ""
    readonly property bool unlocking: state === "unlocking"
    readonly property bool showing: state === "locked" || state === "unlocking"
    readonly property string shotDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    function screenshotFor(screen) {
        return screen
            ? "file://" + shotDir + "/mori-lock-" + screen.name + ".ppm?" + serial : ""
    }

    function lock() { start(false) }
    readonly property string markerPath: shotDir + "/mori-lock-active"
    function preview() { start(true) }

    function start(asPreview, recovering) {
        if (state !== "idle") {
            // A real lock must not be dropped behind a preview or the unlock
            // animation: end that first. Anything else is already locking.
            if (asPreview || !(previewing || state === "unlocking")) return
            finish()
        }
        previewing = asPreview
        seed = Math.random()
        arcs = Math.random() < 0.5
        password = ""
        failed = false
        message = ""
        progress = 0
        serial++
        cardScreen = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
        if (!focusQuery.running) focusQuery.exec(["niri", "msg", "--json", "focused-output"])
        state = "capturing"
        if (!asPreview) marker.setText("locked\n")
        if (recovering) {
            // The screen behind is Niri's empty lock; skip the screenshot.
            show()
            return
        }
        grim.exec(["sh", "-c", "for o in \"$@\"; do grim -t ppm -o \"$o\" \"$0/mori-lock-$o.ppm\" & done; wait",
            shotDir].concat(Quickshell.screens.map(screen => screen.name)))
        captureTimeout.restart()
    }

    function show() {
        if (state !== "capturing") return
        captureTimeout.stop()
        state = "locked"
        if (!previewing) secureCheck.restart()
        dissolve.start()
    }

    function submit() {
        if (state !== "locked" || checking) return
        if (password.length === 0) return
        checking = true
        message = ""
        if (!pam.start()) {
            checking = false
            failed = true
            message = "Couldn't start the password check"
        }
    }

    // Escape ends the preview (playing the unlock animation); the real lock
    // only clears the field.
    function handleEscape() {
        if (checking) cancelCheck("")
        else if (previewing && state === "locked") unlockNow()
        else {
            password = ""
            failed = false
        }
    }

    // Suspend, reboot or power off from the lock screen's buttons.
    function power(action) {
        if (previewing) {
            failed = false
            message = "Preview: " + action + " not run"
        } else
            Quickshell.execDetached(["mori-power", action])
    }

    // Give up on a password check that is still running (Escape, or it took too long).
    function cancelCheck(text) {
        pam.abort()
        checking = false
        password = ""
        failed = text.length > 0
        message = text
    }

    function unlockNow() {
        state = "unlocking"
        dissolve.stop()
        undissolve.from = progress
        undissolve.start()
    }

    function finish() {
        if (!previewing) marker.setText("")
        dissolve.stop()
        undissolve.stop()
        // `locked` follows `state` through its binding; never assign it here.
        state = "idle"
        previewing = false
        password = ""
        checking = false
        progress = 0
    }

    FileView {
        id: marker
        path: root.markerPath
        blockLoading: true
        printErrors: false
    }
    Component.onCompleted: {
        if (marker.text().trim() === "locked") {
            console.warn("Shell restarted while locked; locking again")
            start(false, true)
        }
    }

    Process {
        id: grim
        onExited: root.show()
    }
    Process {
        id: focusQuery
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const output = JSON.parse(this.text)
                    if (Quickshell.screens.some(screen => screen.name === output.name))
                        root.cardScreen = output.name
                } catch (error) {}
            }
        }
    }
    // Never hold up the lock: without screenshots the fog starts from black.
    Timer { id: captureTimeout; interval: 500; onTriggered: root.show() }

    // Lock as soon as the screenshots are in; nothing waits on the animation.
    WlSessionLock {
        id: sessionLock
        locked: root.showing && !root.previewing

        WlSessionLockSurface {
            id: lockWindow
            color: Theme.bg
            LockSurface {
                anchors.fill: parent
                lock: root
                screen: lockWindow.screen
                settings: root.settings
            }
        }
    }

    Timer {
        id: secureCheck
        interval: 2000
        onTriggered: {
            if (root.state === "locked" && !root.previewing && !sessionLock.secure) {
                console.warn("Session lock not confirmed; starting swaylock")
                Quickshell.execDetached(["sh", "-c", "pgrep -x swaylock >/dev/null || exec swaylock"])
                root.finish()
            }
        }
    }

    NumberAnimation {
        id: dissolve
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 3000
        easing.type: Easing.OutQuint
    }
    NumberAnimation {
        id: undissolve
        target: root
        property: "progress"
        to: 0
        duration: 1400
        easing.type: Easing.InOutCubic
        onFinished: root.finish()
    }

    // Long enough for a fingerprint reader to give up and ask for the password.
    Timer {
        interval: 30000
        running: root.checking
        onTriggered: root.cancelCheck("Password check timed out")
    }

    PamContext {
        id: pam
        // Every prompt gets the password (a stack may ask more than once); anything
        // else PAM says, like a fingerprint reader's instructions, is shown.
        onPamMessage: {
            if (responseRequired) respond(root.password)
            else if (message) root.message = message
        }
        onCompleted: result => {
            if (!root.checking) return // cancelled meanwhile
            root.checking = false
            if (result === PamResult.Success) {
                root.message = ""
                root.unlockNow()
            } else {
                root.failed = true
                root.password = ""
                root.message = "Wrong password"
            }
        }
        onError: error => {
            if (!root.checking) return
            root.checking = false
            root.failed = true
            root.password = ""
            root.message = "Password check failed: " + PamError.toString(error)
        }
    }

    // Preview: the same surfaces in overlay windows, without locking.
    LazyLoader {
        active: root.previewing && root.showing

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: previewWindow
                required property var modelData
                screen: modelData
                color: Theme.bg
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "mori-lock-preview"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                LockSurface {
                    anchors.fill: parent
                    lock: root
                    screen: previewWindow.modelData
                    settings: root.settings
                    }
            }
        }
    }
}
