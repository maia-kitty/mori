import QtQuick
import Quickshell.Services.Pipewire
import "./theme"

// Settings → Sound: output and input device, volume and mute, built from the
// same parts as the volume popup. Per-app volumes stay in the popup.
Item {
    id: root

    property color accent: Theme.fg
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    property int keyboardIndex: 0

    function devices(input) {
        return Pipewire.nodes.values.filter(node => node && node.ready && node.audio
            && !node.isStream && node.isSink !== input)
    }
    // Keyboard rows, top to bottom: output devices, output volume, input devices, input volume.
    function rows() {
        const list = []
        for (const input of [false, true]) {
            for (const node of devices(input)) list.push({ "input": input, "node": node })
            list.push({ "input": input, "node": null })
        }
        return list
    }
    function focusedRow() { return rows()[keyboardIndex] || null }
    function isFocusedVolume(input) {
        const row = focusedRow()
        return !!row && row.input === input && !row.node
    }
    function focusedNode() {
        const row = focusedRow()
        return row ? row.node : null
    }

    function select(node) {
        if (!node || !node.ready || !node.audio || node.isStream) return
        if (node.isSink) Pipewire.preferredDefaultAudioSink = node
        else Pipewire.preferredDefaultAudioSource = node
    }
    function setVolume(node, value) {
        if (node && node.ready && node.audio)
            node.audio.volume = Math.max(0, Math.min(1, value))
    }
    function toggleMute(node) {
        if (node && node.ready && node.audio) node.audio.muted = !node.audio.muted
    }

    // Returns true when the key was used; the host handles Escape.
    function handleKey(event) {
        const row = focusedRow()
        const device = row ? (row.input ? source : sink) : null
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down)
            keyboardIndex = Math.max(0, Math.min(rows().length - 1,
                keyboardIndex + (event.key === Qt.Key_Up ? -1 : 1)))
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && row && row.node)
            select(row.node)
        else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && row && !row.node && device)
            setVolume(device, device.audio.volume + (event.key === Qt.Key_Left ? -0.05 : 0.05))
        else if (event.key === Qt.Key_M && row)
            toggleMute(device)
        else
            return false
        return true
    }

    PwObjectTracker {
        // Nodes only become ready while tracked.
        objects: Pipewire.nodes.values
    }

    ScrollableColumn {
        id: content
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: hint.top; bottomMargin: 10 }
        spacing: 8

        Repeater {
            model: [false, true]
            delegate: Column {
                id: section
                required property bool modelData
                readonly property var device: modelData ? root.source : root.sink
                width: content.width
                spacing: 8
                topPadding: modelData ? 12 : 0

                WidgetHeader { text: section.modelData ? "Input" : "Output"; color: root.accent }

                AudioDeviceList {
                    width: parent.width
                    microphone: section.modelData
                    current: section.device
                    focusedNode: root.focusedNode()
                    accent: root.accent
                    onSelected: node => root.select(node)
                }

                Text {
                    visible: root.devices(section.modelData).length === 0
                    text: section.modelData ? "No microphone available" : "No output available"
                    color: Theme.grey1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                AudioDeviceControl {
                    width: parent.width
                    modelData: section.device && section.device.ready && section.device.audio ? section.device : null
                    microphone: section.modelData
                    focused: root.isFocusedVolume(section.modelData)
                    accent: root.accent
                    onVolumeRequested: value => root.setVolume(section.device, value)
                    onMuteRequested: root.toggleMute(section.device)
                }
            }
        }
    }

    KeyboardHint {
        id: hint
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        text: "↑↓: device or volume · Enter: use device · ←→: volume · M: mute"
    }
}
