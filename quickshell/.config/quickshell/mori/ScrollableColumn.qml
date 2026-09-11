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

    Column {
        id: contentColumn
        width: root.width
    }
}
