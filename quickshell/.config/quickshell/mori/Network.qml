import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "./theme"

// Bar widget: network icon and name, and a popup with NetworkPanel. State and
// actions live in NetworkService (shell.qml), shared with Settings → Network.
RowLayout {
    id: root
    spacing: 4

    required property var service
    property color accent: Theme.blue
    property bool compactMode: false
    // Supplied by Bar.qml: PopupWindow requires the real Quickshell window,
    // not the Qt content window exposed through Window.window.
    required property var panelWindow
    required property var popupCoordinator
    readonly property bool popupVisible: popup.visible

    function toggle() {
        if (popup.visible)
            close()
        else {
            popupCoordinator.showPopup(root)
            popup.visible = true
        }
    }

    function close() { popup.visible = false }

    function handleKeyPressed(event) {
        // The panel uses Escape to leave its list; on its tabs Escape closes.
        if (!popupContent.item || !popupContent.item.handleKey(event)) {
            if (event.key === Qt.Key_Escape) close()
            else return
        }
        event.accepted = true
    }

    BarLabel {
        text: root.service.icon
        color: root.service.wiredConnected || (root.service.wifiRadioEnabled && root.service.hasWifiConnection) ? root.accent : Theme.grey
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize
    }

    BarLabel {
        visible: root.service.vpnConnections.length > 0
        text: String.fromCodePoint(0xf033e)
        color: root.accent
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize
    }

    BarLabel {
        text: root.service.wiredConnected ? root.service.wiredName
              : !root.service.wifiRadioEnabled ? "off"
              : root.service.hasWifiConnection ? root.service.currentWifiName : "N/A"
        color: root.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        elide: Text.ElideRight
        Layout.maximumWidth: 90
        visible: !root.compactMode
    }

    TapHandler { onTapped: root.toggle() }

    // PopupWindow is positioned relative to the bar, unlike a screen-anchored
    // PanelWindow. This keeps it reliably below the bar on every screen.
    PopupWindow {
        id: popup

        implicitWidth: 400
        implicitHeight: Math.min(popupContent.item ? popupContent.item.implicitHeight : 80, 440)
        visible: false
        color: "transparent"
        grabFocus: false

        anchor.window: root.panelWindow
        anchor.rect {
            x: root.panelWindow.popupAnchorX(root, popup.implicitWidth, popup.visible)
            y: parentWindow.height + 2
            width: 1
            height: 1
        }
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left

        onVisibleChanged: if (!visible) root.popupCoordinator.hidePopup(root)

        Loader {
            id: popupContent
            anchors.fill: parent
            active: popup.visible

            sourceComponent: Component {
                NetworkPanel {
                    service: root.service
                    accent: root.accent
                    shown: popup.visible
                }
            }
        }
    }

    // Dismiss clicks below the bar without blocking the network pill itself.
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

        onVisibleChanged: if (visible) Qt.callLater(() => keyCapture.forceActiveFocus())

        Item {
            id: keyCapture
            anchors.fill: parent
            focus: dismissLayer.visible
            Keys.onPressed: event => root.handleKeyPressed(event)
            MouseArea { anchors.fill: parent; onClicked: root.close() }
        }
    }

}
