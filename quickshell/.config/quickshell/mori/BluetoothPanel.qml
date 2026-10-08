import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import "./theme"

Column {
    id: root
    property color accent: Theme.blue
    property bool active: false
    property int selectedIndex: 0
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter ? adapter.devices.values : []
    property var scanningAdapter: null
    spacing: 8

    function stopScan() {
        if (scanningAdapter) scanningAdapter.discovering = false
        scanningAdapter = null
    }
    onActiveChanged: if (!active) stopScan()
    onAdapterChanged: { stopScan(); selectedIndex = 0 }
    Component.onDestruction: stopScan()

    function activateDevice(device) {
        if (!device || device.blocked || device.pairing
            || device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting) return
        if (device.connected) device.disconnect()
        else if (device.paired) device.connect()
        else device.pair()
    }
    function handleKeyPressed(event) {
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            selectedIndex = Math.max(0, Math.min(devices.length - 1,
                selectedIndex + (event.key === Qt.Key_Up ? -1 : 1)))
            const row = deviceRepeater.itemAt(selectedIndex)
            if (row) row.ensureVisible()
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!event.isAutoRepeat) activateDevice(devices[selectedIndex])
        } else if (event.key === Qt.Key_D) {
            const device = devices[selectedIndex]
            if (!event.isAutoRepeat && device && device.connected) device.disconnect()
        } else return
        event.accepted = true
    }

    RowLayout {
        width: parent.width
        spacing: 6
        Repeater {
            model: ["power", "scan"]
            delegate: Rectangle {
                required property string modelData
                readonly property bool power: modelData === "power"
                readonly property bool available: !!root.adapter && (power
                    ? root.adapter.state !== BluetoothAdapterState.Blocked
                        && root.adapter.state !== BluetoothAdapterState.Enabling
                        && root.adapter.state !== BluetoothAdapterState.Disabling
                    : root.adapter.enabled)
                readonly property bool selected: !!root.adapter
                    && (power ? root.adapter.enabled : root.adapter.discovering)
                Layout.fillWidth: true
                implicitHeight: Theme.controlHeight
                color: Theme.controlBackground(selected, false, controlHover.hovered && available)
                border.width: 1
                border.color: Theme.controlBorder(selected, false, controlHover.hovered && available, root.accent)
                Text {
                    anchors.centerIn: parent
                    text: parent.power ? "Bluetooth " + (parent.selected ? "on" : "off")
                        : parent.selected ? "Stop scan" : "Scan"
                    color: !parent.available ? Theme.disabledText : parent.selected ? root.accent : Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                HoverHandler { id: controlHover }
                TapHandler {
                    enabled: parent.available
                    onTapped: {
                        if (parent.power) {
                            root.stopScan()
                            root.adapter.enabled = !root.adapter.enabled
                        } else if (root.adapter.discovering) {
                            root.adapter.discovering = false
                            root.scanningAdapter = null
                        }
                        else {
                            root.scanningAdapter = root.adapter
                            root.adapter.discovering = true
                        }
                    }
                }
            }
        }
    }

    Text {
        width: parent.width
        visible: !root.adapter || !root.adapter.enabled || root.devices.length === 0
        text: !root.adapter ? "No Bluetooth adapter available"
            : root.adapter.state === BluetoothAdapterState.Blocked ? "Bluetooth is blocked"
            : !root.adapter.enabled ? "Bluetooth is off"
            : root.adapter.discovering ? "Searching for devices…" : "No devices found · Scan to discover devices"
        color: Theme.grey
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        wrapMode: Text.Wrap
    }

    Repeater {
        id: deviceRepeater
        model: root.adapter && root.adapter.enabled ? root.devices : []
        delegate: Rectangle {
            id: deviceRow
            required property var modelData
            required property int index
            readonly property bool selected: root.selectedIndex === index
            readonly property bool busy: modelData.pairing
                || modelData.state === BluetoothDeviceState.Connecting
                || modelData.state === BluetoothDeviceState.Disconnecting
            width: parent.width
            implicitHeight: Theme.controlHeight + 20
            color: Theme.controlBackground(modelData.connected, selected, rowHover.hovered)
            border.width: 1
            border.color: Theme.controlBorder(modelData.connected, selected, rowHover.hovered, root.accent)

            function ensureVisible() {
                // The panel shares the network popup's scrollable column.
                let scroll = root.parent
                while (scroll && scroll.contentY === undefined) scroll = scroll.parent
                if (!scroll) return
                const y = mapToItem(scroll.contentItem, 0, 0).y
                if (y < scroll.contentY) scroll.contentY = y
                else if (y + height > scroll.contentY + scroll.height)
                    scroll.contentY = y + height - scroll.height
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6
                Column {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Text {
                        width: parent.width
                        text: (deviceRow.selected ? "› " : "  ")
                            + (deviceRow.modelData.name || deviceRow.modelData.address)
                        color: deviceRow.modelData.connected ? root.accent : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: deviceRow.modelData.blocked ? "Blocked"
                            : deviceRow.modelData.pairing ? "Pairing…"
                            : BluetoothDeviceState.toString(deviceRow.modelData.state)
                                + (deviceRow.modelData.paired ? " · Paired" : " · Not paired")
                                + (deviceRow.modelData.batteryAvailable
                                    ? " · " + Math.round(deviceRow.modelData.battery * 100) + "%" : "")
                        color: Theme.grey
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                        elide: Text.ElideRight
                    }
                }
                Text {
                    text: deviceRow.busy ? "…" : deviceRow.modelData.connected ? "Disconnect"
                        : deviceRow.modelData.paired ? "Connect" : "Pair"
                    color: deviceRow.modelData.blocked || deviceRow.busy ? Theme.disabledText
                        : deviceRow.modelData.connected ? Theme.red : root.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
            }
            HoverHandler { id: rowHover }
            TapHandler {
                onTapped: {
                    root.selectedIndex = index
                    root.activateDevice(modelData)
                }
            }
        }
    }
}
