import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import "theme"

// Mori's login screen (greetd). The last wallpaper sits under settled Kiri fog;
// logging in plays the fog backwards to the sharp wallpaper, then starts Niri,
// which shows the same wallpaper. State shared with the session lives in
// /var/lib/mori-greeter: mode and wallpapers (written by mori-greeter-sync) and
// last-user (written here).
// Run outside greetd it is a preview: any password works except "wrong".
ShellRoot {
    id: root

    readonly property string stateDir: Quickshell.env("MORI_GREETER_STATE") || "/var/lib/mori-greeter"
    readonly property bool preview: !Greetd.available
    property string user: lastUser.text().trim()
    property string password: ""
    property bool busy: false
    property bool failed: false
    property string message: ""
    property bool leaving: false
    property string cardScreen: ""
    property real progress: 1
    property real seed: Math.random()
    readonly property bool arcs: seed < 0.5
    property var wallpapers: ({})

    function wallpaperFor(screen) {
        const file = screen ? wallpapers[screen.name] : ""
        return file ? "file://" + stateDir + "/" + file : ""
    }

    function submit() {
        if (busy || leaving) return
        if (!user.trim()) {
            failed = true
            message = "Enter a user name"
            return
        }
        busy = true
        failed = false
        message = ""
        if (preview) {
            previewCheck.restart()
            return
        }
        Greetd.createSession(user.trim())
    }

    function loginFailed(text) {
        busy = false
        failed = true
        password = ""
        message = text
        if (!preview) Greetd.cancelSession()
    }

    // The buttons under the login card. mori-power is copied next to this file.
    function power(action) {
        if (preview) {
            failed = false
            message = "Preview: " + action + " not run"
        } else
            Quickshell.execDetached([Quickshell.shellDir + "/mori-power", action])
    }

    function loggedIn() {
        busy = false
        lastUser.setText(user.trim() + "\n")
        leaving = true
        reveal.start()
    }

    // "12h" or "24h", copied from the session's clock setting.
    FileView {
        id: clockFormat
        path: root.stateDir + "/clock"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: lastUser
        path: root.stateDir + "/last-user"
        blockLoading: true
        printErrors: false
    }

    // "output<TAB>file" per line, kept by mori-greeter-sync.
    FileView {
        id: wallpaperIndex
        path: root.stateDir + "/wallpapers"
        blockLoading: true
        printErrors: false
        onLoaded: {
            const map = {}
            for (const line of text().split("\n")) {
                const tab = line.indexOf("\t")
                if (tab > 0) map[line.slice(0, tab)] = line.slice(tab + 1)
            }
            root.wallpapers = map
        }
    }

    Process {
        id: focusQuery
        running: true
        command: ["niri", "msg", "--json", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const output = JSON.parse(this.text)
                    root.cardScreen = output.name || ""
                } catch (error) {}
                if (!root.cardScreen && Quickshell.screens.length > 0)
                    root.cardScreen = Quickshell.screens[0].name
            }
        }
    }

    Connections {
        target: Greetd
        function onAuthMessage(text, error, responseRequired, echoResponse) {
            if (responseRequired) Greetd.respond(root.password)
            else if (error) root.message = text
        }
        function onAuthFailure(text) { root.loginFailed("Wrong password") }
        function onReadyToLaunch() { root.loggedIn() }
        function onError(text) { root.loginFailed(text) }
    }

    Timer {
        id: previewCheck
        interval: 400
        onTriggered: root.password === "wrong" ? root.loginFailed("Wrong password") : root.loggedIn()
    }

    NumberAnimation {
        id: reveal
        target: root
        property: "progress"
        to: 0
        duration: 1400
        easing.type: Easing.InOutCubic
        onFinished: {
            if (root.preview) Qt.quit()
            // mori-session (copied next to this file) picks niri-session or a plain
            // D-Bus session, so the same login screen works with and without systemd.
            else Greetd.launch([Quickshell.shellDir + "/mori-session"], ["XDG_SESSION_TYPE=wayland"], true)
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window
            required property var modelData
            readonly property bool hasCard: root.cardScreen === modelData.name
            screen: modelData
            color: "black"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "mori-greeter"
            WlrLayershell.keyboardFocus: hasCard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            KiriEffect {
                anchors.fill: parent
                image: root.wallpaperFor(window.modelData)
                progress: root.progress
                seed: root.seed
                arcs: root.arcs
                // Fade in from black at boot.
                opacity: 0
                NumberAnimation on opacity { to: 1; duration: 900; easing.type: Easing.OutCubic }
            }

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            Column {
                id: card
                anchors.centerIn: parent
                spacing: 14
                visible: window.hasCard
                opacity: root.leaving ? Math.max(0, (root.progress - 0.5) / 0.5) : 1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(clock.date, clockFormat.text().trim() === "12h" ? "h:mm AP" : "HH:mm")
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 72
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(clock.date, "dddd, d MMMM")
                    color: Theme.grey2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                }

                Repeater {
                    model: [false, true]
                    delegate: Rectangle {
                        id: field
                        required property bool modelData
                        readonly property bool isPassword: modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 320
                        height: Theme.controlHeight + 8
                        color: Theme.bg1
                        border.width: input.activeFocus ? 2 : 1
                        border.color: root.failed && isPassword ? Theme.red : input.activeFocus ? Theme.fg : Theme.bg4

                        TextInput {
                            id: input
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignHCenter
                            clip: true
                            activeFocusOnTab: true
                            echoMode: field.isPassword ? TextInput.Password : TextInput.Normal
                            passwordCharacter: "•"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 2
                            enabled: !root.busy && !root.leaving
                            text: field.isPassword ? root.password : root.user
                            onTextEdited: {
                                if (field.isPassword) root.password = text
                                else root.user = text
                                root.failed = false
                            }
                            // Start in the password field when the last user is known. The
                            // card's monitor is only known once Niri answers.
                            function takeFocus() {
                                if (window.hasCard && field.isPassword === (root.user.length > 0))
                                    Qt.callLater(() => input.forceActiveFocus())
                            }
                            Component.onCompleted: takeFocus()
                            Connections {
                                target: window
                                function onHasCardChanged() { input.takeFocus() }
                            }
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (!field.isPassword) nextItemInFocusChain().forceActiveFocus()
                                    else root.submit()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                    nextItemInFocusChain(event.key === Qt.Key_Tab).forceActiveFocus()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Escape && root.preview) {
                                    Qt.quit()
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: input.text.length === 0
                            text: field.isPassword ? (root.busy ? "Checking…" : "Password") : "User"
                            color: Theme.grey1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 2
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.message || "Tab: next field · Enter: log in"
                    color: root.failed ? Theme.red : Theme.grey1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }

            PowerButtons {
                anchors { right: parent.right; bottom: parent.bottom; margins: 24 }
                visible: card.visible
                opacity: card.opacity
                onRequested: action => root.power(action)
            }

            // Clicking a monitor brings the login card there.
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: root.cardScreen = window.modelData.name
            }
        }
    }
}
