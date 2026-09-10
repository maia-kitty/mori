import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland
import "./theme"

RowLayout {
    id: root
    spacing: 4

    property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
    property var active: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) : null
    readonly property var wiredDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wired)
    readonly property var activeWired: wiredDevices.find(d => d.connected)
    property var vpnConnections: []
    property var passwordNetwork: null
    // Supplied by Bar.qml: PopupWindow requires the real Quickshell window,
    // not the Qt content window exposed through Window.window.
    required property var panelWindow
    required property var popupCoordinator
    readonly property real signal: active ? active.signalStrength : 0
    readonly property bool popupVisible: popup.visible

    readonly property string icon: {
        if (activeWired) return String.fromCodePoint(0xf0200)
        if (!Networking.wifiEnabled || !active) return String.fromCodePoint(0xf092d)

        let tier = signal >= 0.75 ? 4
                 : signal >= 0.50 ? 3
                 : signal >= 0.25 ? 2
                 : 1
        return String.fromCodePoint(0xf091f + (tier + 1) * 3)
    }

    function toggle() {
        if (popup.visible)
            close()
        else {
            popupCoordinator.showPopup(root)
            popup.visible = true
        }
    }

    function close() { popup.visible = false }

    function refreshVpn() {
        if (!vpnQuery.running)
            vpnQuery.exec(["nmcli", "-t", "--escape", "no", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active"])
    }

    function requestPassword(network) {
        passwordNetwork = network
        passwordDialog.exec([
            "zenity",
            "--password",
            "--title=Wi-Fi Password",
            "--text=Password for \"" + network.name + "\""
        ])
    }

    Process {
        id: passwordDialog

        stdout: StdioCollector {
            onStreamFinished: {
                // Zenity appends one newline to its result; preserve every
                // other character in case the passphrase contains spaces.
                const password = this.text.replace(/\r?\n$/, "")
                if (password.length && root.passwordNetwork)
                    root.passwordNetwork.connectWithPsk(password)
                root.passwordNetwork = null
            }
        }
    }

    Process {
        id: vpnQuery

        stdout: StdioCollector {
            onStreamFinished: {
                const activeVpns = []
                for (const line of this.text.split(/\r?\n/)) {
                    if (!line.length) continue
                    const deviceSeparator = line.lastIndexOf(":")
                    if (deviceSeparator < 0) continue
                    const typeSeparator = line.lastIndexOf(":", deviceSeparator - 1)
                    if (typeSeparator < 0) continue

                    const name = line.slice(0, typeSeparator)
                    const type = line.slice(typeSeparator + 1, deviceSeparator)
                    const device = line.slice(deviceSeparator + 1)
                    const tunnelDevice = /^(tun|tap|wg|proton)/i.test(device)
                    const vpnProfile = /proton/i.test(name)

                    if (type === "vpn" || type === "wireguard" || type === "tun" || tunnelDevice || vpnProfile)
                        activeVpns.push(name)
                }
                root.vpnConnections = activeVpns
            }
        }
    }

    Text {
        text: root.icon
        color: root.activeWired || Networking.wifiEnabled ? Theme.blue : Theme.grey
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize
    }

    Text {
        text: root.activeWired
              ? (root.activeWired.network ? root.activeWired.network.name : root.activeWired.name)
              : !Networking.wifiEnabled ? "off" : root.active ? root.active.name : "N/A"
        color: Theme.blue
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        elide: Text.ElideRight
        Layout.maximumWidth: 90
    }

    TapHandler { onTapped: root.toggle() }

    // PopupWindow is positioned relative to the bar, unlike a screen-anchored
    // PanelWindow. This keeps it reliably below the bar on every screen.
    PopupWindow {
        id: popup

        implicitWidth: 320
        implicitHeight: Math.min(listCol.height + 24, 400)
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

        onVisibleChanged: {
            if (root.wifiDevice)
                root.wifiDevice.scannerEnabled = visible
            if (visible)
                root.refreshVpn()
            if (!visible)
                root.popupCoordinator.hidePopup(root)
        }

        Timer {
            interval: 5000
            repeat: true
            running: popup.visible
            onTriggered: root.refreshVpn()
        }

        PopupSurface {
            anchors.fill: parent
            shown: popup.visible
            radius: 0
            color: Theme.bg1
            border.width: 2
            border.color: Theme.fg

            Column {
                id: listCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 10

                Column {
                    width: parent.width
                    spacing: 4
                    visible: root.wiredDevices.length > 0

                    Text {
                        text: "Ethernet"
                        color: Theme.blue
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Repeater {
                        model: root.wiredDevices
                        delegate: Column {
                            required property var modelData
                            required property int index
                            width: parent.width
                            spacing: 1

                            Text {
                                text: modelData.network ? modelData.network.name : modelData.name
                                color: modelData.connected ? Theme.blue : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }

                            Text {
                                text: modelData.connected
                                      ? "Connected" + (modelData.linkSpeed > 0 ? " · " + modelData.linkSpeed + " Mbps" : "")
                                      : modelData.hasLink ? "Cable connected" : "Cable disconnected"
                                color: Theme.grey
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }

                            TapHandler {
                                enabled: !!modelData.network
                                onTapped: {
                                    if (!modelData.network) return
                                    if (modelData.network.connected)
                                        modelData.network.disconnect()
                                    else
                                        modelData.network.connect()
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                visible: index < root.wiredDevices.length - 1
                                color: Theme.bg4
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        visible: root.wiredDevices.length > 0
                        color: Theme.bg4
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4

                    Text {
                        text: "VPN"
                        color: Theme.blue
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        visible: root.vpnConnections.length === 0
                        text: "Not connected"
                        color: Theme.grey
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Repeater {
                        model: root.vpnConnections
                        delegate: Text {
                            required property string modelData
                            text: modelData
                            color: Theme.blue
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4

                    Text {
                        text: "Wi-Fi"
                        color: Theme.blue
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        visible: !Networking.wifiEnabled
                        text: "Wi-Fi is off"
                        color: Theme.grey
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Repeater {
                        model: root.wifiDevice ? root.wifiDevice.networks.values : []
                        delegate: Column {
                            required property int index
                            required property var modelData
                            width: parent.width

                            Text {
                                text: modelData.name + "   " + Math.round(modelData.signalStrength * 100) + "%"
                                color: modelData.connected ? Theme.blue : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize

                                TapHandler {
                                    onTapped: {
                                        if (modelData.connected) return
                                        if (modelData.known || modelData.security === 0)
                                            modelData.connect()
                                        else
                                            root.requestPassword(modelData)
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                visible: index < (root.wifiDevice ? root.wifiDevice.networks.values.length - 1 : 0)
                                color: Theme.bg4
                            }
                        }
                    }
                }
            }

        }
    }

    // Dismiss clicks below the bar without blocking the network pill itself.
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
