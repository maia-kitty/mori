import QtQuick
import Quickshell
import "./theme"
import "ThemeSchedule.js" as ThemeSchedule

// Runs mori-theme when the light/dark schedule crosses a boundary. A manual
// switch (keybind, bar icon, Settings) holds until the next boundary.
Item {
    id: root

    required property var settings
    property string lastScheduled: ""

    function check() {
        if (settings.loading) return
        const mode = ThemeSchedule.scheduledMode(settings, new Date())
        if (mode === "" || mode === lastScheduled) return
        lastScheduled = mode
        if ((mode === "dark") !== Theme.dark)
            Quickshell.execDetached(["mori-theme", mode])
    }

    // Changing the schedule applies it right away, even over a manual switch.
    function reapply() {
        lastScheduled = ""
        check()
    }

    Connections {
        target: root.settings
        function onThemeScheduleChanged() { root.reapply() }
        function onThemeLightTimeChanged() { root.reapply() }
        function onThemeDarkTimeChanged() { root.reapply() }
        function onThemeLatitudeChanged() { root.reapply() }
        function onThemeLongitudeChanged() { root.reapply() }
        function onLoadingChanged() { root.check() }
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.settings.themeSchedule !== "off"
        triggeredOnStart: true
        onTriggered: root.check()
    }
}
