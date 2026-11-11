import QtQuick
import "./theme"

// Settings → Power profile, the same choice as in the Battery popup.
Column {
    id: root

    required property var profiles
    spacing: 8
    // False while Settings keyboard focus is on the sidebar or tabs.
    property bool active: true

    function handleKey(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right)
            row.pick(event.key === Qt.Key_Left ? -1 : 1)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            row.apply()
        else
            return false
        return true
    }

    Component.onCompleted: root.profiles.probe()

    SettingsLabel {
        keys: "←→: pick · Enter: apply"
        color: Theme.grey1
    }

    ChoiceRow {
        id: row
        label: "Power profile"
        values: root.profiles.performanceAvailable
            ? ["power-saver", "balanced", "performance"] : ["power-saver", "balanced"]
        labels: ["Power saver", "Balanced", "Performance"]
        value: root.profiles.current
        available: root.profiles.available
        focused: root.active
        onChosen: value => root.profiles.select(value)
    }

    MoriText {
        width: parent.width
        textFormat: Text.PlainText
        visible: !root.profiles.available
        text: "Needs power-profiles-daemon (powerprofilesctl), which isn't available."
        color: Theme.grey1
        font.pixelSize: Math.max(10, Theme.fontSize - 2)
        wrapMode: Text.WordWrap
    }
}
