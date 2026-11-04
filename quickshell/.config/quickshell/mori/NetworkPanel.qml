import QtQuick
import QtQuick.Layouts
import "./theme"

// The network popup's content, also shown in Settings → Network. State and
// actions live in NetworkService; only the keyboard selection is local.
PopupSurface {
    id: root

    required property var service
    property color accent: Theme.blue
    // Inside Settings: no card, no duplicate header, Escape goes back.
    property bool embedded: false
    property bool bluetoothView: false
    property int keyboardNetworkIndex: 0
    readonly property alias bluetoothPanel: bluetoothControls

    function setView(bluetooth) {
        bluetoothView = bluetooth
        keyboardNetworkIndex = 0
        listCol.contentY = 0
    }
    function networkCount() { return service.useWpaFallback ? service.wpaNetworks.count : service.wifiNetworks.count }
    function selectionCount() { return service.wiredDevices.count + service.vpnConnections.length + networkCount() }
    function moveNetworkSelection(offset) {
        keyboardNetworkIndex = Math.max(0, Math.min(selectionCount() - 1,
            keyboardNetworkIndex + offset))
        let index = keyboardNetworkIndex
        let repeater = wiredRepeater
        if (index >= service.wiredDevices.count) {
            index -= service.wiredDevices.count
            repeater = vpnRepeater
            if (index >= service.vpnConnections.length) {
                index -= service.vpnConnections.length
                repeater = networkRepeater
            }
        }
        const item = repeater ? repeater.itemAt(index) : null
        if (item && listCol) {
            const y = item.mapToItem(listCol.contentItem, 0, 0).y
            if (y < listCol.contentY)
                listCol.contentY = y
            else if (y + item.height > listCol.contentY + listCol.height)
                listCol.contentY = y + item.height - listCol.height
        }
    }

    function actOnSelection(disconnect) {
        if (selectionCount() === 0) return
        keyboardNetworkIndex = Math.max(0, Math.min(keyboardNetworkIndex, selectionCount() - 1))
        let index = keyboardNetworkIndex
        if (index < service.wiredDevices.count) {
            const entry = service.wiredDevices.get(index)
            if (disconnect) service.disconnectWiredDevice(entry.deviceName)
            else service.connectWiredDevice(entry.deviceName)
            return
        }
        index -= service.wiredDevices.count
        if (index < service.vpnConnections.length) {
            if (disconnect) service.disconnectVpn(service.vpnConnections[index].uuid)
            return
        }
        index -= service.vpnConnections.length
        const entry = (service.useWpaFallback ? service.wpaNetworks : service.wifiNetworks).get(index)
        if (disconnect) {
            if (entry.isConnected) service.disconnectNetwork(entry.networkName)
        } else {
            service.activateNetwork(entry.networkName, entry.securityType, entry.isKnown,
                entry.isConnected, entry.networkId)
        }
    }
    // Returns true when the key was used; hosts handle Escape.
    function handleKey(event) {
        if (event.modifiers !== Qt.NoModifier) return false
        if (event.key === Qt.Key_Tab) {
            if (!event.isAutoRepeat) setView(!bluetoothView)
        } else if (bluetoothView) {
            bluetoothControls.handleKeyPressed(event)
            return event.accepted
        } else if (event.key === Qt.Key_Up) moveNetworkSelection(-1)
        else if (event.key === Qt.Key_Down) moveNetworkSelection(1)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!event.isAutoRepeat) actOnSelection(false)
        } else if (event.key === Qt.Key_D) {
            if (!event.isAutoRepeat) actOnSelection(true)
        } else return false
        return true
    }

    Component.onCompleted: service.viewers++
    Component.onDestruction: service.viewers--

    implicitHeight: listCol.implicitHeight + networkHint.implicitHeight + 34
    anchors.fill: parent
    color: root.embedded ? "transparent" : Theme.bg1
    border.width: root.embedded ? 0 : 2
    border.color: root.accent

    ScrollableColumn {
        id: listCol
        anchors.top: parent.top
        anchors.bottom: networkHint.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        anchors.bottomMargin: 10
        spacing: 12

        WidgetHeader { text: "Network"; color: root.accent; visible: !root.embedded }

        RowLayout {
            width: parent.width
            spacing: 6
            Repeater {
                model: ["Network", "Bluetooth"]
                delegate: Rectangle {
                    required property int index
                    required property string modelData
                    readonly property bool selected: root.bluetoothView === (index === 1)
                    Layout.fillWidth: true
                    implicitHeight: Theme.controlHeight
                    color: Theme.controlBackground(selected, false, tabHover.hovered)
                    border.width: 1
                    border.color: Theme.controlBorder(selected, false, tabHover.hovered, root.accent)
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: parent.selected ? root.accent : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    HoverHandler { id: tabHover }
                    TapHandler { onTapped: root.setView(index === 1) }
                }
            }
        }

        BluetoothPanel {
            id: bluetoothControls
            width: parent.width
            accent: root.accent
            visible: root.bluetoothView
            active: root.bluetoothView
        }

        Column {
            width: parent.width
            spacing: 4
            visible: !root.bluetoothView && root.service.wiredDevices.count > 0

            WidgetHeader {
                text: "Ethernet"
                color: root.accent
            }

            Repeater {
                id: wiredRepeater
                model: root.service.wiredDevices
                delegate: Rectangle {
                    id: wiredRow
                    required property int index
                    required property string deviceName
                    required property string displayName
                    required property bool isConnected
                    readonly property bool selected: root.keyboardNetworkIndex === index
                    width: parent.width
                    implicitHeight: Theme.controlHeight
                    color: Theme.controlBackground(isConnected, selected, rowHover.hovered)
                    border.width: 1
                    border.color: Theme.controlBorder(isConnected, selected, rowHover.hovered, root.accent)
                    HoverHandler { id: rowHover }

                    RowLayout {
                        id: rowContents
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        Column {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 1
                            Text {
                                width: parent.width
                                text: (wiredRow.selected ? "› " : "  ") + displayName
                                color: isConnected ? root.accent : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                            }

                            TapHandler {
                                onTapped: {
                                    root.keyboardNetworkIndex = index
                                    root.service.connectWiredDevice(deviceName)
                                }
                            }
                        }

                        Rectangle {
                            visible: isConnected
                            implicitWidth: disconnectLabel.implicitWidth + 10
                            implicitHeight: Theme.controlHeight - 8
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
                                    root.keyboardNetworkIndex = index
                                    root.service.disconnectWiredDevice(deviceName)
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                visible: !root.bluetoothView && root.service.wiredDevices.count > 0
                color: Theme.bg4
            }
        }

        Column {
            width: parent.width
            spacing: 4

            visible: !root.bluetoothView

            WidgetHeader {
                text: "VPN"
                color: root.accent
            }

            Text {
                visible: root.service.vpnConnections.length === 0
                text: "Not connected"
                color: Theme.grey
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Repeater {
                id: vpnRepeater
                model: root.service.vpnConnections
                delegate: Rectangle {
                    id: vpnRow
                    required property int index
                    required property var modelData
                    readonly property bool selected: root.keyboardNetworkIndex === root.service.wiredDevices.count + index
                    width: parent.width
                    implicitHeight: Theme.controlHeight
                    color: Theme.controlBackground(true, selected, rowHover.hovered)
                    border.width: 1
                    border.color: Theme.controlBorder(true, selected, rowHover.hovered, root.accent)
                    HoverHandler { id: rowHover }

                    RowLayout {
                        id: rowContents
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        Column {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 1
                            Text {
                                width: parent.width
                                text: (vpnRow.selected ? "› " : "  ") + vpnRow.modelData.name
                                color: root.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                            }

                            TapHandler {
                                onTapped: {
                                    root.keyboardNetworkIndex = root.service.wiredDevices.count + index
                                }
                            }
                        }

                        Rectangle {
                            visible: true
                            implicitWidth: disconnectLabel.implicitWidth + 10
                            implicitHeight: Theme.controlHeight - 8
                            color: Theme.bgred
                            border.width: 1
                            border.color: Theme.red

                            Text {
                                id: disconnectLabel
                                anchors.centerIn: parent
                                text: root.service.disconnectingVpnUuid === vpnRow.modelData.uuid
                                    ? "Disconnecting…" : "Disconnect"
                                color: Theme.red
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }
                            TapHandler {
                                onTapped: {
                                    root.keyboardNetworkIndex = root.service.wiredDevices.count + index
                                    root.service.disconnectVpn(vpnRow.modelData.uuid)
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.service.vpnError.length > 0
                text: root.service.vpnError
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }

        Column {
            width: parent.width
            spacing: 4

            visible: !root.bluetoothView

            WidgetHeader {
                text: "Wi-Fi"
                color: root.accent
            }

            Text {
                visible: !root.service.wifiRadioEnabled
                text: "Wi-Fi is off"
                color: Theme.grey
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Text {
                visible: root.service.useWpaFallback && root.service.wpaError.length > 0
                width: parent.width
                text: root.service.wpaError
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                wrapMode: Text.Wrap
            }

            Text {
                visible: root.service.wifiRadioEnabled
                    && (root.service.useWpaFallback ? root.service.wpaNetworks.count : root.service.wifiNetworks.count) === 0
                    && root.service.wpaError.length === 0
                text: "No networks found"
                color: Theme.grey
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Repeater {
                id: networkRepeater
                model: root.service.useWpaFallback ? root.service.wpaNetworks : root.service.wifiNetworks
                delegate: Rectangle {
                    id: wifiRow
                    required property int index
                    required property string networkName
                    required property real strength
                    required property int securityType
                    required property bool isKnown
                    required property bool isConnected
                    required property int networkId
                    readonly property bool selected: root.keyboardNetworkIndex === root.service.wiredDevices.count + root.service.vpnConnections.length + index
                    width: parent.width
                    implicitHeight: Theme.controlHeight
                    color: Theme.controlBackground(isConnected, selected, rowHover.hovered)
                    border.width: 1
                    border.color: Theme.controlBorder(isConnected, selected, rowHover.hovered, root.accent)
                    HoverHandler { id: rowHover }

                    RowLayout {
                        id: rowContents
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        Column {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 1
                            Text {
                                width: parent.width
                                text: (wifiRow.selected ? "› " : "  ") + networkName + "   " + Math.round(strength * 100) + "%"
                                color: isConnected ? root.accent : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                            }

                            TapHandler {
                                onTapped: {
                                    root.keyboardNetworkIndex = root.service.wiredDevices.count + root.service.vpnConnections.length + index
                                    root.service.activateNetwork(networkName, securityType, isKnown, isConnected, networkId)
                                }
                            }
                        }

                        Rectangle {
                            visible: isConnected
                            implicitWidth: disconnectLabel.implicitWidth + 10
                            implicitHeight: Theme.controlHeight - 8
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
                                    root.keyboardNetworkIndex = root.service.wiredDevices.count + root.service.vpnConnections.length + index
                                    root.service.disconnectNetwork(networkName)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    KeyboardHint {
        id: networkHint
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        text: root.bluetoothView
            ? "Tab: Network / Bluetooth · ↑↓: select\nEnter: pair / connect · D: disconnect · Esc: " + (root.embedded ? "back" : "close")
            : "Tab: Network / Bluetooth · ↑↓: select\nEnter: connect · D: disconnect · Esc: " + (root.embedded ? "back" : "close")
    }

}
