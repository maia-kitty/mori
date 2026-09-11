import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import org.kde.kdeconnect as Connect
import "./theme"

Item {
    id: root
    required property var panelWindow
    required property var popupCoordinator
    property var device: null
    readonly property color accent: Theme.orange
    readonly property string deviceId: device ? device.id() : ""
    readonly property bool connected: device !== null && device.isReachable && device.isPaired
    readonly property var battery: connected && batteryPlugin.available
        ? Connect.DeviceBatteryDbusInterfaceFactory.create(deviceId) : null
    readonly property var network: connected && networkPlugin.available
        ? Connect.DeviceConnectivityReportDbusInterfaceFactory.create(deviceId) : null
    readonly property bool batteryKnown: battery !== null && battery.hasBattery && battery.charge >= 0
    readonly property int strength: network && network.cellularNetworkType.length
        ? network.cellularNetworkStrength : -1
    readonly property string batteryText: batteryKnown
        ? battery.charge + "%" + (battery.isCharging ? " +" : "") : "—"
    readonly property string notificationText: connected && notificationsPlugin.available
        && notifications.item ? String(notifications.item.count) : "—"
    property string feedback: ""

    implicitWidth: summary.implicitWidth
    implicitHeight: summary.implicitHeight

    function selectDevice() {
        let fallback = null
        for (let i = 0; i < devices.count; ++i) {
            const candidate = devices.getDevice(i)
            if (candidate.type !== "phone") continue
            if (!fallback) fallback = candidate
            if (candidate.isReachable) {
                device = candidate
                return
            }
        }
        device = fallback
    }

    function toggle() {
        if (popup.visible) close()
        else {
            popupCoordinator.showPopup(root)
            popup.visible = true
        }
    }
    function close() { popup.visible = false }

    onDeviceChanged: {
        feedback = ""
        batteryPlugin.available = false
        networkPlugin.available = false
        notificationsPlugin.available = false
        clipboardPlugin.available = false
        Qt.callLater(() => {
            batteryPlugin.pluginsChanged()
            networkPlugin.pluginsChanged()
            notificationsPlugin.pluginsChanged()
            clipboardPlugin.pluginsChanged()
        })
    }

    Connect.DevicesModel {
        id: devices
        displayFilter: Connect.DevicesModel.Paired
        onRowsChanged: root.selectDevice()
        onDataChanged: root.selectDevice()
    }
    Connect.PluginChecker { id: batteryPlugin; device: root.device; pluginName: "battery" }
    Connect.PluginChecker { id: networkPlugin; device: root.device; pluginName: "connectivity_report" }
    Connect.PluginChecker { id: notificationsPlugin; device: root.device; pluginName: "notifications" }
    Connect.PluginChecker { id: clipboardPlugin; device: root.device; pluginName: "clipboard" }
    Loader {
        id: notifications
        active: root.connected && notificationsPlugin.available
        sourceComponent: Item {
            readonly property int count: notificationModel.count
            Connect.NotificationsModel {
                id: notificationModel
                deviceId: root.deviceId
            }
        }
    }

    Process {
        id: clipboardSend
        onExited: exitCode => {
            root.feedback = exitCode === 0 ? "Clipboard sent" : "Could not send clipboard"
            feedbackTimer.restart()
        }
    }
    Timer { id: feedbackTimer; interval: 4000; onTriggered: root.feedback = "" }

    Row {
        id: summary
        spacing: 6
        Text {
            text: "["
            color: root.connected ? root.accent : Theme.grey
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        Text {
            text: String.fromCodePoint(0xf011c)
            color: root.connected ? root.accent : Theme.grey
            font.family: Theme.nerdFontFamily
            font.pixelSize: Theme.fontSize
        }
        Text {
            text: root.connected ? root.batteryText : "offline"
            color: !root.connected ? Theme.grey
                : root.batteryKnown && root.battery.charge <= 20 ? Theme.red : root.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        Text {
            visible: root.connected
            text: String.fromCodePoint(0xf009a) + " " + root.notificationText
            color: root.accent
            font.family: Theme.nerdFontFamily
            font.pixelSize: Theme.fontSize
        }
        Row {
            visible: root.connected
            spacing: 2
            height: Theme.fontSize
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 3
                    height: 4 + index * 3
                    anchors.bottom: parent.bottom
                    color: root.strength > index ? root.accent : Theme.grey
                }
            }
        }
        Text {
            text: "]"
            color: root.connected ? root.accent : Theme.grey
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
    TapHandler { onTapped: root.toggle() }

    PopupWindow {
        id: popup
        implicitWidth: 300
        implicitHeight: details.implicitHeight + 24
        visible: false
        color: "transparent"
        grabFocus: false
        anchor.window: root.panelWindow
        anchor.rect {
            x: root.x + root.width / 2 + popup.implicitWidth / 2
            y: parentWindow.height + 6
            width: 1
            height: 1
        }
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left
        onVisibleChanged: if (!visible) root.popupCoordinator.hidePopup(root)

        PopupSurface {
            anchors.fill: parent
            shown: popup.visible
            color: Theme.bg1
            border.width: 2
            border.color: root.accent
            Column {
                id: details
                anchors.margins: 12
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 12

                Text {
                    width: parent.width
                    text: root.device ? root.device.name : "KDE Connect"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                }
                Text {
                    width: parent.width
                    text: !root.device ? "No paired phone. Pair one in KDE Connect."
                        : !root.connected ? "Phone disconnected"
                        : "Battery: " + (root.batteryKnown ? root.battery.charge + "%" + (root.battery.isCharging ? " · charging" : "") : "unavailable")
                          + "\nNotifications: " + (notificationsPlugin.available ? root.notificationText : "unavailable")
                          + "\nCellular: " + (root.strength >= 0 ? root.network.cellularNetworkType + " · " + root.strength + "/4" : "unavailable")
                    wrapMode: Text.WordWrap
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    lineHeight: 1.5
                }
                Rectangle {
                    width: parent.width
                    height: 32
                    readonly property bool canSend: root.connected && clipboardPlugin.available && !clipboardSend.running
                    color: canSend ? (sendMouse.containsMouse ? Theme.bg3 : Theme.bgorange) : Theme.bg2
                    border.width: 1
                    border.color: canSend ? root.accent : Theme.grey
                    Text {
                        anchors.centerIn: parent
                        text: clipboardSend.running ? "Sending…" : "Send clipboard"
                        color: parent.canSend ? root.accent : Theme.grey
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    MouseArea {
                        id: sendMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: parent.canSend
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.feedback = ""
                            clipboardSend.exec(["kdeconnect-cli", "--device", root.deviceId, "--send-clipboard"])
                        }
                    }
                }
                Text {
                    visible: text.length > 0
                    width: parent.width
                    text: root.feedback
                    wrapMode: Text.WordWrap
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }
        }
    }

    PanelWindow {
        visible: popup.visible
        anchors { top: true; bottom: true; left: true; right: true }
        margins.top: root.panelWindow.height
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }
}
