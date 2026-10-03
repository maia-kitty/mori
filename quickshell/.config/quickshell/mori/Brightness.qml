import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./theme"

RowLayout {
    id: root
    spacing: 6

    property color accent: Theme.yellow
    property bool compactMode: false
    required property var panelWindow
    required property var popupCoordinator
    property bool available: false
    property real brightness: 0
    property real requestedBrightness: 0

    function refresh() {
        if (!brightnessQuery.running && !brightnessSet.running
                && !brightnessApply.running && !slider.pressed
                && !popupSlider.pressed)
            brightnessQuery.exec([
                "sh", "-c",
                "command -v brightnessctl >/dev/null 2>&1 && exec brightnessctl -m"
            ])
    }

    function parseBrightness(text) {
        const line = text.trim().split(/\r?\n/)[0] || ""
        const fields = line.split(",")
        if (fields.length < 4) {
            available = false
            return
        }
        const current = Number(fields[2])
        const maximum = Number(fields[3])
        available = isFinite(current) && isFinite(maximum) && maximum > 0
        if (available)
            brightness = Math.max(0, Math.min(1, current / maximum))
    }

    function requestBrightness(value) {
        requestedBrightness = Math.max(0.01, Math.min(1, value))
        brightness = requestedBrightness
        brightnessApply.restart()
    }

    function togglePopup() {
        if (!available)
            return
        if (brightnessPopup.visible) {
            close()
        } else {
            popupCoordinator.showPopup(root)
            brightnessPopup.visible = true
        }
    }

    function close() { brightnessPopup.visible = false }

    function handleKeyPressed(event) {
        if (event.key === Qt.Key_Escape) close()
        else if (event.key === Qt.Key_Left) requestBrightness(brightness - 0.05)
        else if (event.key === Qt.Key_Right) requestBrightness(brightness + 0.05)
        else if (event.key !== Qt.Key_Up && event.key !== Qt.Key_Down) return
        event.accepted = true
    }

    Component.onCompleted: refresh()

    Process {
        id: brightnessQuery
        stdout: StdioCollector {
            onStreamFinished: root.parseBrightness(this.text)
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.available = false
        }
    }

    Process {
        id: brightnessSet
        onExited: exitCode => root.refresh()
    }

    Timer {
        id: brightnessApply
        interval: 70
        onTriggered: {
            if (!root.available)
                return
            if (brightnessSet.running) {
                brightnessApply.restart()
                return
            }
            brightnessSet.exec([
                "brightnessctl", "set",
                Math.round(root.requestedBrightness * 100) + "%"
            ])
        }
    }

    Timer {
        interval: brightnessPopup.visible ? 2000 : 10000
        repeat: true
        running: root.available
        onTriggered: root.refresh()
    }

    Text {
        text: String.fromCodePoint(0xf185)
        color: root.available ? root.accent : Theme.grey1
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize

        TapHandler {
            enabled: root.compactMode && root.available
            onTapped: root.togglePopup()
        }
    }

    Slider {
        id: slider
        from: 0.01
        to: 1
        stepSize: 0.01
        implicitWidth: 110
        implicitHeight: 20
        visible: !root.compactMode
        enabled: root.available
        value: root.brightness
        onMoved: root.requestBrightness(value)

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
                color: root.available ? root.accent : Theme.grey1
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition
                * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 10
            height: 10
            radius: 0
            color: root.available ? root.accent : Theme.grey1
        }
    }

    PopupWindow {
        id: brightnessPopup
        implicitWidth: 230
        implicitHeight: 80
        visible: false
        color: "transparent"
        grabFocus: false
        onVisibleChanged: {
            if (visible) root.refresh()
            else root.popupCoordinator.hidePopup(root)
        }

        anchor.window: root.panelWindow
        anchor.rect {
            x: root.panelWindow.popupAnchorX(
                root, brightnessPopup.implicitWidth, brightnessPopup.visible)
            y: parentWindow.height + 6
            width: 1
            height: 1
        }
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left

        PopupSurface {
            anchors.fill: parent
            shown: brightnessPopup.visible
            color: Theme.bg1
            border.width: 2
            border.color: root.accent

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Row {
                    width: parent.width
                    Text {
                        text: "› Brightness"
                        color: root.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    Text {
                        width: parent.width - x
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(root.brightness * 100) + "%"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }

                Slider {
                    id: popupSlider
                    width: parent.width
                    implicitHeight: 20
                    from: 0.01
                    to: 1
                    stepSize: 0.01
                    enabled: root.available
                    value: root.brightness
                    onMoved: root.requestBrightness(value)

                    background: Rectangle {
                        x: popupSlider.leftPadding
                        y: popupSlider.topPadding
                            + popupSlider.availableHeight / 2 - height / 2
                        width: popupSlider.availableWidth
                        height: 4
                        color: Theme.bg4
                        Rectangle {
                            width: popupSlider.visualPosition * parent.width
                            height: parent.height
                            color: root.accent
                        }
                    }
                    handle: Rectangle {
                        x: popupSlider.leftPadding + popupSlider.visualPosition
                            * (popupSlider.availableWidth - width)
                        y: popupSlider.topPadding
                            + popupSlider.availableHeight / 2 - height / 2
                        width: 10
                        height: 10
                        color: root.accent
                    }
                }
            }
        }
    }

    PanelWindow {
        id: dismissLayer
        visible: brightnessPopup.visible
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
