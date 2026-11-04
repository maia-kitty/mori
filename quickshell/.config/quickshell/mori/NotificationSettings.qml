import QtQuick
import "./theme"

// Settings → Notifications. Clearing history stays in the notification centre.
Column {
    id: root

    required property var settings
    spacing: 8

    function handleKey(event) {
        if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Return, Qt.Key_Enter, Qt.Key_D].indexOf(event.key) < 0)
            return false
        dnd.step(event.key === Qt.Key_Left ? -1 : 1)
        return true
    }

    SettingsLabel {
        text: "←→ / Enter / D change"
        color: Theme.grey1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    ChoiceRow {
        id: dnd
        label: "Do Not Disturb"
        values: [false, true]
        labels: ["Off", "On"]
        value: root.settings.doNotDisturb
        focused: true
        onChosen: value => root.settings.setDoNotDisturb(value)
    }

    Text {
        width: parent.width
        textFormat: Text.PlainText
        text: "While on, notifications don't pop up; they still go to the notification centre."
        color: Theme.grey1
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(10, Theme.fontSize - 2)
        wrapMode: Text.WordWrap
    }
}
