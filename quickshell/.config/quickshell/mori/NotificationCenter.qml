import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./theme"

Item {
    id: root
    implicitWidth: Math.max(18, indicator.implicitWidth)
    implicitHeight: indicator.implicitHeight
    required property var panelWindow
    required property var notificationServer
    required property var popupCoordinator
    property color accent: Theme.purple
    property bool doNotDisturb: false

    property var pendingNotifications: []
    property int nextNotificationId: 0
    readonly property int historyLimit: 500
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

    function handleKeyPressed(event) {
        if (event.key === Qt.Key_Escape) {
            close()
            event.accepted = true
            return
        }
        if (event.modifiers !== Qt.NoModifier || event.isAutoRepeat)
            return

        if (event.key === Qt.Key_C) {
            notificationHistory.clear()
            event.accepted = true
        } else if (event.key === Qt.Key_D) {
            doNotDisturb = !doNotDisturb
            event.accepted = true
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
        if (pendingNotifications.length >= historyLimit)
            pendingNotifications.shift()
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
        if (notificationHistory.count > historyLimit)
            notificationHistory.remove(historyLimit, notificationHistory.count - historyLimit)
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
    // race delegate regeneration in Qt.
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

    Row {
        id: indicator
        anchors.centerIn: parent
        spacing: 6

        BarLabel {
            text: String.fromCodePoint(root.doNotDisturb ? 0xf009b : 0xf009a)
            color: root.accent
            font.family: Theme.nerdFontFamily
            font.pixelSize: Theme.fontSize
        }

        BarLabel {
            id: countLabel
            text: String(root.notificationCount)
            visible: root.notificationCount > 0
            color: root.accent
        }
    }

    TapHandler { onTapped: root.toggle() }

    PopupWindow {
        id: popup
        implicitWidth: 360
        implicitHeight: popupContent.item ? popupContent.item.implicitHeight : 80
        visible: false
        color: "transparent"
        grabFocus: false
        onVisibleChanged: if (!visible) root.popupCoordinator.hidePopup(root)

        anchor.window: root.panelWindow
        anchor.rect {
            x: root.panelWindow.popupAnchorX(root, popup.implicitWidth, popup.visible)
            y: parentWindow.height + 6
            width: 1
            height: 1
        }
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left

        Loader {
            id: popupContent
            anchors.fill: parent
            active: popup.visible

            sourceComponent: Component {
                PopupSurface {
                    implicitHeight: notificationList.implicitHeight + 24
                    anchors.fill: parent
                    shown: popup.visible
                    color: Theme.bg1
                    border.width: 2
                    border.color: root.accent

                    Column {
                        id: notificationList
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 12
                        spacing: 8

                        Item {
                            id: notificationHeader
                            width: parent.width
                            height: implicitHeight
                            implicitHeight: Math.max(headerTitle.implicitHeight, headerActions.implicitHeight)

                            WidgetHeader {
                                id: headerTitle
                                text: "Notifications"
                                color: root.accent
                            }

                            Row {
                                id: headerActions
                                anchors.right: parent.right
                                spacing: 12

                                Text {
                                    text: "DND · D"
                                    color: root.doNotDisturb ? root.accent : Theme.grey1
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize

                                    TapHandler {
                                        onTapped: root.doNotDisturb = !root.doNotDisturb
                                    }
                                }

                                Text {
                                    id: clearAll
                                    text: "Clear all  C"
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

                        ListView {
                            id: historyView
                            width: parent.width
                            height: Math.min(contentHeight, Math.max(0, 440 - 24 - notificationHeader.height - notificationHint.implicitHeight - 16))
                            clip: true
                            spacing: 8
                            cacheBuffer: 0
                            reuseItems: true
                            model: notificationHistory

                            delegate: Rectangle {
                                required property int notificationId
                                required property string appName
                                required property string desktopEntry
                                required property string summary
                                required property string body
                                width: historyView.width
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
                                        color: root.accent
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
                                    color: root.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize + 5

                                    TapHandler {
                                        margin: 6
                                        onTapped: root.removeNotification(notificationId)
                                    }
                                }

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

                        KeyboardHint {
                            id: notificationHint
                            text: "Esc: close"
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: dismissLayer
        visible: popup.visible
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

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }
    }
}
