import QtQuick
import "theme"

// Suspend / Restart / Power off icons for a corner of the lock and login screens (the greeter
// gets a copy, so this file only depends on the theme). Clicking a button, or
// Tab to it and Enter, arms it (red); doing it again within 3 s emits requested().
Row {
    id: root

    signal requested(string action)
    property string armed: ""

    spacing: 8

    Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }

    Repeater {
        model: [
            { "action": "suspend", "icon": 0xf0904 },
            { "action": "reboot", "icon": 0xf0709 },
            { "action": "poweroff", "icon": 0xf0425 }
        ]

        delegate: Rectangle {
            id: button
            required property var modelData
            readonly property bool armed: root.armed === modelData.action

            function press() {
                if (armed) {
                    root.armed = ""
                    disarm.stop()
                    root.requested(modelData.action)
                } else {
                    root.armed = modelData.action
                    disarm.restart()
                }
            }

            width: 36
            height: 36
            activeFocusOnTab: true
            color: Theme.controlBackground(false, activeFocus, hover.hovered)
            border.width: 1
            border.color: armed ? Theme.red : Theme.controlBorder(false, activeFocus, hover.hovered)

            Text {
                anchors.centerIn: parent
                text: String.fromCodePoint(button.modelData.icon)
                color: button.armed ? Theme.red : button.activeFocus || hover.hovered ? Theme.fg : Theme.grey2
                font.family: Theme.nerdFontFamily
                font.pixelSize: 18
            }

            HoverHandler { id: hover }
            TapHandler { onTapped: button.press() }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                    button.press()
                else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                    nextItemInFocusChain(event.key === Qt.Key_Tab).forceActiveFocus()
                else return
                event.accepted = true
            }
        }
    }
}
