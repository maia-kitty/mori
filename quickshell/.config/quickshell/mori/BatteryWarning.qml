import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import "./theme"

Item {
    id: root
    width: 0
    height: 0

    // 0: no warning this discharge, 1: low, 2: critical.
    property int warnedLevel: 0
    property int warningLevel: 0
    property int warningCharge: 0

    function showWarning(level, charge) {
        warningLevel = level
        warningCharge = charge
        warningWindow.visible = true
        hideWarning.restart()
    }

    function checkBattery() {
        const battery = UPower.displayDevice
        if (!battery || !battery.ready || !battery.isLaptopBattery) {
            warningWindow.visible = false
            return
        }
        if (!UPower.onBattery) {
            warnedLevel = 0
            warningWindow.visible = false
            return
        }

        const charge = Math.round(battery.percentage * 100)
        if (charge > 25) {
            warnedLevel = 0
        } else if (charge <= 10 && warnedLevel < 2) {
            warnedLevel = 2
            showWarning(2, charge)
        } else if (charge <= 20 && warnedLevel < 1) {
            warnedLevel = 1
            showWarning(1, charge)
        }
    }

    Timer {
        id: hideWarning
        interval: root.warningLevel === 2 ? 15000 : 9000
        onTriggered: warningWindow.visible = false
    }

    PanelWindow {
        id: warningWindow
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        anchors { top: true; right: true }
        margins { top: 44; right: 16 }
        implicitWidth: 310
        implicitHeight: 72
        visible: false
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay

        Rectangle {
            anchors.fill: parent
            color: Theme.bg1
            border.width: 2
            border.color: root.warningLevel === 2 ? Theme.red : Theme.yellow

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 12
                spacing: 4

                Text {
                    text: root.warningLevel === 2 ? "Battery critically low" : "Battery low"
                    color: root.warningLevel === 2 ? Theme.red : Theme.yellow
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.headingFontSize
                    font.weight: Font.DemiBold
                }

                Text {
                    text: root.warningCharge + "% remaining"
                        + (root.warningLevel === 2 ? " · Plug in your charger" : "")
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: warningWindow.visible = false
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.checkBattery()
    }

    Connections {
        target: UPower.displayDevice
        function onPercentageChanged() { root.checkBattery() }
        function onStateChanged() { root.checkBattery() }
        function onReadyChanged() { root.checkBattery() }
    }
}
