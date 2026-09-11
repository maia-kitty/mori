import QtQuick
import Quickshell
import "./theme"

Item {
    id: root
    required property var panelWindow
    required property var notificationServer
    required property var popupCoordinator
    required property bool doNotDisturb
    property var popupNotifications: []
    property bool suppressed: false

    function addNotification(notification) {
        popupCoordinator.showPopup(root)
        suppressed = false
        popupNotifications = [notification].concat(popupNotifications).slice(0, 3)
    }

    function removeNotification(notification) {
        popupNotifications = popupNotifications.filter(item => item !== notification)
    }

    function close() {
        suppressed = true
    }

    Connections {
        target: root.notificationServer

        function onNotification(notification) {
            if (!root.doNotDisturb)
                root.addNotification(notification)
        }
    }

    PopupWindow {
        id: popup
        implicitWidth: 360
        implicitHeight: popupList.implicitHeight + 24
        visible: root.popupNotifications.length > 0 && !root.suppressed
        color: "transparent"
        grabFocus: false
        onVisibleChanged: if (!visible) root.popupCoordinator.hidePopup(root)

        anchor.window: root.panelWindow
        anchor.rect {
            x: parentWindow.width - 2
            y: parentWindow.height + 6
            width: 1
            height: 1
        }
        anchor.edges: Edges.Top | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left

        PopupSurface {
            anchors.fill: parent
            shown: popup.visible
            radius: 0
            color: Theme.bg1
            border.width: 2
            border.color: Theme.purple

            Column {
                id: popupList
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 8

                Repeater {
                    model: root.popupNotifications

                    delegate: PopupSurface {
                        id: toast
                        required property var modelData
                        width: popupList.width
                        implicitHeight: notificationText.implicitHeight + 12
                        shown: false
                        radius: 0
                        color: Theme.bg2

                        function dismiss() {
                            if (!shown) return
                            shown = false
                            removeTimer.stop()
                            exitTimer.restart()
                        }

                        Component.onCompleted: shown = true

                        Timer {
                            id: removeTimer
                            interval: 6000
                            running: true
                            repeat: false
                            onTriggered: toast.dismiss()
                        }

                        Timer {
                            id: exitTimer
                            interval: 140
                            repeat: false
                            onTriggered: root.removeNotification(modelData)
                        }

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
                                onTapped: toast.dismiss()
                            }
                        }
                    }
                }
            }
        }
    }
}
