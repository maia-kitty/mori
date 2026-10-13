//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.UPower

ShellRoot {
    id: root

    SettingsStore {
        id: settings
    }

    // Desktops have no battery; skip the warning window and its timer.
    Loader {
        active: UPower.displayDevice.isLaptopBattery
        sourceComponent: BatteryWarning {}
    }

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

    Osd {
        id: osd
        settings: settings
        screen: bar.screen
    }

    // Niri invokes these through: qs -c mori ipc call bar <function>.
    IpcHandler {
        target: "bar"

        function togglePowerMenu(): void { bar.togglePowerMenu() }
        function toggleWallpaperPicker(): void { bar.toggleWallpaperPicker() }
        function toggleNotifications(): void { bar.toggleNotifications() }
        function toggleSettings(): void { bar.toggleSettings() }
        function volumeUp(): void { bar.volumeUp(); osd.showVolume() }
        function volumeDown(): void { bar.volumeDown(); osd.showVolume() }
        function toggleMute(): void { bar.toggleMute(); osd.showVolume() }
        function brightnessUp(): void { osd.showBrightness(bar.adjustBrightness(0.05)) }
        function brightnessDown(): void { osd.showBrightness(bar.adjustBrightness(-0.05)) }
    }
}
