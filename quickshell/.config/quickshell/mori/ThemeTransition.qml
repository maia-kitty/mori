import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./theme"

// Crossfades a light/dark switch: freeze every output on a screenshot, let
// mori-theme repaint everything underneath, then fade the screenshot out.
// Screenshots come from grim, not ScreencopyView: ScreencopyView binds its own
// wl_output, and the surface enter events for it crash Qt's Wayland client
// (Quickshell 0.3.2 / Qt 6.12). Without grim the switch just isn't faded.
Scope {
    id: root

    property bool busy: false
    // The overlay windows stay a few seconds after a fade so quick switches reuse them.
    property bool windowsActive: false
    property string mode: ""
    property int ready: 0
    property int serial: 0
    property real shotOpacity: 0
    readonly property string shotDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    signal capture()

    function switchTo(requested) {
        const next = requested === "toggle" ? (Theme.dark ? "light" : "dark") : requested
        if (busy || (next !== "dark" && next !== "light")) return
        mode = next
        ready = 0
        serial++
        shotOpacity = 0
        busy = true
        linger.stop()
        if (windowsActive) capture()
        else windowsActive = true // new windows capture once they exist
        captureTimeout.restart()
    }

    function shotReady() {
        ready++
        if (ready >= Quickshell.screens.length) startSwitch(true)
    }

    function startSwitch(shown) {
        if (!busy || switcher.running || hold.running || fade.running) return
        captureTimeout.stop()
        shotOpacity = shown ? 1 : 0
        switcher.running = true
    }

    Process {
        id: switcher
        command: ["mori-theme", root.mode]
        environment: ({ "MORI_THEME_DIRECT": "1" })
        // Apps repaint a moment after mori-theme exits (portal signals, Zen's chrome).
        onExited: hold.restart()
    }

    // No screenshot in time (no grim, slow GPU): switch without the fade.
    Timer { id: captureTimeout; interval: 600; onTriggered: root.startSwitch(false) }
    Timer { id: hold; interval: 300; onTriggered: fade.start() }
    Timer { id: linger; interval: 3000; onTriggered: root.windowsActive = false }

    NumberAnimation {
        id: fade
        target: root
        property: "shotOpacity"
        to: 0
        duration: 500
        easing.type: Easing.InOutQuad
        onFinished: {
            root.busy = false
            linger.restart()
            // The images are loaded; don't leave the desktop's screenshots in RAM.
            Quickshell.execDetached(["sh", "-c", "rm -f \"$0\"/mori-theme-*.ppm", root.shotDir])
        }
    }

    LazyLoader {
        active: root.windowsActive

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: overlay
                required property var modelData
                readonly property string shotPath: root.shotDir + "/mori-theme-" + modelData.name + ".ppm"
                screen: modelData
                color: "transparent"
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "mori-theme-fade"
                // Clicks go to the windows underneath while the frame is up.
                mask: Region {}

                Component.onCompleted: grim.running = true

                Process {
                    id: grim
                    // PPM skips compression; the file lives in the runtime tmpfs.
                    command: ["grim", "-t", "ppm", "-o", overlay.modelData.name, overlay.shotPath]
                    onExited: code => {
                        if (code === 0) shot.source = "file://" + overlay.shotPath + "?" + root.serial
                    }
                }

                Connections {
                    target: root
                    function onCapture() { grim.running = true }
                }

                Image {
                    id: shot
                    anchors.fill: parent
                    cache: false
                    asynchronous: true
                    opacity: root.shotOpacity
                    onStatusChanged: if (status === Image.Ready) root.shotReady()
                }
            }
        }
    }
}
