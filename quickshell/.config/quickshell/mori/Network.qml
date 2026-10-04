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
    property color accent: Theme.blue
    property bool compactMode: false
    property var wifiDevice: null
    property bool wiredConnected: false
    property string wiredName: ""
    property bool wifiConnected: false
    property int nativeWifiNetworkCount: 0
    property string wifiName: ""
    // Quickshell.Networking currently gets its Wi-Fi state from
    // NetworkManager. This setup uses wpa_supplicant, so keep a small
    // read-only fallback for the bar when that model has no active network.
    property string fallbackWifiInterface: ""
    property bool fallbackWifiConnected: false
    property string fallbackWifiName: ""
    property real fallbackWifiSignal: 0
    property var wpaKnownNetworks: ({})
    property string wpaError: ""
    property string pendingWpaName: ""
    property string pendingWpaPassword: ""
    property bool pendingWpaOpen: false
    property var wpaCommands: []
    property int wpaCommandCount: 0
    property bool wpaSavingProfile: false
    property bool passwordForWpa: false
    property var vpnConnections: []
    property string vpnError: ""
    property string disconnectingVpnUuid: ""
    property bool vpnRefreshPending: false
    property string passwordNetworkName: ""
    property var pendingNetwork: null
    property int keyboardNetworkIndex: 0
    // Supplied by Bar.qml: PopupWindow requires the real Quickshell window,
    // not the Qt content window exposed through Window.window.
    required property var panelWindow
    required property var popupCoordinator
    readonly property bool popupVisible: popup.visible
    readonly property bool useWpaFallback: fallbackWifiInterface.length > 0
        && (!wifiDevice || (!wifiConnected && nativeWifiNetworkCount === 0))
    readonly property bool hasWifiConnection: wifiConnected || fallbackWifiConnected
    readonly property bool wifiRadioEnabled: Networking.wifiEnabled || fallbackWifiInterface.length > 0
    readonly property string currentWifiName: wifiConnected ? wifiName : fallbackWifiName
    readonly property string icon: {
        if (wiredConnected) return String.fromCodePoint(0xf0200)
        if (!wifiRadioEnabled || !hasWifiConnection) return String.fromCodePoint(0xf092d)
        return String.fromCodePoint(0xf0928)
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

    function networkCount() { return useWpaFallback ? wpaNetworks.count : wifiNetworks.count }
    function moveNetworkSelection(offset) {
        keyboardNetworkIndex = Math.max(0, Math.min(networkCount() - 1,
            keyboardNetworkIndex + offset))
        const item = networkRepeater.itemAt(keyboardNetworkIndex)
        if (item) {
            const y = item.mapToItem(listCol.contentItem, 0, 0).y
            if (y < listCol.contentY)
                listCol.contentY = y
            else if (y + item.height > listCol.contentY + listCol.height)
                listCol.contentY = y + item.height - listCol.height
        }
    }
    function activateNetwork(name, securityType, isKnown, isConnected, networkId) {
        if (isConnected) return
        if (useWpaFallback) {
            if (networkId < 0 && securityType === -2) {
                wpaError = "Only open and WPA-Personal networks can be added here"
                return
            }
            connectWpaNetwork(name, networkId, securityType === WifiSecurityType.Open)
            return
        }
        const network = findNetwork(name)
        if (!network) return
        if (isKnown || securityType === WifiSecurityType.Open)
            connectKnownNetwork(network)
        else
            requestPassword(network)
    }
    function handleKeyPressed(event) {
        if (event.key === Qt.Key_Escape) close()
        else if (event.key === Qt.Key_Up) moveNetworkSelection(-1)
        else if (event.key === Qt.Key_Down) moveNetworkSelection(1)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (networkCount() > 0) {
                const index = Math.min(keyboardNetworkIndex, networkCount() - 1)
                keyboardNetworkIndex = index
                const entry = (useWpaFallback ? wpaNetworks : wifiNetworks).get(index)
                activateNetwork(entry.networkName, entry.securityType, entry.isKnown,
                    entry.isConnected, entry.networkId)
            }
        } else return
        event.accepted = true
    }

    function findNetwork(name) {
        if (!wifiDevice)
            return null
        return wifiDevice.networks.values.find(network => network.name === name)
    }

    function connectKnownNetwork(network) {
        pendingNetwork = network
        network.connect()
    }

    function refreshWpaNetworks() {
        if (!useWpaFallback || !popup.visible)
            return
        if (!wpaScan.running)
            wpaScan.exec(["wpa_cli", "-i", fallbackWifiInterface, "scan"])
        if (!wpaKnownQuery.running)
            wpaKnownQuery.exec(["wpa_cli", "-i", fallbackWifiInterface, "list_networks"])
    }

    function parseWpaNetworks(text) {
        const known = Object.create(null)
        for (const line of text.trim().split(/\r?\n/).slice(1)) {
            const fields = line.split("\t")
            if (fields.length >= 2 && /^\d+$/.test(fields[0]))
                known[fields[1]] = Number(fields[0])
        }
        wpaKnownNetworks = known
        refreshWpaScanResults()
    }

    function refreshWpaScanResults() {
        if (useWpaFallback && popup.visible && !wpaResults.running)
            wpaResults.exec(["wpa_cli", "-i", fallbackWifiInterface, "scan_results"])
    }

    function parseWpaScanResults(text) {
        const strongest = Object.create(null)
        for (const line of text.trim().split(/\r?\n/).slice(1)) {
            const fields = line.split("\t")
            if (fields.length < 5)
                continue
            const name = fields.slice(4).join("\t")
            if (!name)
                continue
            const dbm = Number(fields[2])
            const strength = isFinite(dbm)
                ? Math.max(0, Math.min(1, (dbm + 90) / 50)) : 0
            const flags = fields[3]
            const securityType = /PSK/.test(flags) ? -1
                : /(?:WPA|WEP|SAE|OWE|EAP)/.test(flags)
                    ? -2 : WifiSecurityType.Open
            if (!strongest[name] || strength > strongest[name].strength)
                strongest[name] = { "name": name, "strength": strength,
                    "securityType": securityType }
        }
        const entries = Object.values(strongest)
        if (fallbackWifiConnected && fallbackWifiName && !strongest[fallbackWifiName])
            entries.push({ "name": fallbackWifiName,
                "strength": fallbackWifiSignal, "securityType": -1 })
        entries.sort((left, right) => {
            if ((left.name === fallbackWifiName) !== (right.name === fallbackWifiName))
                return left.name === fallbackWifiName ? -1 : 1
            return right.strength - left.strength
        })
        wpaNetworks.clear()
        for (const entry of entries)
            wpaNetworks.append({
                "networkName": entry.name,
                "strength": entry.strength,
                "securityType": entry.securityType,
                "networkId": wpaKnownNetworks[entry.name] ?? -1,
                "isKnown": entry.name in wpaKnownNetworks,
                "isConnected": fallbackWifiConnected && entry.name === fallbackWifiName
            })
    }

    function runWpaAction(commands) {
        if (wpaAction.running)
            return
        wpaError = ""
        wpaCommandCount = commands.length
        wpaSavingProfile = commands[commands.length - 1] === "save_config"
        wpaCommands = commands
        wpaAction.exec(["wpa_cli", "-i", fallbackWifiInterface])
    }

    function wpaValue(value) {
        // Commands go to wpa_cli's stdin, never into a process argument.
        return "\"" + value.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"") + "\""
    }

    function connectWpaNetwork(name, networkId, isOpen, password) {
        if (networkId >= 0) {
            runWpaAction(["select_network " + networkId])
            return
        }
        if (!isOpen && !password) {
            if (passwordDialog.running)
                return
            passwordForWpa = true
            requestPassword(name)
            return
        }
        if (/[\r\n]/.test(name) || /[\r\n]/.test(password || "")) {
            wpaError = "Network name or password contains an unsupported newline"
            return
        }
        if (!isOpen && !((password.length >= 8 && password.length <= 63)
                || /^[0-9a-fA-F]{64}$/.test(password))) {
            wpaError = "WPA password must be 8–63 characters or a 64-digit key"
            return
        }
        if (wpaAddNetwork.running || wpaAction.running)
            return
        pendingWpaName = name
        pendingWpaPassword = password || ""
        pendingWpaOpen = isOpen
        wpaError = ""
        wpaAddNetwork.exec(["wpa_cli", "-i", fallbackWifiInterface, "add_network"])
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
        wiredConnected = false
        wiredName = ""
        const nextWifiDevice = devices.find(device => device.type === DeviceType.Wifi) || null
        if (wifiDevice !== nextWifiDevice) {
            if (wifiDevice)
                wifiDevice.scannerEnabled = false
            wifiDevice = nextWifiDevice
            if (wifiDevice)
                wifiDevice.scannerEnabled = popup.visible
        }
        const wiredEntries = []

        for (const device of devices) {
            if (device.type !== DeviceType.Wired)
                continue

            const connectedNetwork = device.networks.values.find(network => network.connected)
            const name = connectedNetwork ? connectedNetwork.name : device.name
            wiredEntries.push({
                "deviceName": String(device.name || "Ethernet"),
                "displayName": String(name || "Ethernet"),
                "isConnected": !!device.connected
            })
            if (device.connected && !wiredConnected) {
                wiredConnected = true
                wiredName = String(name || device.name || "Ethernet")
            }
        }
        syncNetworkList(wiredDevices, wiredEntries)

        const networks = wifiDevice ? wifiDevice.networks.values.slice() : []
        nativeWifiNetworkCount = networks.length
        networks.sort((left, right) => {
            if (left.connected !== right.connected)
                return left.connected ? -1 : 1
            return right.signalStrength - left.signalStrength
        })

        wifiConnected = false
        wifiName = ""
        const wifiEntries = []
        for (const network of networks) {
            wifiEntries.push({
                "networkName": String(network.name || "Unknown"),
                "strength": Number(network.signalStrength || 0),
                "securityType": Number(network.security),
                "networkId": -1,
                "isKnown": !!network.known,
                "isConnected": !!network.connected
            })
            if (network.connected && !wifiConnected) {
                wifiConnected = true
                wifiName = String(network.name || "Wi-Fi")
            }
        }
        syncNetworkList(wifiNetworks, wifiEntries)
    }

    function syncNetworkList(model, entries) {
        // Preserve delegates (and the keyboard selection) when a poll finds
        // the same networks, instead of clearing and recreating every row.
        while (model.count > entries.length)
            model.remove(model.count - 1)
        for (let i = 0; i < entries.length; ++i) {
            const entry = entries[i]
            if (i >= model.count) {
                model.append(entry)
                continue
            }
            const current = model.get(i)
            for (const key of Object.keys(entry)) {
                if (current[key] !== entry[key])
                    model.setProperty(i, key, entry[key])
            }
        }
    }

    Component.onCompleted: refreshNetworkModel()

    ListModel { id: wiredDevices }
    ListModel { id: wifiNetworks }
    ListModel { id: wpaNetworks }

    Timer {
        interval: popup.visible ? 2000 : 10000
        repeat: true
        running: true
        onTriggered: root.refreshNetworkModel()
    }

    // `iw dev` identifies the wpa_supplicant interface without assuming a
    // distro-specific name such as wlan0. Then wpa_cli supplies the active
    // SSID. These processes only affect the compact bar indicator; the popup
    // continues to use Quickshell's native model for network actions.
    function refreshWpaSupplicantState() {
        if (fallbackWifiInterface) {
            if (!wpaStatus.running)
                wpaStatus.exec(["wpa_cli", "-i", fallbackWifiInterface, "status"])
        } else if (!wifiProbe.running) {
            wifiProbe.exec(["iw", "dev"])
        }
    }

    Timer {
        interval: root.fallbackWifiInterface ? 5000 : 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshWpaSupplicantState()
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.fallbackWifiInterface.length > 0
        onTriggered: if (!wifiProbe.running) wifiProbe.exec(["iw", "dev"])
    }

    Process {
        id: wpaScan
        onExited: exitCode => {
            if (exitCode === 0)
                wpaScanDelay.restart()
            else
                root.wpaError = "Could not scan Wi-Fi networks"
        }
    }

    Timer {
        id: wpaScanDelay
        interval: 1200
        onTriggered: root.refreshWpaScanResults()
    }

    Process {
        id: wpaKnownQuery
        stdout: StdioCollector {
            onStreamFinished: root.parseWpaNetworks(this.text)
        }
    }

    Process {
        id: wpaResults
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() === "FAIL")
                    root.wpaError = "Could not read Wi-Fi scan results"
                else
                    root.parseWpaScanResults(this.text)
            }
        }
    }

    Process {
        id: wpaAddNetwork
        stdout: StdioCollector {
            onStreamFinished: {
                const id = Number(this.text.trim())
                if (!Number.isInteger(id) || id < 0) {
                    root.wpaError = "Could not create Wi-Fi connection"
                    root.pendingWpaPassword = ""
                    return
                }
                const commands = [
                    "set_network " + id + " ssid " + root.wpaValue(root.pendingWpaName),
                    "set_network " + id + " key_mgmt "
                        + (root.pendingWpaOpen ? "NONE" : "WPA-PSK")
                ]
                if (!root.pendingWpaOpen)
                    commands.push("set_network " + id + " psk "
                        + root.wpaValue(root.pendingWpaPassword))
                commands.push("enable_network " + id)
                commands.push("select_network " + id)
                commands.push("save_config")
                root.pendingWpaPassword = ""
                root.runWpaAction(commands)
            }
        }
    }

    Process {
        id: wpaAction
        stdinEnabled: true
        onStarted: {
            wpaAction.write(root.wpaCommands.join("\n") + "\nquit\n")
            root.wpaCommands = []
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const replies = this.text.split(/\r?\n/)
                    .map(line => line.trim().replace(/^>\s*/, ""))
                    .filter(line => line === "OK" || line === "FAIL")
                const failedAt = replies.indexOf("FAIL")
                if (failedAt >= 0) {
                    root.wpaError = root.wpaSavingProfile
                        && failedAt === root.wpaCommandCount - 1
                        ? "Connected, but wpa_supplicant could not save this network"
                        : "Wi-Fi action failed; check wpa_supplicant permissions"
                }
                root.refreshWpaSupplicantState()
                root.refreshWpaNetworks()
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.wpaError = "Could not control wpa_supplicant"
        }
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
                    wpaNetworks.clear()
                    return
                }
                if (!wpaStatus.running)
                    wpaStatus.exec(["wpa_cli", "-i", root.fallbackWifiInterface, "status"])
                root.refreshWpaNetworks()
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
        if (vpnQuery.running) {
            vpnRefreshPending = true
            return
        }
        vpnQuery.exec(["nmcli", "-t", "--escape", "no", "-f", "NAME,UUID,TYPE,DEVICE", "connection", "show", "--active"])
    }

    function disconnectVpn(uuid) {
        if (vpnDisconnect.running)
            return
        vpnError = ""
        disconnectingVpnUuid = uuid
        vpnDisconnect.exec(["nmcli", "connection", "down", "uuid", uuid])
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshVpn()
    }

    Process {
        id: vpnMonitor
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: vpnRefreshDelay.restart()
        }
        onExited: vpnMonitorRetry.restart()
    }

    Timer {
        id: vpnRefreshDelay
        interval: 200
        onTriggered: root.refreshVpn()
    }

    Timer {
        id: vpnMonitorRetry
        interval: 3000
        onTriggered: vpnMonitor.running = true
    }

    function requestPassword(network) {
        if (passwordDialog.running)
            return

        passwordNetworkName = typeof network === "string" ? network : network.name
        // Unmap the layer-shell dismiss surface before Zenity appears.
        close()
        passwordDialog.exec([
            "zenity",
            "--password",
            "--title=Wi-Fi Password",
            "--text=Password for \"" + passwordNetworkName + "\""
        ])
    }

    Process {
        id: passwordDialog

        stdout: StdioCollector {
            onStreamFinished: {
                // Zenity appends one newline to its result; preserve every
                // other character in case the passphrase contains spaces.
                const password = this.text.replace(/\r?\n$/, "")
                if (root.passwordForWpa) {
                    if (password.length)
                        root.connectWpaNetwork(root.passwordNetworkName, -1, false, password)
                    root.passwordForWpa = false
                } else {
                    const network = root.findNetwork(root.passwordNetworkName)
                    if (password.length && network)
                        network.connectWithPsk(password)
                }
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
                    const uuidSeparator = line.lastIndexOf(":", typeSeparator - 1)
                    if (uuidSeparator < 0) continue

                    const name = line.slice(0, uuidSeparator)
                    const uuid = line.slice(uuidSeparator + 1, typeSeparator)
                    const type = line.slice(typeSeparator + 1, deviceSeparator)
                    const device = line.slice(deviceSeparator + 1)
                    const tunnelDevice = /^(tun|tap|wg|proton)/i.test(device)
                    const vpnProfile = /proton/i.test(name)

                    if (type === "vpn" || type === "wireguard" || type === "tun" || tunnelDevice || vpnProfile)
                        activeVpns.push({ "name": name, "uuid": uuid })
                }
                root.vpnConnections = activeVpns
            }
        }
        onExited: {
            if (root.vpnRefreshPending) {
                root.vpnRefreshPending = false
                vpnRefreshDelay.restart()
            }
        }
    }

    Process {
        id: vpnDisconnect
        onExited: exitCode => {
            root.disconnectingVpnUuid = ""
            if (exitCode !== 0)
                root.vpnError = "Could not disconnect VPN"
            root.refreshVpn()
        }
    }

    Text {
        text: root.icon
        color: root.wiredConnected || (root.wifiRadioEnabled && root.hasWifiConnection) ? root.accent : Theme.grey
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize
    }

    Text {
        visible: root.vpnConnections.length > 0
        text: String.fromCodePoint(0xf033e)
        color: root.accent
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize
    }

    Text {
        text: root.wiredConnected ? root.wiredName
              : !root.wifiRadioEnabled ? "off"
              : root.hasWifiConnection ? root.currentWifiName : "N/A"
        color: root.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        elide: Text.ElideRight
        Layout.maximumWidth: 90
        visible: !root.compactMode
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
            x: root.panelWindow.popupAnchorX(root, popup.implicitWidth, popup.visible)
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
                root.refreshWpaNetworks()
            }
            if (!visible)
                root.popupCoordinator.hidePopup(root)
        }

        Timer {
            interval: 5000
            repeat: true
            running: popup.visible
            onTriggered: {
                root.refreshWpaNetworks()
            }
        }

        PopupSurface {
            anchors.fill: parent
            shown: popup.visible
            color: Theme.bg1
            border.width: 2
            border.color: root.accent

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
                        color: root.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.headingFontSize
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
                                color: isConnected ? root.accent : Theme.fg
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
                        color: root.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.headingFontSize
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
                        delegate: RowLayout {
                            id: vpnRow
                            required property var modelData
                            width: parent.width
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: vpnRow.modelData.name
                                color: root.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                implicitWidth: vpnDisconnectLabel.implicitWidth + 10
                                implicitHeight: vpnDisconnectLabel.implicitHeight + 4
                                color: Theme.bgred
                                border.width: 1
                                border.color: Theme.red

                                Text {
                                    id: vpnDisconnectLabel
                                    anchors.centerIn: parent
                                    text: root.disconnectingVpnUuid === vpnRow.modelData.uuid
                                        ? "Disconnecting…" : "Disconnect"
                                    color: Theme.red
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 2
                                }

                                TapHandler {
                                    onTapped: root.disconnectVpn(vpnRow.modelData.uuid)
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.vpnError.length > 0
                        text: root.vpnError
                        color: Theme.red
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4

                    Text {
                        text: "Wi-Fi"
                        color: root.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.headingFontSize
                    }

                    Text {
                        visible: !root.wifiRadioEnabled
                        text: "Wi-Fi is off"
                        color: Theme.grey
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        visible: root.useWpaFallback && root.wpaError.length > 0
                        width: parent.width
                        text: root.wpaError
                        color: Theme.red
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        wrapMode: Text.Wrap
                    }

                    Text {
                        visible: root.wifiRadioEnabled
                            && (root.useWpaFallback ? wpaNetworks.count : wifiNetworks.count) === 0
                            && root.wpaError.length === 0
                        text: "No networks found"
                        color: Theme.grey
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Repeater {
                        id: networkRepeater
                        model: root.useWpaFallback ? wpaNetworks : wifiNetworks
                        delegate: Column {
                            required property int index
                            required property string networkName
                            required property real strength
                            required property int securityType
                            required property bool isKnown
                            required property bool isConnected
                            required property int networkId
                            width: parent.width

                            RowLayout {
                                width: parent.width
                                spacing: 6

                                Text {
                                    Layout.fillWidth: true
                                    text: (root.keyboardNetworkIndex === index ? "› " : "  ")
                                        + networkName + "   " + Math.round(strength * 100) + "%"
                                    color: isConnected || root.keyboardNetworkIndex === index
                                        ? root.accent : Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize

                                    TapHandler {
                                        onTapped: {
                                            root.keyboardNetworkIndex = index
                                            root.activateNetwork(networkName, securityType, isKnown,
                                                isConnected, networkId)
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
                                            if (root.useWpaFallback) {
                                                root.runWpaAction(["disconnect"])
                                                return
                                            }
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
                                visible: index < (root.useWpaFallback
                                    ? wpaNetworks.count : wifiNetworks.count) - 1
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
        id: dismissLayer
        visible: popup.visible
        anchors { top: true; bottom: true; left: true; right: true }
        margins.top: root.panelWindow.height
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: if (visible) Qt.callLater(() => keyCapture.forceActiveFocus())

        Item {
            id: keyCapture
            anchors.fill: parent
            focus: dismissLayer.visible
            Keys.onPressed: event => root.handleKeyPressed(event)
            MouseArea { anchors.fill: parent; onClicked: root.close() }
        }
    }

}
