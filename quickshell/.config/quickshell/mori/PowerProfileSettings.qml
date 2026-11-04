import QtQuick
import "./theme"

// Settings → Power profile, the same choice as in the Battery popup.
Column {
    id: root

    required property var profiles
    spacing: 8

    function handleKey(event) {
        if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Return, Qt.Key_Enter].indexOf(event.key) < 0)
            return false
        row.step(event.key === Qt.Key_Left ? -1 : 1)
        return true
    }

    Component.onCompleted: root.profiles.probe()

    SettingsLabel {
        text: "←→ / Enter change"
        color: Theme.grey1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    ChoiceRow {
        id: row
        label: "Power profile"
        values: root.profiles.performanceAvailable
            ? ["power-saver", "balanced", "performance"] : ["power-saver", "balanced"]
        labels: ["Power saver", "Balanced", "Performance"]
        value: root.profiles.current
        available: root.profiles.available
        focused: true
        onChosen: value => root.profiles.select(value)
    }

    Text {
        width: parent.width
        textFormat: Text.PlainText
        visible: !root.profiles.available
        text: "Needs power-profiles-daemon (powerprofilesctl), which isn't available."
        color: Theme.grey1
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(10, Theme.fontSize - 2)
        wrapMode: Text.WordWrap
    }
}
