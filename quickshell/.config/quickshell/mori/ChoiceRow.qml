import QtQuick
import "./theme"

// One Settings row: label on the left, choices on the right. Settings pages
// for bar modules use it (Notifications, Battery, Network).
Item {
    id: root

    property string label: ""
    property var values: []
    property var labels: []
    property var value
    property bool focused: false
    property bool available: true
    // Choice highlighted with ←→ until apply(); -1 means the current value.
    property int pendingIndex: -1
    signal chosen(var value)
    onFocusedChanged: pendingIndex = -1
    onValueChanged: pendingIndex = -1

    width: parent ? parent.width : 0
    height: Theme.controlHeight

    SettingsLabel {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: (root.focused ? "› " : "  ") + root.label
        color: Theme.grey1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    Row {
        anchors.right: parent.right
        spacing: 6
        Repeater {
            model: root.values
            delegate: Rectangle {
                id: choice
                required property var modelData
                required property int index
                readonly property bool selected: root.value === modelData
                readonly property bool highlighted: root.focused
                    && (root.pendingIndex >= 0 ? index === root.pendingIndex : selected)
                width: Math.max(72, choiceLabel.implicitWidth + 20)
                height: Theme.controlHeight
                color: Theme.controlBackground(selected, highlighted, root.available && choiceHover.hovered)
                border.width: 1
                border.color: Theme.controlBorder(selected, highlighted, root.available && choiceHover.hovered)
                SettingsLabel {
                    id: choiceLabel
                    anchors.centerIn: parent
                    text: root.labels[choice.index] || String(choice.modelData)
                    color: !root.available ? Theme.disabledText : choice.selected ? Theme.fg : Theme.grey1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                HoverHandler { id: choiceHover }
                TapHandler {
                    enabled: root.available
                    onTapped: root.chosen(choice.modelData)
                }
            }
        }
    }

    // ←→ moves the highlight, Enter applies it.
    function pick(offset) {
        if (!available || values.length === 0) return
        const base = pendingIndex >= 0 ? pendingIndex : Math.max(0, values.indexOf(value))
        pendingIndex = Math.max(0, Math.min(values.length - 1, base + offset))
    }

    function apply() {
        if (available && pendingIndex >= 0) chosen(values[pendingIndex])
        pendingIndex = -1
    }

    // Next choice right away (shortcut keys such as D for Do Not Disturb).
    function step(offset) {
        if (!available || values.length === 0) return
        const index = values.indexOf(value)
        chosen(values[(index + offset + values.length) % values.length])
    }
}
