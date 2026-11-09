import QtQuick
import Quickshell
import "./theme"

// Bar module: wallpaper icon and popup. The chooser itself is
// WallpaperBrowser, shared with Settings → Wallpaper.
Item {
    id: root
    required property var panelWindow
    required property var popupCoordinator
    required property var settings
    property color accent: Theme.green
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    function close() { popup.visible = false }
    function handleKeyPressed(event) {
        if (event.key === Qt.Key_Escape)
            close()
        else if (!browser.item || !browser.item.handleKey(event))
            return
        event.accepted = true
    }
    function toggle() {
        if (popup.visible) {
            close()
        } else {
            popupCoordinator.showPopup(root)
            popup.visible = true
        }
    }

    BarLabel {
        id: icon
        anchors.centerIn: parent
        text: String.fromCodePoint(0xf03e)
        color: root.accent
        font.family: Theme.nerdFontFamily
        TapHandler { onTapped: root.toggle() }
    }

    PopupWindow {
        id: popup
        visible: false
        implicitWidth: 420
        implicitHeight: 440
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

        PopupSurface {
            anchors.fill: parent
            shown: popup.visible
            color: Theme.bg1
            border.width: 2
            border.color: root.accent

            WidgetHeader {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
                text: "Wallpapers"
                color: root.accent
            }

            Loader {
                id: browser
                anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
                anchors { topMargin: 8; leftMargin: 12; rightMargin: 12; bottomMargin: 12 }
                active: popup.visible
                sourceComponent: WallpaperBrowser {
                    settings: root.settings
                    accent: root.accent
                    Component.onCompleted: reset()
                }
            }
        }
    }
}
