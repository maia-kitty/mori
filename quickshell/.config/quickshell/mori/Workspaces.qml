import QtQuick
import Quickshell
import Quickshell.Io
import "./theme"

Item {
    id: root

    required property var panelWindow
    property color accent: Theme.fg
    property var workspaces: []
    property var visibleWorkspaces: []

    implicitWidth: workspaceRow.implicitWidth
    implicitHeight: workspaceRow.implicitHeight
    width: implicitWidth
    height: implicitHeight

    function refresh() {
        if (!workspaceQuery.running)
            workspaceQuery.exec(["niri", "msg", "--json", "workspaces"])
    }

    function parseWorkspaces(text) {
        try {
            const outputName = panelWindow.screen ? panelWindow.screen.name : ""
            const parsed = JSON.parse(text)
            const filtered = parsed.filter(workspace => workspace.output === outputName)
            filtered.sort((left, right) => left.idx - right.idx)
            workspaces = filtered
            visibleWorkspaces = limitedWorkspaces(filtered)
        } catch (error) {
            console.warn("Could not read Niri workspaces:", error)
        }
    }

    function limitedWorkspaces(items) {
        if (items.length <= 5)
            return items
        let activeIndex = items.findIndex(workspace => workspace.is_active)
        if (activeIndex < 0)
            activeIndex = 0
        let slots = 5
        let start = Math.max(0, Math.min(activeIndex - 2, items.length - slots))
        for (let pass = 0; pass < 3; ++pass) {
            const hiddenLeft = start > 0
            const hiddenRight = start + slots < items.length
            slots = 5 - (hiddenLeft ? 1 : 0) - (hiddenRight ? 1 : 0)
            start = Math.max(0, Math.min(
                activeIndex - Math.floor((slots - 1) / 2), items.length - slots))
        }
        const end = Math.min(items.length, start + slots)
        const result = []
        if (start > 0)
            result.push({ "overflow": true, "side": "left" })
        result.push(...items.slice(start, end))
        if (end < items.length)
            result.push({ "overflow": true, "side": "right" })
        return result.slice(0, 5)
    }

    function focusWorkspace(workspace) {
        if (!workspace || workspace.overflow)
            return
        focusWorkspaceProcess.exec([
            "niri", "msg", "action", "focus-workspace", String(workspace.idx)])
    }

    Component.onCompleted: refresh()

    Connections {
        target: root.panelWindow
        ignoreUnknownSignals: true
        function onScreenChanged() { root.refresh() }
    }

    Process {
        id: workspaceQuery
        stdout: StdioCollector {
            onStreamFinished: root.parseWorkspaces(this.text)
        }
    }

    Process {
        id: focusWorkspaceProcess
        onExited: exitCode => root.refresh()
    }

    Process {
        id: niriEvents
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: workspaceRefresh.restart()
        }
        onExited: eventStreamRetry.restart()
    }

    Timer {
        id: workspaceRefresh
        interval: 40
        onTriggered: root.refresh()
    }

    Timer {
        id: eventStreamRetry
        interval: 3000
        onTriggered: niriEvents.running = true
    }

    Row {
        id: workspaceRow
        spacing: 4

        Repeater {
            model: root.visibleWorkspaces
            delegate: Rectangle {
                id: workspaceBox
                required property var modelData
                width: Math.max(22, workspaceLabel.implicitWidth + 10)
                height: 22
                color: !modelData.overflow && modelData.is_active
                    ? root.accent : workspaceHover.hovered && !modelData.overflow
                        ? Theme.bg2 : "transparent"
                border.width: 1
                border.color: !modelData.overflow && modelData.is_urgent
                    ? Theme.red : modelData.overflow ? Theme.grey1 : root.accent

                Text {
                    id: workspaceLabel
                    anchors.centerIn: parent
                    text: workspaceBox.modelData.overflow ? ""
                        : workspaceBox.modelData.name || workspaceBox.modelData.idx
                    color: !workspaceBox.modelData.overflow
                        && workspaceBox.modelData.is_active ? Theme.bg : root.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: !workspaceBox.modelData.overflow
                        && workspaceBox.modelData.is_active
                        ? Font.DemiBold : Font.Normal
                }

                HoverHandler { id: workspaceHover }
                TapHandler {
                    enabled: !workspaceBox.modelData.overflow
                    onTapped: root.focusWorkspace(workspaceBox.modelData)
                }
            }
        }
    }
}
