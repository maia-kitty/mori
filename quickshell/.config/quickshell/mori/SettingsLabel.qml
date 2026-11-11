import QtQuick
import "./theme"

BarLabel {
    // Key hints ("Key: action · Key: action"), instead of text.
    property string keys
    text: Theme.keyHint(keys)
    textFormat: keys ? Text.StyledText : Text.PlainText
    // Leave room for settings headings while retaining the same glyph
    // alignment used by the bar's labels and icons.
    implicitHeight: Math.max(22, font.pixelSize + 6)
}
