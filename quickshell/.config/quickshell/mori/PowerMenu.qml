import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./theme"

Item {
    id: root
    implicitWidth: powerIcon.implicitWidth
    implicitHeight: powerIcon.implicitHeight
    required property var panelWindow
    required property var popupCoordinator
    property int heldActionKey: 0

    function toggle() {
        if (menu.visible)
            close()
        else {
            popupCoordinator.showPopup(root)
            menu.visible = true
        }
    }

    function close() { menu.visible = false }

    function runAction(command) {
        heldActionKey = 0
        menu.visible = false
        actionProcess.exec(command)
    }

    function handleKeyPressed(event) {
        if (event.isAutoRepeat)
            return

        const actionKeys = [Qt.Key_L, Qt.Key_X, Qt.Key_S, Qt.Key_R, Qt.Key_P]
        if (actionKeys.indexOf(event.key) !== -1) {
            heldActionKey = event.key
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            close()
            event.accepted = true
        }
    }

    function handleKeyReleased(event) {
        if (!event.isAutoRepeat && heldActionKey === event.key) {
            heldActionKey = 0
            event.accepted = true
        }
    }

    Process {
        id: actionProcess
    }

    Text {
        id: powerIcon
        anchors.centerIn: parent
        text: String.fromCodePoint(0xf0425)
        color: Theme.red
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize

        TapHandler {
            onTapped: root.toggle()
        }
    }

    PopupWindow {
        id: menu
        implicitWidth: 150
        implicitHeight: menuItems.implicitHeight + 24
        visible: false
        color: "transparent"
        grabFocus: false
        onVisibleChanged: {
            if (!visible) {
                root.heldActionKey = 0
                root.popupCoordinator.hidePopup(root)
            }
        }

        anchor.window: root.panelWindow
        anchor.rect {
            x: root.x + root.width / 2 + menu.implicitWidth / 2
            y: parentWindow.height + 6
            width: 1
            height: 1
        }
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left

        PopupSurface {
            id: menuSurface
            anchors.fill: parent
            shown: menu.visible
            radius: 0
            color: Theme.bg1
            border.width: 2
            border.color: Theme.fg

            Column {
                id: menuItems
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 8

                Repeater {
                    model: [
                        { label: "Lock", shortcut: "L", key: Qt.Key_L, command: ["loginctl", "lock-session"] },
                        { label: "Log out", shortcut: "X", key: Qt.Key_X, command: ["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""] },
                        { label: "Suspend", shortcut: "S", key: Qt.Key_S, command: ["systemctl", "suspend"] },
                        { label: "Restart", shortcut: "R", key: Qt.Key_R, command: ["systemctl", "reboot"] },
                        { label: "Power off", shortcut: "P", key: Qt.Key_P, command: ["systemctl", "poweroff"] }
                    ]

                    delegate: Item {
                        required property var modelData
                        property real holdProgress: 0
                        width: menuItems.width
                        implicitHeight: 20

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * parent.holdProgress
                            color: modelData.label === "Power off" ? Theme.bgred : Theme.bg4
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: modelData.label === "Power off" ? Theme.red : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.shortcut
                            color: modelData.label === "Power off" ? Theme.red : Theme.grey1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        Timer {
                            id: holdTimer
                            interval: 25
                            repeat: true
                            running: (buttonArea.pressed && buttonArea.containsMouse)
                                     || (menu.visible && root.heldActionKey === parent.modelData.key)

                            onRunningChanged: {
                                if (!running && parent.holdProgress < 1)
                                    parent.holdProgress = 0
                            }

                            onTriggered: {
                                parent.holdProgress = Math.min(1, parent.holdProgress + interval / 800)
                                if (parent.holdProgress === 1) {
                                    stop()
                                    const command = parent.modelData.command
                                    parent.holdProgress = 0
                                    root.runAction(command)
                                }
                            }
                        }

                        MouseArea {
                            id: buttonArea
                            anchors.fill: parent
                            onPressed: parent.holdProgress = 0
                            onReleased: parent.holdProgress = 0
                            onCanceled: parent.holdProgress = 0
                            onExited: if (pressed) parent.holdProgress = 0
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: dismissLayer
        visible: menu.visible
        anchors { top: true; bottom: true; left: true; right: true }
        margins.top: root.panelWindow.height
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => keyCapture.forceActiveFocus())
        }

        Item {
            id: keyCapture
            anchors.fill: parent
            focus: dismissLayer.visible

            Keys.onPressed: event => root.handleKeyPressed(event)
            Keys.onReleased: event => root.handleKeyReleased(event)

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }
    }
}
