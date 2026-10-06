import QtQuick
import Quickshell.Io

Item {
    id: root
    property bool overviewOpen: false
    signal workspacesChanged()

    function readEvent(line) {
        try {
            const event = JSON.parse(line)
            if (event.OverviewOpenedOrClosed)
                overviewOpen = event.OverviewOpenedOrClosed.is_open
            if (event.WorkspacesChanged || event.WorkspaceActivated
                    || event.WorkspaceUrgencyChanged)
                workspacesChanged()
        } catch (error) {
            console.warn("Could not read Niri event:", error)
        }
    }

    // One subscription serves the overview and workspace controls, including
    // when the workspace module is disabled. Niri sends initial state on connect.
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
