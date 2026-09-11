import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "./theme"

RowLayout {
    id: root
    spacing: 6

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var outputs: Pipewire.nodes.values.filter(node =>
        node.isSink && !node.isStream && node.audio)
    readonly property var applications: Pipewire.nodes.values.filter(node =>
        // Playback streams accept an application's audio, so PipeWire exposes
        // them as sink streams. Source streams are microphone inputs.
        node.isStream && node.isSink && node.audio)
    required property var panelWindow
    required property var popupCoordinator

    function togglePopup() {
        if (devicePopup.visible)
            close()
        else {
            popupCoordinator.showPopup(root)
            devicePopup.visible = true
        }
    }

    function close() { devicePopup.visible = false }

    function adjustVolume(delta) {
        if (!root.sink || !root.sink.audio)
            return

        root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + delta))
    }

    function toggleMute() {
        if (root.sink && root.sink.audio)
            root.sink.audio.muted = !root.sink.audio.muted
    }

    PwObjectTracker {
        objects: root.outputs.concat(root.applications)
    }

    Text {
        text: root.sink && root.sink.audio && root.sink.audio.muted
              ? String.fromCodePoint(0xf0583)
              : String.fromCodePoint(0xf057e)
        color: root.sink ? Theme.yellow : Theme.grey
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize

        TapHandler {
            enabled: root.sink && root.sink.audio
            onTapped: root.sink.audio.muted = !root.sink.audio.muted
        }
    }

    Slider {
        id: slider
        from: 0
        to: 1
        stepSize: 0.01
        implicitWidth: 110
        implicitHeight: 20
        enabled: root.sink && root.sink.audio
        value: enabled ? root.sink.audio.volume : 0

        // onMoved is emitted only for user interaction, leaving the binding
        // above intact for volume changes from media keys or other tools.
        onMoved: root.sink.audio.volume = value

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
                color: Theme.yellow
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 10
            height: 10
            radius: 0
            color: Theme.yellow
        }
    }

    Text {
        id: deviceArrow
        text: "v"
        color: Theme.yellow
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
            x: root.x + root.width / 2 + devicePopup.implicitWidth / 2
            y: parentWindow.height + 6
            width: 1
            height: 1
        }
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left

        PopupSurface {
            anchors.fill: parent
            shown: devicePopup.visible
            radius: 0
            color: Theme.bg1
            border.width: 2
            border.color: Theme.yellow

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
                    color: Theme.yellow
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Repeater {
                    model: root.outputs

                    delegate: Column {
                        required property var modelData
                        required property int index
                        width: deviceList.width
                        spacing: 5

                        RowLayout {
                            width: parent.width
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: modelData.description || modelData.nickname || modelData.name
                                color: modelData === root.sink ? Theme.yellow : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight

                                TapHandler {
                                    onTapped: Pipewire.preferredDefaultAudioSink = modelData
                                }
                            }

                            Text {
                                text: Math.round(modelData.audio.volume * 100) + "%"
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
                            value: modelData.audio.volume
                            onMoved: modelData.audio.volume = value

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
                                    color: Theme.yellow
                                }
                            }

                            handle: Rectangle {
                                x: deviceSlider.leftPadding + deviceSlider.visualPosition
                                   * (deviceSlider.availableWidth - width)
                                y: deviceSlider.topPadding + deviceSlider.availableHeight / 2 - height / 2
                                width: 10
                                height: 10
                                radius: 0
                                color: Theme.yellow
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            visible: index < root.outputs.length - 1
                            color: Theme.bg4
                        }
                    }
                }

                Text {
                    text: "Applications"
                    color: Theme.yellow
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    topPadding: 4
                }

                Repeater {
                    model: root.applications

                    delegate: Column {
                        required property var modelData
                        required property int index
                        width: deviceList.width
                        spacing: 5

                        RowLayout {
                            width: parent.width
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: modelData.properties["application.name"]
                                      || modelData.description
                                      || modelData.name
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                            }

                            Text {
                                text: Math.round(modelData.audio.volume * 100) + "%"
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
                            value: modelData.audio.volume
                            onMoved: modelData.audio.volume = value

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
                                    color: Theme.yellow
                                }
                            }

                            handle: Rectangle {
                                x: appSlider.leftPadding + appSlider.visualPosition
                                   * (appSlider.availableWidth - width)
                                y: appSlider.topPadding + appSlider.availableHeight / 2 - height / 2
                                width: 10
                                height: 10
                                radius: 0
                                color: Theme.yellow
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            visible: index < root.applications.length - 1
                            color: Theme.bg4
                        }
                    }
                }
            }
        }
    }

    // The shield starts beneath the bar: it dismisses the panel on an outside
    // click while keeping the volume controls (including the `v`) clickable.
    PanelWindow {
        visible: devicePopup.visible
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
