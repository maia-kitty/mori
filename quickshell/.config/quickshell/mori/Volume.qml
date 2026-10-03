import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "./theme"

RowLayout {
    id: root
    property color accent: Theme.yellow
    property bool compactMode: false
    spacing: 6

    readonly property var sink: Pipewire.defaultAudioSink
    property var keyboardNode: null
    required property var panelWindow
    required property var popupCoordinator

    function togglePopup() {
        if (devicePopup.visible)
            close()
        else {
            popupCoordinator.showPopup(root)
            devicePopup.visible = true
            keyboardNode = sink || selectableNodes()[0] || null
        }
    }

    function close() { devicePopup.visible = false }

    function selectableNodes() {
        const nodes = Pipewire.nodes.values.filter(node => node && node.ready
            && node.isSink && node.audio)
        return nodes.filter(node => !node.isStream)
            .concat(nodes.filter(node => node.isStream))
    }
    function moveKeyboardSelection(offset) {
        const nodes = selectableNodes()
        if (nodes.length === 0) return
        const current = nodes.indexOf(keyboardNode)
        keyboardNode = nodes[Math.max(0, Math.min(nodes.length - 1,
            (current < 0 ? 0 : current) + offset))]
        Qt.callLater(() => {
            for (const repeater of [outputRepeater, appRepeater]) {
                for (let i = 0; i < repeater.count; i++) {
                    const item = repeater.itemAt(i)
                    if (!item || item.modelData !== keyboardNode) continue
                    const y = item.mapToItem(deviceList.contentItem, 0, 0).y
                    if (y < deviceList.contentY) deviceList.contentY = y
                    else if (y + item.height > deviceList.contentY + deviceList.height)
                        deviceList.contentY = y + item.height - deviceList.height
                    return
                }
            }
        })
    }
    function handleKeyPressed(event) {
        if (event.key === Qt.Key_Escape) close()
        else if (event.key === Qt.Key_Up) moveKeyboardSelection(-1)
        else if (event.key === Qt.Key_Down) moveKeyboardSelection(1)
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            if (keyboardNode && keyboardNode.audio)
                setVolume(keyboardNode, keyboardNode.audio.volume
                    + (event.key === Qt.Key_Left ? -0.05 : 0.05))
        } else return
        event.accepted = true
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
        objects: Pipewire.nodes.values
    }

    Text {
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

    Text {
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
        implicitWidth: 320
        implicitHeight: Math.min(deviceList.implicitHeight + 24, 440)
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

        PopupSurface {
            anchors.fill: parent
            shown: devicePopup.visible
            color: Theme.bg1
            border.width: 2
            border.color: root.accent

            ScrollableColumn {
                id: deviceList
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 10

                Text {
                    text: "Output Devices"
                    color: root.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.headingFontSize
                }

                Repeater {
                    id: outputRepeater
                    // Keep the native object model: insert/remove individual
                    // delegates instead of rebuilding a filtered JS array.
                    model: Pipewire.nodes

                    delegate: Column {
                        required property var modelData
                        required property int index
                        visible: !!modelData && modelData.ready && modelData.isSink
                                 && !modelData.isStream && !!modelData.audio
                        width: deviceList.width
                        spacing: 5

                        RowLayout {
                            width: parent.width
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: modelData ? (modelData === root.keyboardNode ? "› " : "  ")
                                    + (modelData.description || modelData.nickname || modelData.name) : ""
                                color: modelData === root.sink || modelData === root.keyboardNode
                                    ? root.accent : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight

                                TapHandler {
                                    onTapped: {
                                        root.keyboardNode = modelData
                                        if (modelData && modelData.ready && modelData.audio)
                                            Pipewire.preferredDefaultAudioSink = modelData
                                    }
                                }
                            }

                            Text {
                                text: modelData && modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : "—"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                        }

                        Slider {
                            id: deviceSlider
                            width: parent.width
                            implicitHeight: 20
                            from: 0
                            to: 1
                            stepSize: 0.01
                            enabled: !!modelData && modelData.ready && !!modelData.audio
                            value: enabled ? modelData.audio.volume : 0
                            onMoved: { root.keyboardNode = modelData; root.setVolume(modelData, value) }

                            background: Rectangle {
                                x: deviceSlider.leftPadding
                                y: deviceSlider.topPadding + deviceSlider.availableHeight / 2 - height / 2
                                width: deviceSlider.availableWidth
                                height: 4
                                radius: 0
                                color: Theme.bg4

                                Rectangle {
                                    width: deviceSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 0
                                    color: root.accent
                                }
                            }

                            handle: Rectangle {
                                x: deviceSlider.leftPadding + deviceSlider.visualPosition
                                   * (deviceSlider.availableWidth - width)
                                y: deviceSlider.topPadding + deviceSlider.availableHeight / 2 - height / 2
                                width: 10
                                height: 10
                                radius: 0
                                color: root.accent
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.bg4
                        }
                    }
                }

                Text {
                    text: "Applications"
                    color: root.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    topPadding: 4
                }

                Repeater {
                    id: appRepeater
                    model: Pipewire.nodes

                    delegate: Column {
                        required property var modelData
                        required property int index
                        // Playback streams are sinks; source streams record audio.
                        visible: !!modelData && modelData.ready && modelData.isSink
                                 && modelData.isStream && !!modelData.audio
                        width: deviceList.width
                        spacing: 5

                        RowLayout {
                            width: parent.width
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: modelData ? (modelData === root.keyboardNode ? "› " : "  ")
                                    + (modelData.properties["application.name"]
                                      || modelData.description
                                      || modelData.name) : ""
                                color: modelData === root.keyboardNode ? root.accent : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                            }

                            Text {
                                text: modelData && modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : "—"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                        }

                        Slider {
                            id: appSlider
                            width: parent.width
                            implicitHeight: 20
                            from: 0
                            to: 1
                            stepSize: 0.01
                            enabled: !!modelData && modelData.ready && !!modelData.audio
                            value: enabled ? modelData.audio.volume : 0
                            onMoved: { root.keyboardNode = modelData; root.setVolume(modelData, value) }

                            background: Rectangle {
                                x: appSlider.leftPadding
                                y: appSlider.topPadding + appSlider.availableHeight / 2 - height / 2
                                width: appSlider.availableWidth
                                height: 4
                                radius: 0
                                color: Theme.bg4

                                Rectangle {
                                    width: appSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 0
                                    color: root.accent
                                }
                            }

                            handle: Rectangle {
                                x: appSlider.leftPadding + appSlider.visualPosition
                                   * (appSlider.availableWidth - width)
                                y: appSlider.topPadding + appSlider.availableHeight / 2 - height / 2
                                width: 10
                                height: 10
                                radius: 0
                                color: root.accent
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.bg4
                        }
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
