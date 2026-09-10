import QtQuick
import Quickshell
import "./theme"
Text {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    text: Qt.formatDateTime(clock.date, "[ yyyy/MM/dd   hh:mm ]")
    color: Theme.fg
    font.pixelSize: 14
}
