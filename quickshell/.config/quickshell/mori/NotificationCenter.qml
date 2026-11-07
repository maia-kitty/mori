import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "./theme"

Item {
    id: root
    implicitWidth: Math.max(18, indicator.implicitWidth)
    implicitHeight: indicator.implicitHeight
    required property var panelWindow
    required property var popupCoordinator
    property var settings: null
    property color accent: Theme.purple
    required property var service
    readonly property bool doNotDisturb: !!settings && settings.doNotDisturb
    function toggleDoNotDisturb() { if (settings) settings.setDoNotDisturb(!doNotDisturb) }

    readonly property int notificationCount: service.count
    readonly property bool popupVisible: popup.visible
    // ↑↓ shows the selection; mouse users don't see one.
    property bool keyboardActive: false
    property int selectedIndex: 0
    onNotificationCountChanged: selectedIndex = Math.max(0, Math.min(selectedIndex, notificationCount - 1))

    function close() {
        popup.visible = false
    }

    function toggle() {
        if (popup.visible)
            close()
        else {
            popupCoordinator.showPopup(root)
            keyboardActive = false
            selectedIndex = 0
            popup.visible = true
        }
    }

    function handleKeyPressed(event) {
        if (event.key === Qt.Key_Escape) {
            close()
            event.accepted = true
            return
        }
        if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier)
            return

        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            if (notificationCount > 0) {
                if (keyboardActive)
                    selectedIndex = Math.max(0, Math.min(notificationCount - 1,
                        selectedIndex + (event.key === Qt.Key_Up ? -1 : 1)))
                keyboardActive = true
            }
        } else if (event.isAutoRepeat) {
            return
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (keyboardActive && popupContent.item) popupContent.item.activateSelected()
        } else if (event.key === Qt.Key_R) {
            if (keyboardActive && notificationCount > 0)
                service.remove(service.history.get(selectedIndex).notificationId)
        } else if (event.key === Qt.Key_C) {
            service.clear()
        } else if (event.key === Qt.Key_D) {
            toggleDoNotDisturb()
        } else {
            return
        }
        event.accepted = true
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
            y: parentWindow.height + 2
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
                    function activateSelected() {
                        const entry = historyView.itemAtIndex(root.selectedIndex)
                        if (entry) entry.activate()
                    }

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
                                        onTapped: root.toggleDoNotDisturb()
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
                                        onTapped: root.service.clear()
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
                            model: root.service.history
                            currentIndex: root.selectedIndex
                            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                            delegate: Rectangle {
                                id: historyEntry
                                required property int index
                                required property int notificationId
                                required property int liveId
                                required property string appName
                                required property string desktopEntry
                                required property string summary
                                required property string body
                                required property double receivedAt
                                property bool expanded: false
                                width: historyView.width
                                ListView.onReused: expanded = false
                                implicitHeight: notificationText.implicitHeight + 12
                                radius: 0
                                color: Theme.bg2
                                border.width: root.keyboardActive && index === root.selectedIndex ? 1 : 0
                                border.color: root.accent

                                function activate() {
                                    // First click on a cut-off notification reveals the rest.
                                    if (!expanded && (summaryText.truncated || bodyText.truncated)) {
                                        expanded = true
                                        return
                                    }
                                    root.service.activate(liveId, desktopEntry)
                                    root.service.remove(notificationId)
                                }

                                Column {
                                    id: notificationText
                                    z: 1 // action buttons above the click area
                                    anchors.left: parent.left
                                    anchors.right: closeButton.left
                                    anchors.top: parent.top
                                    anchors.margins: 6
                                    spacing: 2

                                    RowLayout {
                                        width: parent.width
                                        spacing: 8
                                        Text {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            text: appName
                                            color: root.accent
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.maximumWidth: parent.width * 0.65
                                            Layout.alignment: Qt.AlignVCenter
                                            text: Qt.formatDateTime(new Date(receivedAt),
                                                (root.settings ? root.settings.clockDateFormat : "yyyy/MM/dd")
                                                + " · " + (root.settings && root.settings.clockTimeFormat === "12h"
                                                    ? "h:mm AP" : "HH:mm"))
                                            color: Theme.grey
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize - 2
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        id: summaryText
                                        width: parent.width
                                        text: summary
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        wrapMode: expanded ? Text.Wrap : Text.NoWrap
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        id: bodyText
                                        width: parent.width
                                        visible: body.length > 0
                                        text: body
                                        textFormat: Text.PlainText
                                        color: Theme.grey1
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        wrapMode: Text.Wrap
                                        maximumLineCount: expanded ? 1000 : 3
                                        elide: Text.ElideRight
                                    }

                                    NotificationActions {
                                        service: root.service
                                        liveId: historyEntry.liveId
                                        accent: root.accent
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
                                        onTapped: root.service.remove(notificationId)
                                    }
                                }

                                MouseArea {
                                    anchors.left: parent.left
                                    anchors.right: closeButton.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: historyEntry.activate()
                                }
                            }
                        }

                        KeyboardHint {
                            id: notificationHint
                            text: "↑↓: select · Enter: open · R: remove · C: clear · D: DND · Esc: close"
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: dismissLayer
        screen: root.panelWindow.screen
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
