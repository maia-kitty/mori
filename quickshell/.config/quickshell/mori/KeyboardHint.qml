import QtQuick
import "./theme"

Column {
    property string text

    width: parent ? parent.width : 0
    spacing: 10

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.bg4
    }

    MoriText {
        id: hintText
        width: parent.width
        color: Theme.grey1
        font.pixelSize: Math.max(10, Theme.fontSize - 2)
        text: Theme.keyHint(parent.text)
        textFormat: Text.StyledText
        wrapMode: Text.WordWrap
    }
}
