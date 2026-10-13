import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "./theme"

// Short-lived level indicator for volume and brightness keybinds. Values are
// live bindings, so the bar shows the level PipeWire or brightnessctl settles
// on rather than the one that was requested.
PanelWindow {
    id: root

    required property var settings
    property var brightnessModule: null
    property string kind: ""
    property bool shown: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: kind === "volume"
        && !!(sink && sink.audio && sink.audio.muted)
    readonly property real level: {
        if (kind === "volume")
            return sink && sink.audio ? sink.audio.volume : 0
        if (kind === "brightness")
            return brightnessModule ? brightnessModule.brightness : 0
        return 0
    }
    readonly property color accent: muted ? Theme.grey1
        : settings.moduleColor(kind === "brightness" ? "brightness" : "volume")

    function showVolume() { show("volume") }

    function showBrightness(module) {
        if (!module || !module.available)
            return
        brightnessModule = module
        show("brightness")
    }

    function show(nextKind) {
        kind = nextKind
        shown = true
        hideTimer.restart()
    }

    visible: shown || content.opacity > 0
    implicitWidth: 280
    implicitHeight: 48
    anchors.bottom: true
    margins.bottom: 40
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // Input passes through, so the indicator never steals a click or focus.
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "mori-osd"

    PwObjectTracker {
        objects: root.visible && root.sink ? [root.sink] : []
    }

    Timer {
        id: hideTimer
        interval: 1400
        onTriggered: root.shown = false
    }

    Rectangle {
        id: content
        anchors.fill: parent
        color: Theme.bg1
        border.width: 2
        border.color: root.accent
        opacity: root.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        transform: Translate {
            y: root.shown ? 0 : 6
            Behavior on y {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            Text {
                id: icon
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                horizontalAlignment: Text.AlignHCenter
                text: root.kind === "brightness" ? String.fromCodePoint(0xf185)
                    : root.muted ? String.fromCodePoint(0xf0581)
                    : String.fromCodePoint(0xf057e)
                color: root.accent
                font.family: Theme.nerdFontFamily
                font.pixelSize: Theme.headingFontSize
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - icon.width - percent.width - parent.spacing * 2
                height: 4
                color: Theme.bg4

                Rectangle {
                    width: Math.max(0, Math.min(1, root.level)) * parent.width
                    height: parent.height
                    color: root.accent
                    Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                }
            }

            Text {
                id: percent
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: root.muted ? "Muted" : Math.round(root.level * 100) + "%"
                color: root.muted ? Theme.grey1 : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }
}
