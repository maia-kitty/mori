import QtQuick
import Quickshell
import Quickshell.Wayland
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
        else if (!browser.handleKey(event))
            return
        event.accepted = true
    }
    function toggle() {
        if (popup.visible) {
            close()
        } else {
            popupCoordinator.showPopup(root)
            popup.visible = true
            browser.reset()
        }
    }

    BarLabel {
        id: icon
        anchors.centerIn: parent
        text: String.fromCodePoint(0xf03e)
        color: root.accent
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize
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

            WallpaperBrowser {
                id: browser
                anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
                anchors { topMargin: 8; leftMargin: 12; rightMargin: 12; bottomMargin: 12 }
                settings: root.settings
                accent: root.accent
                onFolderPickerRequested: root.close()
                onFolderPicked: {
                    if (!popup.visible) root.toggle()
                    browser.keyboardMode = "files"
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
