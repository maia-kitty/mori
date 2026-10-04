import QtQuick

BarLabel {
    // Leave room for settings headings while retaining the same glyph
    // alignment used by the bar's labels and icons.
    implicitHeight: Math.max(22, font.pixelSize + 6)
}
