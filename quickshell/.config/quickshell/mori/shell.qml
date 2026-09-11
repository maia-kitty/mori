//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

ShellRoot {
    id: root
    property bool niriOverviewOpen: false

    // awww restores its per-output cache when the daemon starts.
    Process {
        command: ["awww-daemon", "--quiet"]
        running: true
    }

    // Super+Tab invokes niri's toggle-overview action. Its event stream emits
    // the overview state immediately on connection and whenever it changes.
    Process {
        id: niriEvents
        command: ["niri", "msg", "event-stream"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const match = /^Overview toggled:\s*(true|false)\s*$/.exec(line)
                if (match)
                    root.niriOverviewOpen = match[1] === "true"
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                niriEventsRetry.restart()
        }
    }

    Timer {
        id: niriEventsRetry
        interval: 3000
        onTriggered: niriEvents.running = true
    }

    NotificationServer {
        id: notificationServer
        keepOnReload: false
        actionsSupported: false
        persistenceSupported: true
        onNotification: notification => notification.tracked = true
    }

    Bar {
        id: bar
        notificationServer: notificationServer
        overviewOpen: root.niriOverviewOpen
    }

    // Niri invokes these through: qs -c mori ipc call bar <function>.
    IpcHandler {
        target: "bar"

        function togglePowerMenu(): void { bar.togglePowerMenu() }
        function toggleWallpaperPicker(): void { bar.toggleWallpaperPicker() }
        function toggleNotifications(): void { bar.toggleNotifications() }
        function volumeUp(): void { bar.volumeUp() }
        function volumeDown(): void { bar.volumeDown() }
        function toggleMute(): void { bar.toggleMute() }
    }
}
