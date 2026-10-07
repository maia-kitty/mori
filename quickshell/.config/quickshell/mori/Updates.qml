import QtQuick
import Quickshell
import Quickshell.Wayland
import "./theme"

Row {
    id: root
    spacing: 5
    required property var panelWindow
    required property var popupCoordinator
    required property var updateService
    property color accent: Theme.green
    readonly property color statusColor: accent
    readonly property string summary: updateService.checking ? "Checking for updates…"
        : updateService.updating ? "Updater open in terminal"
        : updateService.status === "error" ? "Some checks failed"
        : !updateService.report ? "Updates have not been checked"
        : updateService.status === "unknown" ? "Update status unavailable"
        : updateService.count > 0 ? updateService.count + " update(s) available"
        : updateService.incomplete ? "Some update counts are unavailable" : "Up to date"

    function toggle() {
        if (popup.visible) close()
        else {
            popupCoordinator.showPopup(root)
            popup.visible = true
        }
    }
    function close() { popup.visible = false }
    function launch() {
        if (updateService.checking || updateService.updating || updateService.launching) return
        updateService.launch()
        close()
    }
    function handleKeyPressed(event) {
        if (event.key === Qt.Key_Escape) close()
        else if (event.key === Qt.Key_C && !event.isAutoRepeat) updateService.check()
        else if (event.key === Qt.Key_U && !event.isAutoRepeat) launch()
        else if ((event.key === Qt.Key_Up || event.key === Qt.Key_Down) && popupContent.item) {
            const list = popupContent.item.scrollList
            list.contentY = Math.max(0, Math.min(Math.max(0, list.contentHeight - list.height),
                list.contentY + (event.key === Qt.Key_Up ? -40 : 40)))
        } else return
        event.accepted = true
    }

    BarLabel {
        anchors.verticalCenter: parent.verticalCenter
        text: String.fromCodePoint(root.updateService.checking ? 0xf021 : 0xf019)
        color: root.statusColor
        font.family: Theme.nerdFontFamily
    }
    BarLabel {
        anchors.verticalCenter: parent.verticalCenter
        text: root.updateService.checking ? "…" : root.updateService.updating ? "↗"
            : root.updateService.status === "error" ? String(root.updateService.count)
            : !root.updateService.report ? "?"
            : root.updateService.status === "unknown" ? "?"
            : root.updateService.count + (root.updateService.incomplete ? "?" : "")
        color: root.statusColor
    }
    BarLabel {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.updateService.status === "error"
        text: "!"
        color: Theme.red
    }
    TapHandler { onTapped: root.toggle() }

    PopupWindow {
        id: popup
        implicitWidth: 380
        implicitHeight: popupContent.item ? popupContent.item.implicitHeight : 180
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

        Loader {
            id: popupContent
            anchors.fill: parent
            active: popup.visible
            sourceComponent: PopupSurface {
                readonly property alias scrollList: sourceList
                implicitHeight: content.implicitHeight + 24
                shown: popup.visible
                color: Theme.bg1
                border.width: 2
                border.color: root.statusColor

                Column {
                    id: content
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: "Mori updates"
                        color: root.statusColor
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.headingFontSize
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        text: root.summary
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    Text {
                        width: parent.width
                        text: root.updateService.report && root.updateService.report.checked_at
                            ? "Last checked · " + Qt.formatDateTime(new Date(root.updateService.report.checked_at), "MMM d, HH:mm")
                            : "Check now to see available updates"
                        color: Theme.grey1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.bg4 }

                    ScrollableColumn {
                        id: sourceList
                        width: parent.width
                        height: Math.min(280, implicitHeight)
                        spacing: 10

                        Text {
                            width: parent.width
                            visible: root.updateService.errorMessage.length > 0
                            text: root.updateService.errorMessage
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: Theme.red
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        Column {
                            width: parent.width
                            visible: root.updateService.rebootRequired
                            spacing: 3
                            Text {
                                text: "Reboot recommended"
                                color: Theme.yellow
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            Repeater {
                                model: root.updateService.rebootRequired ? root.updateService.report.reboot.reasons : []
                                Text {
                                    required property string modelData
                                    width: parent.width
                                    text: modelData
                                    textFormat: Text.PlainText
                                    wrapMode: Text.Wrap
                                    color: Theme.grey2
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }
                            }
                        }
                        Repeater {
                            model: root.updateService.report ? root.updateService.report.sources : []
                            delegate: Column {
                                id: sourceRow
                                required property var modelData
                                width: sourceList.width
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: sourceRow.modelData.name + " · "
                                        + (sourceRow.modelData.status === "error" ? "Check failed"
                                            : sourceRow.modelData.count === null ? "Count unavailable"
                                            : sourceRow.modelData.count + " available")
                                    wrapMode: Text.Wrap
                                    textFormat: Text.PlainText
                                    color: sourceRow.modelData.status === "error" ? Theme.red : root.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                        Repeater {
                            model: root.updateService.report ? root.updateService.report.notes || [] : []
                            Text {
                                required property string modelData
                                width: sourceList.width
                                text: modelData
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                color: Theme.grey1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.bg4 }
                    Row {
                        spacing: 8
                        Repeater {
                            model: [{label: "Check now · C", update: false}, {label: "Update · U", update: true}]
                            Rectangle {
                                id: actionButton
                                required property var modelData
                                readonly property bool available: !root.updateService.checking && !root.updateService.launching
                                    && (!modelData.update || !root.updateService.updating)
                                width: 168
                                height: Theme.controlHeight
                                color: Theme.controlBackground(false, false, actionHover.hovered && available)
                                border.width: 1
                                border.color: available ? root.accent : Theme.bg4
                                Text {
                                    anchors.centerIn: parent
                                    text: actionButton.modelData.label
                                    color: actionButton.available ? Theme.fg : Theme.grey1
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }
                                HoverHandler { id: actionHover }
                                TapHandler {
                                    enabled: actionButton.available
                                    onTapped: actionButton.modelData.update ? root.launch() : root.updateService.check()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: dismissLayer
        visible: popup.visible
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
