//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    SettingsStore {
        id: settings
    }

    BatteryWarning {}

    NiriEvents { id: niriState }
    UpdateService { id: updateService; settings: settings }

    NotificationServer {
        id: notificationServer
        keepOnReload: false
        actionsSupported: true
        persistenceSupported: true
    }

    Bar {
        id: bar
        notificationServer: notificationServer
        overviewOpen: niriState.overviewOpen
        niriEvents: niriState
        settings: settings
        updateService: updateService
        // Keep the bar on the primary output. Without an explicit screen,
        // Quickshell may remap the panel to the currently active monitor.
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    // Niri invokes these through: qs -c mori ipc call bar <function>.
    IpcHandler {
        target: "bar"

        function togglePowerMenu(): void { bar.togglePowerMenu() }
        function toggleWallpaperPicker(): void { bar.toggleWallpaperPicker() }
        function toggleNotifications(): void { bar.toggleNotifications() }
        function toggleSettings(): void { bar.toggleSettings() }
        function volumeUp(): void { bar.volumeUp() }
        function volumeDown(): void { bar.volumeDown() }
        function toggleMute(): void { bar.toggleMute() }
    }
}
