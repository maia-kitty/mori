import QtQuick
import Quickshell
import Quickshell.Io
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
    property bool profilesAvailable: false
    property bool performanceAvailable: false
    property string currentProfile: ""
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
            keyboardProfileIndex = profileIndex(currentProfile)
            probeProfiles()
            popup.visible = true
        }
    }

    function close() { popup.visible = false }

    function probeProfiles() {
        if (!profileProbe.running)
            profileProbe.exec(["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && exec powerprofilesctl get"])
        if (!profileList.running)
            profileList.exec(["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && exec powerprofilesctl list"])
    }

    function selectProfile(profile) {
        if (!profilesAvailable || profileSet.running
                || (profile === "performance" && !performanceAvailable))
            return
        profileSet.exec(["powerprofilesctl", "set", profile])
    }

    function profileAt(index) {
        return ["power-saver", "balanced", "performance"][index]
    }
    function profileIndex(profile) {
        if (profile === "power-saver") return 0
        if (profile === "performance") return 2
        return 1
    }
    function moveProfileSelection(offset) {
        if (!profilesAvailable)
            return
        let next = keyboardProfileIndex + offset
        while (next >= 0 && next < 3) {
            if (next !== 2 || performanceAvailable) {
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
        if (!profilesAvailable)
            return
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
            profile = "power-saver"
        else if (event.key === Qt.Key_B)
            profile = "balanced"
        else if (event.key === Qt.Key_P)
            profile = "performance"

        if (profile !== null) {
            selectProfile(profile)
            if (profile !== "performance" || performanceAvailable)
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

    Process {
        id: profileProbe
        stdout: StdioCollector {
            onStreamFinished: {
                root.currentProfile = this.text.trim()
                root.keyboardProfileIndex = root.profileIndex(root.currentProfile)
            }
        }
        onExited: exitCode => {
            root.profilesAvailable = exitCode === 0
            if (exitCode !== 0)
                root.currentProfile = ""
        }
    }

    Process {
        id: profileList
        stdout: StdioCollector {
            onStreamFinished: root.performanceAvailable = /^\s*\*?\s*performance:/m.test(this.text)
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.performanceAvailable = false
        }
    }

    Process {
        id: profileSet
        onExited: exitCode => root.probeProfiles()
    }

    Timer {
        interval: 3000
        running: popup.visible && !root.profilesAvailable
        repeat: true
        onTriggered: root.probeProfiles()
    }

    BarLabel {
        anchors.verticalCenter: parent.verticalCenter
        text: root.batteryIcon()
        color: root.accent
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize
    }

    BarLabel {
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

                WidgetHeader {
                    text: root.profilesAvailable ? "Power profile" : "Power profile unavailable"
                    color: root.accent
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
                        { "label": "Power saver", "shortcut": "S", "profile": "power-saver" },
                        { "label": "Balanced", "shortcut": "B", "profile": "balanced" },
                        { "label": "Performance", "shortcut": "P", "profile": "performance" }
                    ]
                    delegate: Rectangle {
                        id: profileRow
                        required property var modelData
                        required property int index
                        readonly property bool available: root.profilesAvailable
                            && (modelData.profile !== "performance"
                                || root.performanceAvailable)
                        readonly property bool selected: root.currentProfile === modelData.profile
                        width: menuColumn.width
                        height: Theme.controlHeight
                        color: Theme.controlBackground(selected, index === root.keyboardProfileIndex,
                            profileHover.hovered && available)
                        border.width: 1
                        border.color: available ? Theme.controlBorder(selected,
                            index === root.keyboardProfileIndex, profileHover.hovered, root.accent) : Theme.bg4

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: (profileRow.index === root.keyboardProfileIndex ? "› " : "  ")
                                + profileRow.modelData.label
                            color: profileRow.available
                                ? profileRow.selected ? root.accent : Theme.fg
                                : Theme.disabledText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: profileRow.available
                                ? profileRow.modelData.shortcut

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

                KeyboardHint {
                    text: root.profilesAvailable ? "↑↓: profile · Enter: select · Esc: close" : "Esc: close"
                }
            }
        }
    }

    PanelWindow {
        id: dismissLayer
        screen: root.panelWindow.screen
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
