import QtQuick
import Quickshell.Services.UPower
import "./theme"

Row {
    id: root
    spacing: 5

    property color accent: Theme.green
    readonly property var device: UPower.displayDevice
    readonly property int charge: Math.round(Math.max(0, Math.min(1,
        device ? device.percentage : 0)) * 100)
    readonly property bool charging: device
        && (device.state === UPowerDeviceState.Charging
            || device.state === UPowerDeviceState.PendingCharge)

    function batteryIcon() {
        if (charging)
            return String.fromCodePoint(0xf0e7)
        if (charge >= 88)
            return String.fromCodePoint(0xf240)
        if (charge >= 63)
            return String.fromCodePoint(0xf241)
        if (charge >= 38)
            return String.fromCodePoint(0xf242)
        if (charge >= 13)
            return String.fromCodePoint(0xf243)
        return String.fromCodePoint(0xf244)
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.batteryIcon()
        color: root.accent
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.charge + "%"
        color: root.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

}
