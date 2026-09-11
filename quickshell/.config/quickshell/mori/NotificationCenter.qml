import QtQuick
import Quickshell
import Quickshell.Wayland
import "./theme"

Item {
    id: root
    implicitWidth: 18
    implicitHeight: bell.implicitHeight
    required property var panelWindow
    required property var notificationServer
    required property var popupCoordinator
    property bool doNotDisturb: false

    readonly property var notifications: notificationServer.trackedNotifications.values
    readonly property bool popupVisible: popup.visible

    function close() {
        popup.visible = false
    }

    function toggle() {
        if (popup.visible)
            close()
        else {
            popupCoordinator.showPopup(root)
            popup.visible = true
        }
    }

    Text {
        id: bell
        anchors.centerIn: parent
        text: String.fromCodePoint(root.doNotDisturb ? 0xf009b : 0xf009a)
        color: Theme.purple
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize

        TapHandler {
            onTapped: root.toggle()
        }
    }

    PopupWindow {
        id: popup
        implicitWidth: 360
        implicitHeight: Math.min(notificationList.implicitHeight + 24, 440)
        visible: false
        color: "transparent"
        grabFocus: false
        onVisibleChanged: if (!visible) root.popupCoordinator.hidePopup(root)

        anchor.window: root.panelWindow
        anchor.rect {
            x: root.x + root.width / 2 + popup.implicitWidth / 2
            y: parentWindow.height + 6
            width: 1
            height: 1
        }
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left

        PopupSurface {
            anchors.fill: parent
            shown: popup.visible
            radius: 0
            color: Theme.bg1
            border.width: 2
            border.color: Theme.purple

            ScrollableColumn {
                id: notificationList
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 8

                Item {
                    width: parent.width
                    height: implicitHeight
                    implicitHeight: Math.max(headerTitle.implicitHeight, headerActions.implicitHeight)

                    Text {
                        id: headerTitle
                        text: "Notifications"
                        color: Theme.purple
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Row {
                        id: headerActions
                        anchors.right: parent.right
                        spacing: 12

                        Text {
                            text: root.doNotDisturb ? "DND on" : "DND off"
                            color: root.doNotDisturb ? Theme.purple : Theme.grey1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize

                            TapHandler {
                                onTapped: root.doNotDisturb = !root.doNotDisturb
                            }
                        }

                        Text {
                            id: clearAll
                            text: "Clear all"
                            visible: root.notifications.length > 0
                            color: Theme.grey1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize

                            TapHandler {
                                onTapped: root.notifications.slice().forEach(notification => notification.dismiss())
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.notifications.length === 0
                    text: "No notifications"
                    color: Theme.grey
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Repeater {
                    model: root.notifications

                    delegate: Rectangle {
                        required property var modelData
                        width: notificationList.width
                        implicitHeight: notificationText.implicitHeight + 12
                        radius: 0
                        color: Theme.bg2

                        Column {
                            id: notificationText
                            anchors.left: parent.left
                            anchors.right: closeButton.left
                            anchors.top: parent.top
                            anchors.margins: 6
                            spacing: 2

                            Text {
                                width: parent.width
                                text: modelData.appName || "Notification"
                                color: Theme.purple
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: modelData.summary
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: modelData.body.length > 0
                                text: modelData.body
                                textFormat: Text.PlainText
                                color: Theme.grey1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            id: closeButton
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            text: "×"
                            color: Theme.grey
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize

                            TapHandler {
                                onTapped: modelData.dismiss()
                            }
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        visible: popup.visible
        anchors { top: true; bottom: true; left: true; right: true }
        margins.top: root.panelWindow.height
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }
}
