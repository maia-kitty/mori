import QtQuick
import "./theme"

BarLabel {
    id: root
    property var action: null
    property real hitMargin: 6

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize

    TapHandler {
        enabled: root.action !== null
        margin: root.hitMargin
        onTapped: root.action()
    }
}
