import QtQuick
import Quickshell
import "./theme"

Item {
    id: root
    required property var panelWindow
    required property var service
    required property bool doNotDisturb
    property color accent: Theme.purple
    property int nextToastId: 0
    property bool suppressed: false

    function addNotification(entry) {
        // An app replacing its notification updates that toast in place.
        for (let i = 0; i < popupNotifications.count; ++i) {
            const toast = popupNotifications.get(i)
            if (toast.liveId === entry.liveId) {
                popupNotifications.set(i, {
                    "appName": entry.appName, "summary": entry.summary,
                    "body": entry.body, "generation": toast.generation + 1
                })
                return
            }
        }
        if (doNotDisturb) return
        popupNotifications.insert(0, {
            "toastId": nextToastId++, "liveId": entry.liveId, "generation": 0,
            "appName": entry.appName, "desktopEntry": entry.desktopEntry,
            "summary": entry.summary, "body": entry.body
        })
        while (popupNotifications.count > 3)
            popupNotifications.remove(popupNotifications.count - 1)
    }

    function removeNotification(toastId) {
        for (let i = 0; i < popupNotifications.count; ++i) {
            if (popupNotifications.get(i).toastId === toastId) {
                popupNotifications.remove(i)
                return
            }
        }
    }

    ListModel {
        id: popupNotifications
    }

    Connections {
        target: root.service
        function onArrived(entry) { root.addNotification(entry) }
        // The app closed it, or one of its actions ran.
        function onLiveClosed(liveId) {
            for (let i = 0; i < toastRepeater.count; ++i) {
                const toast = toastRepeater.itemAt(i)
                if (toast && toast.liveId === liveId) toast.dismiss()
            }
        }
    }

    PopupWindow {
        id: popup
        implicitWidth: 360
        implicitHeight: Math.min(popupList.implicitHeight + 24, root.panelWindow.screen ? Math.max(80, root.panelWindow.screen.height - root.panelWindow.height - 24) : 440)
        visible: popupNotifications.count > 0 && !root.suppressed
        color: "transparent"
        grabFocus: false

        anchor.window: root.panelWindow
        anchor.rect {
            x: parentWindow.width
            y: parentWindow.height + 2
            width: 1
            height: 1
        }
        anchor.edges: Edges.Top | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left

        PopupSurface {
            anchors.fill: parent
            shown: popup.visible
            color: Theme.bg1
            border.width: 2
            border.color: root.accent

            ScrollableColumn {
                id: popupList
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Repeater {
                    id: toastRepeater
                    model: popupNotifications

                    delegate: PopupSurface {
                        id: toast
                        required property int toastId
                        required property int liveId
                        required property int generation
                        required property string appName
                        required property string desktopEntry
                        required property string summary
                        required property string body
                        width: popupList.width
                        implicitHeight: notificationText.implicitHeight + 12
                        shown: false
                        color: Theme.bg2

                        function dismiss() {
                            if (!shown) return
                            shown = false
                            removeTimer.stop()
                            exitTimer.restart()
                        }

                        function activate() {
                            root.service.activate(liveId, desktopEntry)
                            dismiss()
                        }

                        Component.onCompleted: shown = true
                        // An updated notification gets its full time again.
                        onGenerationChanged: if (!toastHover.hovered) removeTimer.restart()

                        // Wait while the pointer is on the toast.
                        HoverHandler {
                            id: toastHover
                            onHoveredChanged: hovered ? removeTimer.stop() : removeTimer.restart()
                        }

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
                            onTriggered: root.removeNotification(toast.toastId)
                        }

                        Column {
                            id: notificationText
                            z: 1 // action buttons above the click area
                            anchors.left: parent.left
                            anchors.right: closeButton.left
                            anchors.top: parent.top
                            anchors.margins: 6
                            spacing: 2

                            MoriText {
                                width: parent.width
                                text: toast.appName
                                color: root.accent
                                elide: Text.ElideRight
                            }

                            MoriText {
                                width: parent.width
                                text: toast.summary
                                color: Theme.fg
                                elide: Text.ElideRight
                            }

                            MoriText {
                                width: parent.width
                                visible: toast.body.length > 0
                                text: toast.body
                                textFormat: Text.PlainText
                                color: Theme.grey1
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }

                            NotificationActions {
                                service: root.service
                                liveId: toast.liveId
                                accent: root.accent
                            }
                        }

                        MoriText {
                            id: closeButton
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            text: "×"
                            color: root.accent
                            font.pixelSize: Theme.fontSize + 5

                            TapHandler {
                                margin: 6
                                onTapped: toast.dismiss()
                            }
                        }

                        MouseArea {
                            anchors.left: parent.left
                            anchors.right: closeButton.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: toast.activate()
                        }
                    }
                }
            }
        }
    }
}
