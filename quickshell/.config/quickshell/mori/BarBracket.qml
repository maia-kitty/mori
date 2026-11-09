import QtQuick
import "./theme"

BarLabel {
    id: root
    property var action: null
    property real hitMargin: 6


    TapHandler {
        enabled: root.action !== null
        margin: root.hitMargin
        onTapped: root.action()
    }
}
