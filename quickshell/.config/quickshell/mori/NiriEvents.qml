import QtQuick
import Quickshell.Io

Item {
    id: root
    property bool overviewOpen: false
    // Niri's workspace list (as `niri msg --json workspaces`), kept current from the events.
    property var workspaces: []

    function readEvent(line) {
        // Most events are about windows; don't parse those.
        if (!line.startsWith('{"Workspace') && !line.startsWith('{"Overview'))
            return
        try {
            const event = JSON.parse(line)
            if (event.OverviewOpenedOrClosed) {
                overviewOpen = event.OverviewOpenedOrClosed.is_open
            } else if (event.WorkspacesChanged) {
                workspaces = event.WorkspacesChanged.workspaces
            } else if (event.WorkspaceActivated) {
                // Same update as niri-ipc's own state: one active workspace per output, one focused overall.
                const id = event.WorkspaceActivated.id
                const focused = event.WorkspaceActivated.focused
                const activated = workspaces.find(workspace => workspace.id === id)
                if (!activated) return
                workspaces = workspaces.map(workspace => Object.assign({}, workspace,
                    workspace.output === activated.output ? { "is_active": workspace.id === id } : {},
                    focused ? { "is_focused": workspace.id === id } : {}))
            } else if (event.WorkspaceUrgencyChanged) {
                const change = event.WorkspaceUrgencyChanged
                workspaces = workspaces.map(workspace => workspace.id === change.id
                    ? Object.assign({}, workspace, { "is_urgent": change.urgent }) : workspace)
            }
        } catch (error) {
            console.warn("Could not read Niri event:", error)
        }
    }

    // One subscription serves the overview and the workspace list. Niri sends
    // the full state on connect.
    Process {
        id: stream
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.readEvent(line)
        }
        onExited: retry.restart()
    }
    Timer {
        id: retry
        interval: 3000
        onTriggered: stream.running = true
    }
}
