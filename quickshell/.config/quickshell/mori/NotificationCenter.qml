import QtQuick
import Quickshell
import Quickshell.Io
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

    property var pendingNotifications: []
    property int nextNotificationId: 0
    readonly property int notificationCount: notificationHistory.count
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

    function desktopId(value) {
        return String(value || "").toLowerCase().replace(/\.desktop$/, "")
    }

    function launchApplication(entry) {
        const desktopEntry = desktopId(entry)
        if (desktopEntry.length)
            applicationLaunch.exec(["gtk-launch", desktopEntry])
    }

    function focusApplication(entry) {
        const desktopEntry = desktopId(entry)
        if (!desktopEntry.length)
            return

        // A second click while the window list is in flight still gets a
        // useful result, without racing a shared Process instance.
        if (windowQuery.running) {
            launchApplication(desktopEntry)
            return
        }

        windowQuery.desktopEntry = desktopEntry
        windowQuery.exec(["niri", "msg", "--json", "windows"])
    }

    function addNotification(notification) {
        // Apps may replace an existing DBus notification. Keep a value copy so
        // the vault preserves every arrival rather than only its replacement.
        pendingNotifications.push({
            "notificationId": nextNotificationId++,
            "appName": String(notification.appName || "Notification"),
            "desktopEntry": String(notification.desktopEntry || ""),
            "summary": String(notification.summary || ""),
            "body": String(notification.body || "")
        })
        notificationQueue.restart()
    }

    function flushNotifications() {
        while (pendingNotifications.length > 0)
            notificationHistory.insert(0, pendingNotifications.shift())
    }

    function removeNotification(notificationId) {
        for (let i = 0; i < notificationHistory.count; ++i) {
            if (notificationHistory.get(i).notificationId === notificationId) {
                notificationHistory.remove(i)
                return
            }
        }
    }

    Process {
        id: applicationLaunch
    }

    Process {
        id: windowFocus
    }

    Process {
        id: windowQuery
        property string desktopEntry: ""
        stdout: StdioCollector { id: windowList }

        onExited: exitCode => {
            const entry = desktopEntry
            if (exitCode !== 0) {
                root.launchApplication(entry)
                return
            }

            let windows = []
            try {
                windows = JSON.parse(windowList.text)
            } catch (error) {
                console.warn("Could not parse Niri window list:", error)
            }

            let match = null
            for (let i = 0; i < windows.length; ++i) {
                const appId = root.desktopId(windows[i].app_id)
                if (appId === entry || appId.endsWith("." + entry)
                        || entry.endsWith("." + appId)) {
                    match = windows[i]
                    break
                }
            }

            if (match)
                windowFocus.exec(["niri", "msg", "action", "focus-window", "--id", String(match.id)])
            else
                root.launchApplication(entry)
        }
    }

    ListModel {
        id: notificationHistory
    }

    // Mutate the model after the DBus callback returns; doing it directly can
    // race a Repeater regeneration in Qt.
    Timer {
        id: notificationQueue
        interval: 0
        repeat: false
        onTriggered: root.flushNotifications()
    }

    Connections {
        target: root.notificationServer

        function onNotification(notification) {
            root.addNotification(notification)
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
            x: root.panelWindow.popupAnchorX(root, popup.implicitWidth)
            y: parentWindow.height + 6
            width: 1
            height: 1
        }
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left

        PopupSurface {
            anchors.fill: parent
            shown: popup.visible
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
                        font.pixelSize: Theme.headingFontSize
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
                            visible: root.notificationCount > 0
                            color: Theme.grey1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize

                            TapHandler {
                            onTapped: notificationHistory.clear()
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.notificationCount === 0
                    text: "No notifications"
                    color: Theme.grey
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Repeater {
                    model: notificationHistory

                    delegate: Rectangle {
                        required property int notificationId
                        required property string appName
                        required property string desktopEntry
                        required property string summary
                        required property string body
                        width: notificationList.width
                        implicitHeight: notificationText.implicitHeight + 12
                        radius: 0
                        color: Theme.bg2

                        function activate() {
                            root.focusApplication(desktopEntry)
                            root.removeNotification(notificationId)
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
                                text: appName
                                color: Theme.purple
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: summary
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: body.length > 0
                                text: body
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
                            color: Theme.purple
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 5

                            TapHandler {
                                margin: 6
                                onTapped: root.removeNotification(notificationId)
                            }
                        }

                        // Applications commonly expose a "default" action to
                        // open their window or jump to the relevant item. When
                        // they do not, focus the Niri window matching the
                        // notification's desktop entry instead.
                        MouseArea {
                            anchors.left: parent.left
                            anchors.right: closeButton.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.activate()
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
