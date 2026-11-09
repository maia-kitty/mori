import QtQuick
import "./theme"

Item {
    id: root

    property alias text: label.text
    property alias color: label.color
    property alias font: label.font
    property alias elide: label.elide
    property alias textFormat: label.textFormat
    property alias horizontalAlignment: label.horizontalAlignment

    implicitWidth: label.implicitWidth
    implicitHeight: Theme.barContentHeight

    TextMetrics {
        id: metrics
        font: label.font
        text: label.text
        elide: label.elide
        elideWidth: root.width
    }

    MoriText {
        id: label
        width: root.width
        // Font rectangles are relative to the baseline. Center the visible
        // glyphs, rather than the font's unused ascent/descent space.
        y: (root.height - metrics.tightBoundingRect.height) / 2
            - metrics.tightBoundingRect.y - baselineOffset
        color: Theme.fg
        textFormat: Text.PlainText
    }
}
