import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Network state and actions: NetworkManager through Quickshell.Networking,
// a wpa_supplicant fallback, and VPN status from nmcli. One instance lives in
// shell.qml; the bar's Network widget and Settings → Network are views of it.
Item {
    id: root
    visible: false

    // Asks for Wi-Fi passwords (Prompt.qml in shell.qml).
    required property var prompt
    // Open NetworkPanels; Wi-Fi scanning and fast polling run while one is shown.
    property int viewers: 0
    readonly property bool panelShown: viewers > 0
    property ListModel wiredDevices: ListModel {}
    property ListModel wifiNetworks: ListModel {}
    property ListModel wpaNetworks: ListModel {}

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
    // False once wpa_cli cannot reach the control socket, e.g. when
    // NetworkManager owns wpa_supplicant. Opening the popup retries once.
    property bool wpaReachable: true
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
    readonly property bool useWpaFallback: fallbackWifiInterface.length > 0 && wpaReachable
        && (!wifiDevice || (!wifiConnected && nativeWifiNetworkCount === 0))
    readonly property bool hasWifiConnection: wifiConnected || fallbackWifiConnected
    readonly property bool wifiRadioEnabled: Networking.wifiEnabled
        || (fallbackWifiInterface.length > 0 && wpaReachable)
    readonly property string currentWifiName: wifiConnected ? wifiName : fallbackWifiName
    readonly property string icon: {
        if (wiredConnected) return String.fromCodePoint(0xf0200)
        if (!wifiRadioEnabled || !hasWifiConnection) return String.fromCodePoint(0xf092d)
        return String.fromCodePoint(0xf0928)
    }


    onPanelShownChanged: {
        if (wifiDevice)
            wifiDevice.scannerEnabled = panelShown
        if (!panelShown)
            return
        if (!wpaReachable) {
            wpaReachable = true
            refreshWpaSupplicantState()
        }
        refreshNetworkModel()
        refreshVpn()
        refreshWpaNetworks()
    }

    function findWiredDevice(name) {
        return Networking.devices.values.find(device => device.type === DeviceType.Wired
            && device.name === name)
    }

    function connectWiredDevice(name) {
        const device = findWiredDevice(name)
        if (device && !device.connected && device.network)
            device.network.connect()
    }

    function disconnectWiredDevice(name) {
        const device = findWiredDevice(name)
        if (device && device.connected)
            device.disconnect()
    }

    function disconnectNetwork(name) {
        if (useWpaFallback) {
            if (fallbackWifiConnected && fallbackWifiName === name)
                runWpaAction(["disconnect"])
            return
        }
        const network = findNetwork(name)
        if (network && network.connected)
            network.disconnect()
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
        if (!useWpaFallback || !panelShown)
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
        if (useWpaFallback && panelShown && !wpaResults.running)
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
        // No escaping: wpa_supplicant takes everything between the first and
        // last quote literally (tested with a password containing " and \).
        return "\"" + value + "\""
    }

    function connectWpaNetwork(name, networkId, isOpen, password) {
        if (networkId >= 0) {
            runWpaAction(["select_network " + networkId])
            return
        }
        if (!isOpen && !password) {
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
        let nextWiredConnected = false
        let nextWiredName = ""
        const nextWifiDevice = devices.find(device => device.type === DeviceType.Wifi) || null
        if (wifiDevice !== nextWifiDevice) {
            if (wifiDevice)
                wifiDevice.scannerEnabled = false
            wifiDevice = nextWifiDevice
            if (wifiDevice)
                wifiDevice.scannerEnabled = panelShown
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
            if (device.connected && !nextWiredConnected) {
                nextWiredConnected = true
                nextWiredName = String(name || device.name || "Ethernet")
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

        let nextWifiConnected = false
        let nextWifiName = ""
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
            if (network.connected && !nextWifiConnected) {
                nextWifiConnected = true
                nextWifiName = String(network.name || "Wi-Fi")
            }
        }
        syncNetworkList(wifiNetworks, wifiEntries)
        wiredConnected = nextWiredConnected
        wiredName = nextWiredName
        wifiConnected = nextWifiConnected
        wifiName = nextWifiName
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


    Timer {
        interval: panelShown ? 2000 : 10000
        repeat: true
        running: true
        onTriggered: root.refreshNetworkModel()
    }

    // `iw dev` identifies the wpa_supplicant interface without assuming a
    // distro-specific name such as wlan0. Then wpa_cli supplies the active
    // SSID. These processes only affect the compact bar indicator; the popup
    // continues to use Quickshell's native model for network actions.
    function refreshWpaSupplicantState() {
        if (!wpaReachable)
            return
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
        running: root.wpaReachable
        triggeredOnStart: true
        onTriggered: root.refreshWpaSupplicantState()
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.fallbackWifiInterface.length > 0 && root.wpaReachable
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
        onExited: exitCode => {
            if (exitCode === 0)
                return
            root.wpaReachable = false
            root.fallbackWifiConnected = false
            root.fallbackWifiName = ""
            root.fallbackWifiSignal = 0
            wpaNetworks.clear()
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

    // `nmcli monitor` below drives updates; this only covers missed events.
    Timer {
        interval: 60000
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

    // Picking another network while the prompt is open replaces the prompt;
    // each request keeps its own network, so the replaced one can't clear it.
    function requestPassword(network) {
        const name = typeof network === "string" ? network : network.name
        const forWpa = passwordForWpa
        function done() {
            if (passwordNetworkName !== name) return
            passwordNetworkName = ""
            passwordForWpa = false
        }
        passwordNetworkName = name
        prompt.ask({
            "title": "Wi-Fi password",
            "text": "Password for \"" + name + "\"",
            "password": true,
            "accept": "Connect"
        }, password => {
            done()
            if (!password.length) return
            if (forWpa) {
                connectWpaNetwork(name, -1, false, password)
            } else {
                const target = findNetwork(name)
                if (target) target.connectWithPsk(password)
            }
        }, done)
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

    // Re-scan the wpa_supplicant fallback while a panel is open.
    Timer {
        interval: 5000
        repeat: true
        running: root.panelShown
        onTriggered: root.refreshWpaNetworks()
    }
}
