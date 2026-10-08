import QtQuick
import QtQuick.Layouts
import "./theme"

Item {
    id: root
    required property var modelData
    property bool microphone: false
    property bool focused: false
    property color accent: Theme.yellow
    readonly property bool available: !!modelData && modelData.ready && !!modelData.audio
    readonly property bool muted: available && modelData.audio.muted
    signal volumeRequested(real value)
    signal muteRequested()
    implicitHeight: Theme.controlHeight

    RowLayout {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            implicitWidth: Theme.controlHeight
            implicitHeight: Theme.controlHeight
            color: Theme.controlBackground(false, false, root.available && muteHover.hovered)
            Text {
                anchors.centerIn: parent
                text: String.fromCodePoint(root.microphone
                    ? (root.muted ? 0xf036d : 0xf036c)
                    : (root.muted ? 0xf0583 : 0xf057e))
                color: !root.available ? Theme.disabledText : root.muted ? Theme.red : root.accent
                font.family: Theme.nerdFontFamily
                font.pixelSize: Theme.fontSize + 2
            }
            HoverHandler { id: muteHover }
            TapHandler {
                enabled: root.available
                onTapped: root.muteRequested()
            }
            Accessible.role: Accessible.Button
            Accessible.name: (root.muted ? "Unmute " : "Mute ") + (root.microphone ? "microphone" : "output")
        }

        AudioSlider {
            Layout.fillWidth: true
            accent: root.accent
            highlighted: root.focused
            enabled: root.available
            value: enabled ? root.modelData.audio.volume : 0
            onMoved: root.volumeRequested(value)
        }

        Text {
            Layout.preferredWidth: 38
            horizontalAlignment: Text.AlignRight
            text: root.available ? Math.round(root.modelData.audio.volume * 100) + "%" : "—"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
