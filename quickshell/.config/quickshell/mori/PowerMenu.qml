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
    property color accent: Theme.red
    property int heldActionKey: 0
    property int selectedActionIndex: 0
    property bool heldEnter: false
    property var resolvedActions: ({})
    property bool resolving: false
    property bool actionPending: false
    property string errorMessage: ""

    function toggle() {
        if (menu.visible)
            close()
        else {
            popupCoordinator.showPopup(root)
            selectedActionIndex = 0
            menu.visible = true
            refreshActions()
        }
    }

    function close() { menu.visible = false }

    function refreshActions() {
        errorMessage = ""
        resolvedActions = ({})
        if (resolveProcess.running)
            return
        resolving = true
        resolveProcess.exec(["mori-power", "--resolve"])
    }

    function actionAvailable(action) {
        if (actionPending)
            return false
        if (!action.action)
            return true
        const resolved = resolvedActions[action.action]
        return !resolving && !!resolved && resolved.command.length > 0
    }

    function reportFailure(message) {
        errorMessage = message
        popupCoordinator.showPopup(root)
        menu.visible = true
    }

    function runAction(action) {
        if (!actionAvailable(action))
            return
        heldActionKey = 0
        heldEnter = false
        menu.visible = false
        errorMessage = ""
        actionPending = true
        actionProcess.exec(action.action ? ["mori-power", action.action] : action.command)
    }

    function handleKeyPressed(event) {
        const actionKeys = [Qt.Key_L, Qt.Key_X, Qt.Key_S, Qt.Key_R, Qt.Key_P]
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            heldEnter = false
            heldActionKey = 0
            selectedActionIndex = Math.max(0, Math.min(powerActions.count - 1,
                selectedActionIndex + (event.key === Qt.Key_Up ? -1 : 1)))
            event.accepted = true
        } else if (event.isAutoRepeat) {
            return
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            heldActionKey = 0
            heldEnter = true
            event.accepted = true
        } else if (actionKeys.indexOf(event.key) !== -1) {
            heldEnter = false
            heldActionKey = event.key
            selectedActionIndex = actionKeys.indexOf(event.key)
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            close()
            event.accepted = true
        }
    }

    function handleKeyReleased(event) {
        if (event.isAutoRepeat)
            return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            heldEnter = false
            event.accepted = true
        } else if (heldActionKey === event.key) {
            heldActionKey = 0
            event.accepted = true
        }
    }

    Process {
        id: actionProcess
        stderr: StdioCollector { id: actionError }
        onExited: exitCode => {
            root.actionPending = false
            if (exitCode !== 0)
                root.reportFailure(actionError.text.trim() || "Power menu action failed")
        }
        // Failed-to-start processes do not emit exited.
        onRunningChanged: {
            if (!running) Qt.callLater(() => {
                if (root.actionPending && !actionProcess.running) {
                    root.actionPending = false
                    root.reportFailure("Could not start the action. Check that mori-power and the selected command are installed.")
                }
            })
        }
    }

    Process {
        id: resolveProcess
        stdout: StdioCollector { id: resolveOutput }
        stderr: StdioCollector { id: resolveError }
        onExited: exitCode => {
            root.resolving = false
            if (exitCode !== 0) {
                root.errorMessage = resolveError.text.trim() || "Could not resolve power actions"
                return
            }
            try {
                const actions = JSON.parse(resolveOutput.text)
                const errors = []
                for (const name of ["suspend", "reboot", "poweroff"]) {
                    if (!actions[name] || !Array.isArray(actions[name].command))
                        throw new Error("Invalid power action: " + name)
                    if (actions[name].error)
                        errors.push(actions[name].error)
                }
                root.resolvedActions = actions
                root.errorMessage = errors.join("\n")
            } catch (error) {
                root.errorMessage = "Could not read power actions: " + error
            }
        }
        onRunningChanged: {
            if (!running) Qt.callLater(() => {
                if (root.resolving && !resolveProcess.running) {
                    root.resolving = false
                    root.errorMessage = "Could not start mori-power. Stow the bin package and ensure ~/.local/bin is on PATH."
                }
            })
        }
    }

    BarLabel {
        id: powerIcon
        anchors.centerIn: parent
        text: String.fromCodePoint(0xf0425)
        color: root.accent
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize

        TapHandler {
            onTapped: root.toggle()
        }
    }

    PopupWindow {
        id: menu
        implicitWidth: root.errorMessage.length > 0 ? 300 : 200
        implicitHeight: menuItems.implicitHeight + 24
        visible: false
        color: "transparent"
        grabFocus: false
        onVisibleChanged: {
            if (!visible) {
                root.heldActionKey = 0
                root.heldEnter = false
                root.popupCoordinator.hidePopup(root)
            }
        }

        anchor.window: root.panelWindow
        anchor.rect {
            x: root.panelWindow.popupAnchorX(root, menu.implicitWidth, menu.visible)
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
            color: Theme.bg1
            border.width: 2
            border.color: root.accent

            Column {
                id: menuItems
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 8

                WidgetHeader {
                    text: "Power"
                    color: root.accent
                }

                Repeater {
                    id: powerActions
                    model: [
                        { label: "Lock", shortcut: "L", key: Qt.Key_L, command: ["swaylock"] },
                        { label: "Log out", shortcut: "X", key: Qt.Key_X, command: ["niri", "msg", "action", "quit", "--skip-confirmation"] },
                        { label: "Suspend", shortcut: "S", key: Qt.Key_S, action: "suspend" },
                        { label: "Restart", shortcut: "R", key: Qt.Key_R, action: "reboot" },
                        { label: "Power off", shortcut: "P", key: Qt.Key_P, action: "poweroff" }
                    ]

                    delegate: Item {
                        required property var modelData
                        required property int index
                        property real holdProgress: 0
                        readonly property bool available: root.actionAvailable(modelData)
                        opacity: available ? 1 : 0.4
                        width: menuItems.width
                        implicitHeight: Theme.controlHeight

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.controlBackground(false, index === root.selectedActionIndex,
                                buttonArea.containsMouse && available)
                            border.width: 1
                            border.color: Theme.controlBorder(false, available && index === root.selectedActionIndex,
                                available && buttonArea.containsMouse, root.accent)
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 1
                            width: Math.max(0, parent.width - 2) * parent.holdProgress
                            color: modelData.label === "Power off" ? Theme.bgred : Theme.bg4
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: (index === root.selectedActionIndex ? "› " : "  ")
                                + modelData.label
                            color: modelData.label === "Power off" ? root.accent : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.shortcut
                            color: modelData.label === "Power off" ? root.accent : Theme.grey1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        Timer {
                            id: holdTimer
                            interval: 25
                            repeat: true
                            running: parent.available && menu.visible
                                && ((buttonArea.pressed && buttonArea.containsMouse)
                                    || root.heldActionKey === parent.modelData.key
                                    || root.heldEnter && root.selectedActionIndex === parent.index)

                            onRunningChanged: {
                                if (!running && parent.holdProgress < 1)
                                    parent.holdProgress = 0
                            }

                            onTriggered: {
                                parent.holdProgress = Math.min(1, parent.holdProgress + interval / 800)
                                if (parent.holdProgress === 1) {
                                    stop()
                                    const action = parent.modelData
                                    parent.holdProgress = 0
                                    root.runAction(action)
                                }
                            }
                        }

                        MouseArea {
                            id: buttonArea
                            enabled: parent.available
                            anchors.fill: parent
                            hoverEnabled: true
                            onPressed: {
                                parent.holdProgress = 0
                            }
                            onReleased: parent.holdProgress = 0
                            onCanceled: parent.holdProgress = 0
                            onExited: if (pressed) parent.holdProgress = 0
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.resolving || root.errorMessage.length > 0
                    text: root.resolving ? "Checking power actions…" : root.errorMessage
                    wrapMode: Text.WrapAnywhere
                    color: Theme.grey1
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(10, Theme.fontSize - 1)
                }

                KeyboardHint {
                    text: "↑↓: select\nHold Enter or shortcut: run\nEsc: close"
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
