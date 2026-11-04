import QtQuick
import Quickshell
import "./theme"

// Bar icon for mori-theme: shows the current mode, click to switch.
Item {
    id: root

    property color accent: Theme.yellow

    function toggle() { Quickshell.execDetached(["mori-theme", "toggle"]) }
    function close() {}

    implicitWidth: icon.implicitWidth
    implicitHeight: Theme.barContentHeight

    BarLabel {
        id: icon
        anchors.centerIn: parent
        // nf-md-weather_night / nf-md-weather_sunny
        text: String.fromCodePoint(Theme.dark ? 0xf0594 : 0xf0599)
        color: root.accent
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize
        TapHandler { onTapped: root.toggle() }
    }
}
