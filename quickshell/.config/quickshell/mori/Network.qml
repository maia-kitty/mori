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
    property var wifiDevice: null
    property bool wiredConnected: false
    property string wiredName: ""
    property bool wifiConnected: false
    property string wifiName: ""
    property real signal: 0
    // Quickshell.Networking currently gets its Wi-Fi state from
    // NetworkManager. This setup uses wpa_supplicant, so keep a small
    // read-only fallback for the bar when that model has no active network.
    property string fallbackWifiInterface: ""
    property bool fallbackWifiConnected: false
    property string fallbackWifiName: ""
    property real fallbackWifiSignal: 0
    property var vpnConnections: []
    property string passwordNetworkName: ""
    property var pendingNetwork: null
    // Supplied by Bar.qml: PopupWindow requires the real Quickshell window,
    // not the Qt content window exposed through Window.window.
    required property var panelWindow
    required property var popupCoordinator
    readonly property bool popupVisible: popup.visible
    readonly property bool hasWifiConnection: wifiConnected || fallbackWifiConnected
    readonly property bool wifiRadioEnabled: Networking.wifiEnabled || fallbackWifiInterface.length > 0
    readonly property string currentWifiName: wifiConnected ? wifiName : fallbackWifiName
    readonly property real currentWifiSignal: wifiConnected ? signal : fallbackWifiSignal

    readonly property string icon: {
        if (wiredConnected) return String.fromCodePoint(0xf0200)
        if (!wifiRadioEnabled || !hasWifiConnection) return String.fromCodePoint(0xf092d)

        let tier = currentWifiSignal >= 0.75 ? 4
                 : currentWifiSignal >= 0.50 ? 3
                 : currentWifiSignal >= 0.25 ? 2
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

    function findNetwork(name) {
        if (!wifiDevice)
            return null
        return wifiDevice.networks.values.find(network => network.name === name)
    }

    function connectKnownNetwork(network) {
        pendingNetwork = network
        network.connect()
    }

    Connections {
        target: root.pendingNetwork
        ignoreUnknownSignals: true

        function onConnectionFailed(reason) {
            const network = root.pendingNetwork
            root.pendingNetwork = null
            if (network)
                root.requestPassword(network)
        }

        function onConnectedChanged() {
            if (root.pendingNetwork && root.pendingNetwork.connected)
                root.pendingNetwork = null
        }
    }

    function refreshNetworkModel() {
        // The backend fills its constant object model asynchronously, which
        // does not invalidate JavaScript expressions based on `.values`.
        const devices = Networking.devices.values.slice()
        wiredDevices.clear()
        wiredConnected = false
        wiredName = ""
        wifiDevice = devices.find(device => device.type === DeviceType.Wifi) || null

        for (const device of devices) {
            if (device.type !== DeviceType.Wired)
                continue

            const connectedNetwork = device.networks.values.find(network => network.connected)
            const name = connectedNetwork ? connectedNetwork.name : device.name
            wiredDevices.append({
                "deviceName": String(device.name || "Ethernet"),
                "displayName": String(name || "Ethernet"),
                "isConnected": !!device.connected
            })
            if (device.connected && !wiredConnected) {
                wiredConnected = true
                wiredName = String(name || device.name || "Ethernet")
            }
        }

        const networks = wifiDevice ? wifiDevice.networks.values.slice() : []
        networks.sort((left, right) => {
            if (left.connected !== right.connected)
                return left.connected ? -1 : 1
            return right.signalStrength - left.signalStrength
        })

        wifiNetworks.clear()
        wifiConnected = false
        wifiName = ""
        signal = 0
        for (const network of networks) {
            wifiNetworks.append({
                "networkName": String(network.name || "Unknown"),
                "strength": Number(network.signalStrength || 0),
                "securityType": Number(network.security),
                "isKnown": !!network.known,
                "isConnected": !!network.connected
            })
            if (network.connected && !wifiConnected) {
                wifiConnected = true
                wifiName = String(network.name || "Wi-Fi")
                signal = Number(network.signalStrength || 0)
            }
        }
    }

    Component.onCompleted: refreshNetworkModel()

    ListModel { id: wiredDevices }
    ListModel { id: wifiNetworks }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.refreshNetworkModel()
    }

    // `iw dev` identifies the wpa_supplicant interface without assuming a
    // distro-specific name such as wlan0. Then wpa_cli supplies the active
    // SSID. These processes only affect the compact bar indicator; the popup
    // continues to use Quickshell's native model for network actions.
    function refreshWpaSupplicantState() {
        if (!wifiProbe.running)
            wifiProbe.exec(["iw", "dev"])
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshWpaSupplicantState()
    }

    Process {
        id: wifiProbe

        stdout: StdioCollector {
            onStreamFinished: {
                const match = /^\s*Interface\s+(.+)\s*$/m.exec(this.text)
                root.fallbackWifiInterface = match ? match[1] : ""
                if (!root.fallbackWifiInterface) {
                    root.fallbackWifiConnected = false
                    root.fallbackWifiName = ""
                    root.fallbackWifiSignal = 0
                    return
                }
                if (!wpaStatus.running)
                    wpaStatus.exec(["wpa_cli", "-i", root.fallbackWifiInterface, "status"])
            }
        }
    }

    Process {
        id: wpaStatus

        stdout: StdioCollector {
            onStreamFinished: {
                const completed = /^wpa_state=COMPLETED$/m.test(this.text)
                const ssid = /^ssid=(.*)$/m.exec(this.text)
                root.fallbackWifiConnected = completed && !!ssid && ssid[1].length > 0
                root.fallbackWifiName = root.fallbackWifiConnected ? ssid[1] : ""
                if (root.fallbackWifiConnected && !wifiSignalProbe.running)
                    wifiSignalProbe.exec(["iw", "dev", root.fallbackWifiInterface, "link"])
                else if (!root.fallbackWifiConnected)
                    root.fallbackWifiSignal = 0
            }
        }
    }

    Process {
        id: wifiSignalProbe

        stdout: StdioCollector {
            onStreamFinished: {
                const match = /^\s*signal:\s*(-?\d+(?:\.\d+)?)\s*dBm$/m.exec(this.text)
                // -90 dBm is effectively unusable and -40 dBm is excellent.
                const dbm = match ? Number(match[1]) : -90
                root.fallbackWifiSignal = Math.max(0, Math.min(1, (dbm + 90) / 50))
            }
        }
    }

    function refreshVpn() {
        if (!vpnQuery.running)
            vpnQuery.exec(["nmcli", "-t", "--escape", "no", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active"])
    }

    function requestPassword(network) {
        if (passwordDialog.running)
            return

        passwordNetworkName = network.name
        // Unmap the layer-shell dismiss surface before Zenity appears.
        close()
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
                const network = root.findNetwork(root.passwordNetworkName)
                if (password.length && network)
                    network.connectWithPsk(password)
                root.passwordNetworkName = ""
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
        color: root.wiredConnected || (root.wifiRadioEnabled && root.hasWifiConnection) ? Theme.blue : Theme.grey
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize
    }

    Text {
        text: root.wiredConnected ? root.wiredName
              : !root.wifiRadioEnabled ? "off"
              : root.hasWifiConnection ? root.currentWifiName : "N/A"
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
        implicitHeight: Math.min(listCol.implicitHeight + 24, 400)
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
            if (visible) {
                root.refreshNetworkModel()
                root.refreshVpn()
            }
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
            border.color: Theme.blue

            ScrollableColumn {
                id: listCol
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 10

                Column {
                    width: parent.width
                    spacing: 4
                    visible: wiredDevices.count > 0

                    Text {
                        text: "Ethernet"
                        color: Theme.blue
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Repeater {
                        model: wiredDevices
                        delegate: Column {
                            required property int index
                            required property string deviceName
                            required property string displayName
                            required property bool isConnected
                            width: parent.width
                            spacing: 1

                            Text {
                                text: displayName
                                color: isConnected ? Theme.blue : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }

                            Text {
                                text: isConnected ? "Connected" : "Disconnected"
                                color: Theme.grey
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                visible: index < wiredDevices.count - 1
                                color: Theme.bg4
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        visible: wiredDevices.count > 0
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
                        visible: !root.wifiRadioEnabled
                        text: "Wi-Fi is off"
                        color: Theme.grey
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Repeater {
                        model: wifiNetworks
                        delegate: Column {
                            required property int index
                            required property string networkName
                            required property real strength
                            required property int securityType
                            required property bool isKnown
                            required property bool isConnected
                            width: parent.width

                            RowLayout {
                                width: parent.width
                                spacing: 6

                                Text {
                                    Layout.fillWidth: true
                                    text: networkName + "   " + Math.round(strength * 100) + "%"
                                    color: isConnected ? Theme.blue : Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize

                                    TapHandler {
                                        onTapped: {
                                            if (isConnected) return
                                            const network = root.findNetwork(networkName)
                                            if (!network) return
                                            if (isKnown || securityType === WifiSecurityType.Open)
                                                root.connectKnownNetwork(network)
                                            else
                                                root.requestPassword(network)
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: isConnected
                                    implicitWidth: disconnectLabel.implicitWidth + 10
                                    implicitHeight: disconnectLabel.implicitHeight + 4
                                    color: Theme.bgred
                                    border.width: 1
                                    border.color: Theme.red

                                    Text {
                                        id: disconnectLabel
                                        anchors.centerIn: parent
                                        text: "Disconnect"
                                        color: Theme.red
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 2
                                    }

                                    TapHandler {
                                        onTapped: {
                                            const network = root.findNetwork(networkName)
                                            if (network)
                                                network.disconnect()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                visible: index < wifiNetworks.count - 1
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
