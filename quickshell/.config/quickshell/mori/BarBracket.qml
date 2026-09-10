import QtQuick
import "./theme"

Text {
    id: root
    property var action: null
    property real hitMargin: 6

    font.family: Theme.fontFamily
    font.pixelSize: 14

    TapHandler {
        enabled: root.action !== null
        margin: root.hitMargin
        onTapped: root.action()
    }
}
