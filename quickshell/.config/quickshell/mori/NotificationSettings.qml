import QtQuick
import "./theme"

// Settings → Notifications. Clearing history stays in the notification centre.
Column {
    id: root

    required property var settings
    spacing: 8
    // False while Settings keyboard focus is on the sidebar or tabs.
    property bool active: true

    function handleKey(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right)
            dnd.pick(event.key === Qt.Key_Left ? -1 : 1)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            dnd.apply()
        else if (event.key === Qt.Key_D)
            dnd.step(1)
        else
            return false
        return true
    }

    SettingsLabel {
        text: "←→ pick · Enter apply · D toggle"
        color: Theme.grey1
    }

    ChoiceRow {
        id: dnd
        label: "Do Not Disturb"
        values: [false, true]
        labels: ["Off", "On"]
        value: root.settings.doNotDisturb
        focused: root.active
        onChosen: value => root.settings.setDoNotDisturb(value)
    }

    MoriText {
        width: parent.width
        textFormat: Text.PlainText
        text: "While on, notifications don't pop up; they still go to the notification centre."
        color: Theme.grey1
        font.pixelSize: Math.max(10, Theme.fontSize - 2)
        wrapMode: Text.WordWrap
    }
}
