import QtQuick
import Quickshell
import "./theme"

// One monitor of the lock screen: the screenshot dissolving into Kiri fog,
// with the clock and password card on top. Used by the real lock surface and
// by the preview window, so both look the same.
Item {
    id: root

    required property var lock        // LockScreen.qml
    required property var screen
    required property var settings
    readonly property alias passwordField: input
    readonly property bool hasCard: !!screen && lock.cardScreen === screen.name
    onHasCardChanged: if (hasCard) Qt.callLater(() => input.forceActiveFocus())

    KiriEffect {
        anchors.fill: parent
        image: root.lock.screenshotFor(root.screen)
        progress: root.lock.progress
        seed: root.lock.seed
        arcs: root.lock.arcs
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // The card fades in once the fog has mostly settled, and out on unlock.
    Column {
        id: card
        anchors.centerIn: parent
        spacing: 14
        opacity: root.hasCard ? Math.max(0, Math.min(1, (root.lock.progress - 0.35) / 0.3)) : 0
        visible: opacity > 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, root.settings.clockTimeFormat === "12h" ? "h:mm AP" : "HH:mm")
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

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            height: Theme.controlHeight + 8
            color: Theme.bg1
            border.width: 2
            border.color: root.lock.failed ? Theme.red : Theme.fg

            TextInput {
                id: input
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                clip: true
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                enabled: !root.lock.checking && !root.lock.unlocking
                activeFocusOnTab: true
                // One password for every monitor.
                text: root.lock.password
                onTextEdited: {
                    root.lock.password = text
                    root.lock.failed = false
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.lock.submit()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        root.lock.handleEscape()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        nextItemInFocusChain(event.key === Qt.Key_Tab).forceActiveFocus()
                        event.accepted = true
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: input.text.length === 0
                text: root.lock.checking ? "Checking…" : "Password"
                color: Theme.grey1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.lock.message
            visible: text.length > 0
            color: root.lock.failed ? Theme.red : Theme.grey1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    // Also the way out if the password check ever hangs.
    PowerButtons {
        anchors { right: parent.right; bottom: parent.bottom; margins: 24 }
        opacity: card.opacity
        visible: card.visible
        onRequested: action => root.lock.power(action)
    }

    // Clicking a monitor brings the clock and password field there.
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            if (root.screen) root.lock.cardScreen = root.screen.name
            input.forceActiveFocus()
        }
    }
}
