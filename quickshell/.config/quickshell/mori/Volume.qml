import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "./theme"

RowLayout {
    id: root
    readonly property var deviceList: popupContent.item ? popupContent.item.deviceListRef : null
    readonly property var deviceRepeater: popupContent.item ? popupContent.item.deviceRepeaterRef : null
    readonly property var appRepeater: popupContent.item ? popupContent.item.appRepeaterRef : null
    readonly property var masterControl: popupContent.item ? popupContent.item.masterControlRef : null
    property color accent: Theme.yellow
    property bool compactMode: false
    spacing: 6

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    property var keyboardNode: null
    property bool microphoneView: false
    property bool devicePickerOpen: false
    readonly property var currentDevice: {
        const device = microphoneView ? source : sink
        return device && device.ready && device.audio ? device : null
    }
    onCurrentDeviceChanged: {
        if (devicePopup.visible && !devicePickerOpen && (!keyboardNode || !keyboardNode.isStream))
            keyboardNode = currentDevice
    }
    required property var panelWindow
    required property var popupCoordinator

    function togglePopup() {
        if (devicePopup.visible)
            close()
        else {
            popupCoordinator.showPopup(root)
            devicePopup.visible = true
            keyboardNode = currentDevice
        }
    }

    function close() {
        devicePopup.visible = false
        devicePickerOpen = false
        keyboardNode = null
    }

    function setView(microphone) {
        microphoneView = microphone
        devicePickerOpen = false
        keyboardNode = currentDevice
        if (deviceList) deviceList.contentY = 0
    }

    function audioNodes() {
        return Pipewire.nodes.values.filter(node => node && node.ready && node.audio)
    }
    function deviceNodes() {
        return audioNodes().filter(node => !node.isStream && node.isSink !== microphoneView)
    }
    function appNodes() {
        return microphoneView ? [] : audioNodes().filter(node => node.isSink && node.isStream)
    }
    function selectableNodes() {
        if (devicePickerOpen) return deviceNodes()
        return (currentDevice && currentDevice.ready && currentDevice.audio ? [currentDevice] : [])
            .concat(appNodes())
    }
    function toggleDevicePicker() {
        if (!devicePickerOpen && deviceNodes().length === 0) return
        if (devicePickerOpen) {
            devicePickerOpen = false
            keyboardNode = currentDevice
        } else {
            devicePickerOpen = true
            keyboardNode = currentDevice || deviceNodes()[0] || null
        }
    }
    function moveKeyboardSelection(offset) {
        const nodes = selectableNodes()
        if (nodes.length === 0) { keyboardNode = null; return }
        const current = nodes.indexOf(keyboardNode)
        keyboardNode = nodes[Math.max(0, Math.min(nodes.length - 1,
            current < 0 ? 0 : current + offset))]
        Qt.callLater(() => {
            if (!deviceList) return
            if (!devicePickerOpen && keyboardNode === currentDevice) {
                deviceList.contentY = 0
                return
            }
            const repeater = devicePickerOpen ? deviceRepeater : appRepeater
            if (!repeater) return
            for (let i = 0; i < repeater.count; i++) {
                const item = repeater.itemAt(i)
                if (!item || item.modelData !== keyboardNode) continue
                const y = item.mapToItem(deviceList.contentItem, 0, 0).y
                if (y < deviceList.contentY) deviceList.contentY = y
                else if (y + item.height > deviceList.contentY + deviceList.height)
                    deviceList.contentY = y + item.height - deviceList.height
                return
            }
        })
    }
    function handleKeyPressed(event) {
        if (event.key === Qt.Key_Escape) {
            if (devicePickerOpen) toggleDevicePicker()
            else close()
        } else if (event.modifiers !== Qt.NoModifier) return
        else if (event.key === Qt.Key_Tab) {
            if (!event.isAutoRepeat) setView(!microphoneView)
        } else if (event.key === Qt.Key_Up) moveKeyboardSelection(-1)
        else if (event.key === Qt.Key_Down) moveKeyboardSelection(1)
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            if (keyboardNode && keyboardNode.audio)
                setVolume(keyboardNode, keyboardNode.audio.volume
                    + (event.key === Qt.Key_Left ? -0.05 : 0.05))
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!event.isAutoRepeat) {
                if (devicePickerOpen) selectDevice(keyboardNode)
                else if (!keyboardNode || !keyboardNode.isStream) toggleDevicePicker()
            }
        } else if (event.key === Qt.Key_M) {
            if (!event.isAutoRepeat) toggleNodeMute(keyboardNode)
        } else return
        event.accepted = true
    }

    function selectDevice(node) {
        if (!node || !node.ready || !node.audio || node.isStream) return
        if (node.isSink) Pipewire.preferredDefaultAudioSink = node
        else Pipewire.preferredDefaultAudioSource = node
        devicePickerOpen = false
        keyboardNode = node
    }

    function toggleNodeMute(node) {
        if (node && node.ready && node.audio) {
            keyboardNode = node
            node.audio.muted = !node.audio.muted
        }
    }

    function setVolume(node, value) {
        if (node && node.ready && node.audio)
            node.audio.volume = Math.max(0, Math.min(1, value))
    }

    function adjustVolume(delta) {
        if (!root.sink || !root.sink.audio)
            return

        setVolume(root.sink, root.sink.audio.volume + delta)
    }

    function toggleMute() {
        if (root.sink && root.sink.audio)
            root.sink.audio.muted = !root.sink.audio.muted
    }

    PwObjectTracker {
        // Track discovery independently of audio readiness. Filtering by audio
        // before tracking can prevent newly discovered nodes from becoming ready.
        objects: devicePopup.visible ? Pipewire.nodes.values : (root.sink ? [root.sink] : [])
    }

    BarLabel {
        text: root.sink && root.sink.audio && root.sink.audio.muted
              ? String.fromCodePoint(0xf0583)
              : String.fromCodePoint(0xf057e)
        color: root.sink ? root.accent : Theme.grey
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize

        TapHandler {
            enabled: root.compactMode || (root.sink && root.sink.audio)
            onTapped: {
                if (root.compactMode)
                    root.togglePopup()
                else
                    root.sink.audio.muted = !root.sink.audio.muted
            }
        }
    }

    Slider {
        id: slider
        from: 0
        to: 1
        stepSize: 0.01
        implicitWidth: 110
        implicitHeight: 20
        visible: !root.compactMode
        enabled: root.sink && root.sink.audio
        value: enabled ? root.sink.audio.volume : 0

        // onMoved is emitted only for user interaction, leaving the binding
        // above intact for volume changes from media keys or other tools.
        onMoved: root.setVolume(root.sink, value)

        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 4
            radius: 0
            color: Theme.bg4

            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 0
                color: root.accent
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 10
            height: 10
            radius: 0
            color: root.accent
        }
    }

    BarLabel {
        id: deviceArrow
        visible: !root.compactMode
        text: devicePopup.visible ? "▴" : "▾"
        color: root.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize

        TapHandler {
            onTapped: root.togglePopup()
        }
    }

    PopupWindow {
        id: devicePopup
        implicitWidth: 400
        implicitHeight: Math.min(popupContent.item ? popupContent.item.implicitHeight : 80, 440)
        visible: false
        color: "transparent"
        grabFocus: false
        onVisibleChanged: if (!visible) root.popupCoordinator.hidePopup(root)

        anchor.window: root.panelWindow
        anchor.rect {
            x: root.panelWindow.popupAnchorX(
                root, devicePopup.implicitWidth, devicePopup.visible)
            y: parentWindow.height + 6
            width: 1
            height: 1
        }
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left

        Loader {
            id: popupContent
            anchors.fill: parent
            active: devicePopup.visible

            sourceComponent: Component {
                PopupSurface {
                    readonly property alias deviceListRef: deviceList
                    readonly property alias deviceRepeaterRef: deviceRepeater
                    readonly property alias appRepeaterRef: appRepeater
                    readonly property alias masterControlRef: masterControl
                    implicitHeight: deviceList.implicitHeight + volumeHint.implicitHeight + 36
                    anchors.fill: parent
                    shown: devicePopup.visible
                    color: Theme.bg1
                    border.width: 2
                    border.color: root.accent

                    ScrollableColumn {
                        id: deviceList
                        anchors.top: parent.top
                        anchors.bottom: volumeHint.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 12
                        anchors.bottomMargin: 10
                        spacing: 12

                        WidgetHeader { text: "Volume"; color: root.accent }

                        RowLayout {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: ["Playback", "Microphone"]
                                delegate: Rectangle {
                                    required property int index
                                    required property string modelData
                                    readonly property bool selected: root.microphoneView === (index === 1)
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

                        Rectangle {
                            id: devicePicker
                            width: parent.width
                            height: Theme.controlHeight
                            readonly property bool available: root.deviceNodes().length > 0
                            color: Theme.controlBackground(false, root.devicePickerOpen
                                || !!root.currentDevice && root.keyboardNode === root.currentDevice, pickerHover.hovered && available)
                            border.width: 1
                            border.color: Theme.controlBorder(false, root.devicePickerOpen
                                || !!root.currentDevice && root.keyboardNode === root.currentDevice, pickerHover.hovered && available, root.accent)
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                Text {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: root.currentDevice
                                        ? root.currentDevice.description || root.currentDevice.nickname || root.currentDevice.name
                                        : devicePicker.available ? "Choose a device" : root.microphoneView ? "No microphone available" : "No output available"
                                    color: root.currentDevice ? root.accent : Theme.grey1
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: root.devicePickerOpen ? "▴" : "▾"
                                    color: devicePicker.available ? Theme.fg : Theme.disabledText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }
                            }
                            HoverHandler { id: pickerHover }
                            TapHandler { enabled: parent.available; onTapped: root.toggleDevicePicker() }
                        }

                        Column {
                            width: parent.width
                            visible: root.devicePickerOpen
                            spacing: 4
                            Repeater {
                                id: deviceRepeater
                                model: Pipewire.nodes
                                delegate: Loader {
                                    id: nodeLoader
                                    required property var modelData
                                    required property int index
                                    active: root.devicePickerOpen && !!modelData && modelData.ready
                                        && !!modelData.audio && !modelData.isStream
                                        && modelData.isSink !== root.microphoneView
                                    visible: active
                                    width: deviceList.width
                                    sourceComponent: Component {
                                        Rectangle {
                                            width: nodeLoader.width
                                            implicitHeight: Theme.controlHeight
                                            readonly property bool selected: nodeLoader.modelData === root.currentDevice
                                            readonly property bool focused: nodeLoader.modelData === root.keyboardNode
                                            color: Theme.controlBackground(selected, focused, deviceHover.hovered)
                                            border.width: 1
                                            border.color: Theme.controlBorder(selected, focused, deviceHover.hovered, root.accent)
                                            Text {
                                                anchors.fill: parent
                                                leftPadding: 8
                                                rightPadding: 8
                                                verticalAlignment: Text.AlignVCenter
                                                text: (parent.selected ? "✓  " : "   ")
                                                    + (nodeLoader.modelData.description || nodeLoader.modelData.nickname || nodeLoader.modelData.name)
                                                color: parent.selected ? root.accent : Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize
                                                elide: Text.ElideRight
                                            }
                                            HoverHandler { id: deviceHover }
                                            TapHandler { onTapped: root.selectDevice(nodeLoader.modelData) }
                                        }
                                    }
                                }
                            }
                        }

                        AudioDeviceControl {
                            id: masterControl
                            width: parent.width
                            modelData: root.currentDevice
                            microphone: root.microphoneView
                            focused: root.keyboardNode === root.currentDevice
                            accent: root.accent
                            onVolumeRequested: value => {
                                root.keyboardNode = root.currentDevice
                                root.setVolume(root.currentDevice, value)
                            }
                            onMuteRequested: root.toggleNodeMute(root.currentDevice)
                        }

                        WidgetHeader {
                            id: appsHeader
                            visible: root.appNodes().length > 0
                            text: "Applications"
                            color: root.accent
                        }

                        Repeater {
                            id: appRepeater
                            model: Pipewire.nodes
                            delegate: Loader {
                                id: appLoader
                                required property var modelData
                                required property int index
                                active: !root.microphoneView && !!modelData && modelData.ready
                                    && modelData.isSink && modelData.isStream && !!modelData.audio
                                visible: active
                                width: deviceList.width
                                sourceComponent: Component {
                                    RowLayout {
                                        width: appLoader.width
                                        height: Theme.controlHeight
                                        spacing: 10
                                        Text {
                                            Layout.preferredWidth: 125
                                            Layout.minimumWidth: 0
                                            text: (appLoader.modelData === root.keyboardNode ? "› " : "  ")
                                                + (appLoader.modelData.properties["application.name"]
                                                    || appLoader.modelData.description || appLoader.modelData.name)
                                            color: appLoader.modelData.audio.muted ? Theme.grey1 : Theme.fg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize
                                            elide: Text.ElideRight
                                        }
                                        AudioSlider {
                                            Layout.fillWidth: true
                                            accent: root.accent
                                            highlighted: appLoader.modelData === root.keyboardNode
                                            value: appLoader.modelData.audio.volume
                                            onMoved: {
                                                root.keyboardNode = appLoader.modelData
                                                root.setVolume(appLoader.modelData, value)
                                            }
                                        }
                                        Text {
                                            Layout.preferredWidth: 38
                                            horizontalAlignment: Text.AlignRight
                                            text: Math.round(appLoader.modelData.audio.volume * 100) + "%"
                                            color: Theme.fg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize
                                        }
                                    }
                                }
                            }
                        }
                    }

                    KeyboardHint {
                        id: volumeHint
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 12
                        text: root.devicePickerOpen
                            ? "Tab: Playback / Microphone\n↑↓: device · Enter: select · Esc: back"
                            : "Tab: Playback / Microphone · ↑↓: focus\n←→: volume · Enter: device · M: mute · Esc: close"
                    }
                }
            }
        }
    }

    // The shield starts below the bar so outside clicks dismiss the panel
    // without blocking the volume controls.
    PanelWindow {
        id: dismissLayer
        visible: devicePopup.visible
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
