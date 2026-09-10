import QtQuick
import Quickshell.Wayland._ToplevelManagement
import "./theme"

Item {
    id: root

    readonly property var activeWindow: ToplevelManager.activeToplevel
    readonly property string activeLabel: {
        if (!activeWindow)
            return "Desktop"
        if (activeWindow.title.length > 0)
            return activeWindow.title
        if (activeWindow.appId.length > 0)
            return activeWindow.appId
        return "Unknown"
    }

    implicitWidth: Math.min(label.implicitWidth, 320)
    implicitHeight: label.implicitHeight

    Text {
        id: label
        width: parent.width
        text: "[ " + root.activeLabel + " ]"
        color: Theme.aqua
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        elide: Text.ElideRight
    }
}
