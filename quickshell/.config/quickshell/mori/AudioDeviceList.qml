import QtQuick
import Quickshell.Services.Pipewire
import "./theme"

// Output or input devices to choose from, shared by the volume popup and
// Settings → Sound. The default device has a check mark.
Column {
    id: root

    property var nodes: Pipewire.nodes
    property bool microphone: false
    property var current: null
    property var focusedNode: null
    property color accent: Theme.yellow
    readonly property alias repeater: deviceRepeater
    signal selected(var node)

    spacing: 4

    Repeater {
        id: deviceRepeater
        model: root.nodes
        delegate: Loader {
            id: nodeLoader
            required property var modelData
            required property int index
            active: !!modelData && modelData.ready && !!modelData.audio && !modelData.isStream
                && modelData.isSink !== root.microphone
            visible: active
            width: root.width
            sourceComponent: Component {
                Rectangle {
                    width: nodeLoader.width
                    implicitHeight: Theme.controlHeight
                    readonly property bool selected: nodeLoader.modelData === root.current
                    readonly property bool focused: nodeLoader.modelData === root.focusedNode
                    color: Theme.controlBackground(selected, focused, deviceHover.hovered)
                    border.width: 1
                    border.color: Theme.controlBorder(selected, focused, deviceHover.hovered, root.accent)
                    Text {
                        anchors.fill: parent
                        leftPadding: 8
                        rightPadding: 8
                        verticalAlignment: Text.AlignVCenter
                        text: (parent.selected ? "✓  " : "   ")
                            + (nodeLoader.modelData.description || nodeLoader.modelData.nickname || nodeLoader.modelData.name)
                        color: parent.selected ? root.accent : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }
                    HoverHandler { id: deviceHover }
                    TapHandler { onTapped: root.selected(nodeLoader.modelData) }
                }
            }
        }
    }
}
