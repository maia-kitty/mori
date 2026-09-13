import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import "./theme"

Item {
    id: root

    required property var panelWindow
    required property var popupCoordinator
    property var player: null
    property bool playerManuallySelected: false
    readonly property color accent: Theme.aqua
    readonly property bool hasPlayer: player !== null
    readonly property string trackTitle: hasPlayer ? (player.trackTitle || "Unknown title") : "No media"
    readonly property string trackArtist: hasPlayer ? (player.trackArtist || player.identity || "Unknown artist") : "Start a player to begin"

    implicitWidth: summary.implicitWidth
    implicitHeight: summary.implicitHeight
    // Anchors position using width/height, not the implicit dimensions.
    // Giving this item a real size keeps KDE Connect after it instead of
    // painting over the media summary.
    width: implicitWidth
    height: implicitHeight

    function selectPlayer() {
        // Quickshell exposes ObjectModel entries through its `values` list.
        // Unlike a Qt ListModel, ObjectModel does not provide indexed player
        // access via get(), so using it left every candidate undefined.
        const players = Mpris.players.values
        if (playerManuallySelected && players.indexOf(player) >= 0)
            return

        playerManuallySelected = false
        let fallback = null
        for (let i = 0; i < players.length; ++i) {
            const candidate = players[i]
            if (!candidate)
                continue
            if (!fallback)
                fallback = candidate
            if (candidate.isPlaying) {
                player = candidate
                return
            }
        }
        player = fallback
    }

    function choosePlayer(candidate) {
        if (!candidate)
            return
        player = candidate
        playerManuallySelected = true
    }

    function toggle() {
        if (popup.visible) {
            close()
        } else {
            selectPlayer()
            popupCoordinator.showPopup(root)
            popup.visible = true
        }
    }

    function close() { popup.visible = false }

    // ObjectModel does not expose a convenient preferred-player property.
    // Refreshing lightly also makes a newly-playing player take precedence.
    Timer {
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.selectPlayer()
    }

    Row {
        id: summary
        spacing: 6

        Text {
            text: "["
            color: root.hasPlayer ? root.accent : Theme.grey
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        Text {
            // Keep the bar glyph recognisable at a glance. Playback state is
            // represented by the explicit play/pause control in the popup.
            text: "♫"
            color: root.hasPlayer ? root.accent : Theme.grey
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        Text {
            width: Math.min(220, implicitWidth)
            text: root.trackTitle
            color: root.hasPlayer ? root.accent : Theme.grey
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }
        Text {
            text: "]"
            color: root.hasPlayer ? root.accent : Theme.grey
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    TapHandler { onTapped: root.toggle() }

    PopupWindow {
        id: popup
        implicitWidth: 340
        implicitHeight: details.implicitHeight + 24
        visible: false
        color: "transparent"
        grabFocus: false
        onVisibleChanged: if (!visible) root.popupCoordinator.hidePopup(root)

        anchor.window: root.panelWindow
        anchor.rect {
            x: root.panelWindow.popupAnchorX(root, popup.implicitWidth)
            y: parentWindow.height + 6
            width: 1
            height: 1
        }
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left

        PopupSurface {
            anchors.fill: parent
            shown: popup.visible
            color: Theme.bg1
            border.width: 2
            border.color: root.accent

            Column {
                id: details
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 8

                Item {
                    id: trackDetails
                    width: parent.width
                    height: titleLabel.implicitHeight + artistLabel.implicitHeight + 8
                        + (albumLabel.visible ? albumLabel.implicitHeight + 8 : 0)

                    Text {
                        id: titleLabel
                        width: parent.width
                        text: root.hasPlayer ? root.trackTitle : "No media player"
                        color: root.hasPlayer ? root.accent : Theme.grey
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.headingFontSize
                        elide: Text.ElideRight
                    }
                    Text {
                        id: artistLabel
                        anchors.top: titleLabel.bottom
                        anchors.topMargin: 8
                        width: parent.width
                        text: root.trackArtist
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }
                    Text {
                        id: albumLabel
                        anchors.top: artistLabel.bottom
                        anchors.topMargin: 8
                        visible: root.hasPlayer && root.player.trackAlbum.length > 0
                        width: parent.width
                        text: root.player ? root.player.trackAlbum : ""
                        color: Theme.grey1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.hasPlayer && root.player.canRaise
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            root.player.raise()
                            root.close()
                        }
                    }
                }
                Text {
                    visible: Mpris.players.values.length > 1
                    text: "Players"
                    color: root.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    topPadding: 4
                }
                Repeater {
                    model: Mpris.players

                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: details.width
                        height: 30

                        Text {
                            anchors.left: parent.left
                            anchors.right: stateLabel.left
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.identity || modelData.dbusName
                            color: modelData === root.player ? root.accent : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                        }
                        Text {
                            id: stateLabel
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.isPlaying ? "playing" : "idle"
                            color: modelData.isPlaying ? root.accent : Theme.grey
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            visible: index < Mpris.players.values.length - 1
                            color: Theme.bg4
                        }
                        TapHandler { onTapped: root.choosePlayer(modelData) }
                    }
                }
                Row {
                    width: parent.width
                    spacing: 20
                    enabled: root.hasPlayer && root.player.canControl

                    Text {
                        text: String.fromCodePoint(0xf04ae)
                        color: parent.enabled && root.player.canGoPrevious ? root.accent : Theme.grey
                        font.family: Theme.nerdFontFamily
                        font.pixelSize: 20
                        TapHandler {
                            enabled: root.hasPlayer && root.player.canGoPrevious
                            onTapped: root.player.previous()
                        }
                    }
                    Text {
                        text: root.hasPlayer && root.player.isPlaying
                            ? String.fromCodePoint(0xf03e4) : String.fromCodePoint(0xf040a)
                        color: parent.enabled && root.player.canTogglePlaying ? root.accent : Theme.grey
                        font.family: Theme.nerdFontFamily
                        font.pixelSize: 20
                        TapHandler {
                            enabled: root.hasPlayer && root.player.canTogglePlaying
                            onTapped: root.player.togglePlaying()
                        }
                    }
                    Text {
                        text: String.fromCodePoint(0xf04ad)
                        color: parent.enabled && root.player.canGoNext ? root.accent : Theme.grey
                        font.family: Theme.nerdFontFamily
                        font.pixelSize: 20
                        TapHandler {
                            enabled: root.hasPlayer && root.player.canGoNext
                            onTapped: root.player.next()
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        visible: popup.visible
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
