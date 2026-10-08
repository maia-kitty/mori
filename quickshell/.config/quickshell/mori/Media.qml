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
    property int keyboardPlayerIndex: 0
    property bool playerManuallySelected: false
    property color accent: Theme.aqua
    property bool compactMode: false
    readonly property bool hasPlayer: player !== null
    readonly property string trackTitle: hasPlayer ? (player.trackTitle || "Unknown title") : "No media"
    readonly property string trackArtist: hasPlayer ? (player.trackArtist || player.identity || "Unknown artist") : "Start a player to begin"

    implicitWidth: summary.implicitWidth
    implicitHeight: summary.implicitHeight
    // Anchors use actual dimensions, so this bar item needs an explicit size.
    width: implicitWidth
    height: implicitHeight

    function selectPlayer() {
        // Mpris.players is an ObjectModel; use `values`, not ListModel#get().
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
            keyboardPlayerIndex = Math.max(0, Mpris.players.values.indexOf(player))
            popupCoordinator.showPopup(root)
            popup.visible = true
        }
    }

    function close() { popup.visible = false }
    function handleKeyPressed(event) {
        if (event.key === Qt.Key_Escape) {
            close()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            const players = Mpris.players.values
            if (!players.length) return
            keyboardPlayerIndex = Math.max(0, Math.min(players.length - 1,
                keyboardPlayerIndex + (event.key === Qt.Key_Up ? -1 : 1)))
            Qt.callLater(() => {
                const row = playerRows.itemAt(keyboardPlayerIndex)
                if (!row) return
                const y = row.mapToItem(details.contentItem, 0, 0).y
                if (y < details.contentY) details.contentY = y
                else if (y + row.height > details.contentY + details.height)
                    details.contentY = y + row.height - details.height
            })
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            const candidate = Mpris.players.values[keyboardPlayerIndex]
            if (candidate) choosePlayer(candidate)
            event.accepted = true
            return
        }
        if (event.isAutoRepeat || !hasPlayer || !player.canControl)
            return
        if ((event.key === Qt.Key_Space || event.key === Qt.Key_P)
                && player.canTogglePlaying) {
            player.togglePlaying()
            event.accepted = true
        } else if (event.key === Qt.Key_Left && player.canGoPrevious) {
            player.previous()
            event.accepted = true
        } else if (event.key === Qt.Key_Right && player.canGoNext) {
            player.next()
            event.accepted = true
        }
    }

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

        TextMetrics {
            id: titleMetrics
            font: titleText.font
            text: root.trackTitle
        }

        BarLabel {
            text: "["
            color: root.hasPlayer ? root.accent : Theme.grey
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        BarLabel {
            // Keep the bar glyph recognisable at a glance. Playback state is
            // represented by the explicit play/pause control in the popup.
            text: "♫"
            color: root.hasPlayer ? root.accent : Theme.grey
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        BarLabel {
            id: titleText
            visible: !root.compactMode
            width: root.compactMode ? 0 : Math.min(220, titleMetrics.width)
            text: root.trackTitle
            color: root.hasPlayer ? root.accent : Theme.grey
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }
        BarLabel {
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
        implicitHeight: Math.min(details.implicitHeight + mediaHint.implicitHeight + 36, root.panelWindow.screen ? Math.max(80, root.panelWindow.screen.height - root.panelWindow.height - 24) : 440)
        visible: false
        color: "transparent"
        grabFocus: false
        onVisibleChanged: if (!visible) root.popupCoordinator.hidePopup(root)

        anchor.window: root.panelWindow
        anchor.rect {
            x: root.panelWindow.popupAnchorX(root, popup.implicitWidth, popup.visible)
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
            border.color: root.hasPlayer && root.player.isPlaying ? root.accent : Theme.grey

            ScrollableColumn {
                id: details
                anchors.top: parent.top
                anchors.bottom: mediaHint.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                anchors.bottomMargin: 10
                spacing: 8

                Item {
                    id: trackDetails
                    width: parent.width
                    height: titleLabel.implicitHeight + artistLabel.implicitHeight + 8
                        + (albumLabel.visible ? albumLabel.implicitHeight + 8 : 0)

                    WidgetHeader {
                        id: titleLabel
                        width: parent.width
                        text: root.hasPlayer ? root.trackTitle : "No media player"
                        color: root.hasPlayer ? root.accent : Theme.grey
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
                    id: playerRows
                    model: Mpris.players

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: details.width
                        height: Theme.controlHeight
                        color: Theme.controlBackground(modelData === root.player, index === root.keyboardPlayerIndex, playerHover.hovered)
                        border.width: 1
                        border.color: Theme.controlBorder(modelData === root.player, index === root.keyboardPlayerIndex, playerHover.hovered, root.accent)
                        HoverHandler { id: playerHover }

                        Text {
                            anchors.left: parent.left
                            anchors.right: stateLabel.left
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: (index === root.keyboardPlayerIndex ? "› " : "  ") + (modelData.identity || modelData.dbusName)
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
                    spacing: 8
                    Repeater {
                        model: [
                            { icon: 0xf04ae, action: "previous" },
                            { icon: root.hasPlayer && root.player.isPlaying ? 0xf03e4 : 0xf040a, action: "togglePlaying" },
                            { icon: 0xf04ad, action: "next" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool available: root.hasPlayer && root.player.canControl
                                && (modelData.action === "previous" ? root.player.canGoPrevious
                                    : modelData.action === "next" ? root.player.canGoNext : root.player.canTogglePlaying)
                            width: 38
                            height: Theme.controlHeight
                            color: Theme.controlBackground(false, false, available && playbackHover.hovered)
                            border.width: 1
                            border.color: Theme.controlBorder(false, false, available && playbackHover.hovered, root.accent)
                            Text {
                                anchors.centerIn: parent
                                text: String.fromCodePoint(modelData.icon)
                                color: available ? root.accent : Theme.disabledText
                                font.family: Theme.nerdFontFamily
                                font.pixelSize: 20
                            }
                            HoverHandler { id: playbackHover }
                            TapHandler {
                                enabled: available
                                onTapped: root.player[modelData.action]()
                            }
                        }
                    }
                }
            }

            KeyboardHint {
                id: mediaHint
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                text: "↑↓: player · Enter: select · Space: play/pause · ←→: track · Esc: close"
            }
        }
    }

    PanelWindow {
        id: dismissLayer
        screen: root.panelWindow.screen
        visible: popup.visible
        anchors { top: true; bottom: true; left: true; right: true }
        margins.top: root.panelWindow.height
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => keyCapture.forceActiveFocus())
        }

        Item {
            id: keyCapture
            anchors.fill: parent
            focus: dismissLayer.visible
            Keys.onPressed: event => root.handleKeyPressed(event)
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }
    }
}
