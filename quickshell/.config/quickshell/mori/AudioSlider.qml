import QtQuick
import QtQuick.Controls
import "./theme"

Slider {
    id: root
    property color accent: Theme.yellow
    property bool highlighted: false
    from: 0
    to: 1
    stepSize: 0.01
    implicitHeight: Theme.controlHeight

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: 4
        color: root.highlighted || root.hovered ? Theme.bg5 : Theme.bg4
        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            color: root.accent
        }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 10
        height: 10
        color: root.accent
    }
}
