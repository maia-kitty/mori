import QtQuick
import "./theme"

Column {
    property alias text: hintText.text

    width: parent ? parent.width : 0
    spacing: 10

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.bg4
    }

    Text {
        id: hintText
        width: parent.width
        color: Theme.grey1
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(10, Theme.fontSize - 2)
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
    }
}
