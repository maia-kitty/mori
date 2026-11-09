import QtQuick

Flickable {
    id: root

    default property alias items: contentColumn.data
    property alias spacing: contentColumn.spacing

    implicitHeight: contentColumn.implicitHeight
    contentWidth: width
    contentHeight: contentColumn.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    function forceLayout() { contentColumn.forceLayout() }

    // Scroll just far enough to show `item` (something inside this column).
    function ensureVisible(item) {
        if (!item) return
        const y = item.mapToItem(contentItem, 0, 0).y
        if (y < contentY) contentY = y
        else if (y + item.height > contentY + height) contentY = y + item.height - height
    }

    Column {
        id: contentColumn
        width: root.width
    }
}
