import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import "./theme"

Row {
    id: root
    spacing: 5

    required property var panelWindow
    required property var popupCoordinator
    property color accent: Theme.green
    property int keyboardProfileIndex: 0
    readonly property var device: UPower.displayDevice
    readonly property int charge: Math.round(Math.max(0, Math.min(1,
        device ? device.percentage : 0)) * 100)
    readonly property bool charging: device
        && (device.state === UPowerDeviceState.Charging
            || device.state === UPowerDeviceState.PendingCharge)

    function toggle() {
        if (popup.visible) {
            close()
        } else {
            popupCoordinator.showPopup(root)
            keyboardProfileIndex = profileIndex(PowerProfiles.profile)
            popup.visible = true
        }
    }

    function close() { popup.visible = false }

    function selectProfile(profile) {
        if (profile === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile)
            return
        PowerProfiles.profile = profile
    }

    function profileAt(index) {
        return [PowerProfile.PowerSaver, PowerProfile.Balanced,
            PowerProfile.Performance][index]
    }
    function profileIndex(profile) {
        if (profile === PowerProfile.PowerSaver) return 0
        if (profile === PowerProfile.Performance) return 2
        return 1
    }
    function moveProfileSelection(offset) {
        let next = keyboardProfileIndex + offset
        while (next >= 0 && next < 3) {
            if (next !== 2 || PowerProfiles.hasPerformanceProfile) {
                keyboardProfileIndex = next
                return
            }
            next += offset
        }
    }

    function handleKeyPressed(event) {
        if (event.key === Qt.Key_Escape) {
            close()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            moveProfileSelection(event.key === Qt.Key_Up ? -1 : 1)
            event.accepted = true
            return
        }
        if (event.isAutoRepeat)
            return

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            selectProfile(profileAt(keyboardProfileIndex))
            event.accepted = true
            return
        }

        let profile = null
        if (event.key === Qt.Key_S)
            profile = PowerProfile.PowerSaver
        else if (event.key === Qt.Key_B)
            profile = PowerProfile.Balanced
        else if (event.key === Qt.Key_P)
            profile = PowerProfile.Performance

        if (profile !== null) {
            selectProfile(profile)
            if (profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)
                keyboardProfileIndex = profileIndex(profile)
            event.accepted = true
        }
    }

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

    TapHandler { onTapped: root.toggle() }

    PopupWindow {
        id: popup
        implicitWidth: 250
        implicitHeight: menuColumn.implicitHeight + 24
        visible: false
        color: "transparent"
        grabFocus: false
        onVisibleChanged: if (!visible) root.popupCoordinator.hidePopup(root)

        anchor.window: root.panelWindow
        anchor.rect {
            x: root.panelWindow.popupAnchorX(root, popup.implicitWidth, popup.visible)
            y: parentWindow.height + 6
            width: 1
            height: 1
        }
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left

        PopupSurface {
            anchors.fill: parent
            shown: popup.visible
            color: Theme.bg1
            border.width: 2
            border.color: root.accent

            Column {
                id: menuColumn
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 7

                Text {
                    text: "Power profile"
                    color: root.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.headingFontSize
                    font.weight: Font.DemiBold
                }

                Text {
                    text: root.charge + "% · "
                        + (root.charging ? "Charging" : UPower.onBattery ? "On battery" : "Plugged in")
                    color: Theme.grey1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.bg4
                }

                Repeater {
                    model: [
                        { "label": "Power saver", "shortcut": "S", "profile": PowerProfile.PowerSaver },
                        { "label": "Balanced", "shortcut": "B", "profile": PowerProfile.Balanced },
                        { "label": "Performance", "shortcut": "P", "profile": PowerProfile.Performance }
                    ]
                    delegate: Rectangle {
                        id: profileRow
                        required property var modelData
                        required property int index
                        readonly property bool available: modelData.profile !== PowerProfile.Performance
                            || PowerProfiles.hasPerformanceProfile
                        readonly property bool selected: PowerProfiles.profile === modelData.profile
                        width: menuColumn.width
                        height: 30
                        color: profileHover.hovered && available
                            ? Theme.bg2 : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: (profileRow.index === root.keyboardProfileIndex ? "› " : "  ")
                                + profileRow.modelData.label
                            color: profileRow.available
                                ? profileRow.selected || profileRow.index === root.keyboardProfileIndex
                                    ? root.accent : Theme.fg
                                : Theme.grey
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: profileRow.available
                                ? profileRow.modelData.shortcut
                                    + (profileRow.selected ? " · Active" : "")
                                : profileRow.modelData.shortcut + " · Unavailable"
                            color: profileRow.available && profileRow.selected
                                ? root.accent : Theme.grey1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        HoverHandler { id: profileHover }
                        TapHandler {
                            enabled: profileRow.available
                            onTapped: {
                                root.keyboardProfileIndex = profileRow.index
                                root.selectProfile(profileRow.modelData.profile)
                            }
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: dismissLayer
        visible: popup.visible
        anchors { top: true; bottom: true; left: true; right: true }
        margins.top: root.panelWindow.height
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => keyCapture.forceActiveFocus())
        }

        Item {
            id: keyCapture
            anchors.fill: parent
            focus: dismissLayer.visible

            Keys.onPressed: event => root.handleKeyPressed(event)

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }
    }
}
