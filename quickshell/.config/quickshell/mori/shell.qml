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
    ThemeScheduler { settings: settings }
    Prompt { id: prompt }
    NetworkService { id: networkService; prompt: prompt }
    PowerProfileService { id: powerProfiles }
    LockScreen { id: lockScreen; settings: settings }
    ThemeTransition { id: themeTransition }

    NotificationServer {
        id: notificationServer
        keepOnReload: false
        actionsSupported: true
        persistenceSupported: true
    }
    NotificationService {
        id: notificationService
        server: notificationServer
        enabled: settings.notificationsEnabled
    }

    Bar {
        id: bar
        notificationService: notificationService
        overviewOpen: niriState.overviewOpen
        niriEvents: niriState
        settings: settings
        updateService: updateService
        networkService: networkService
        powerProfiles: powerProfiles
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

        function togglePowerMenu(): void { bar.toggleModule("powerMenu") }
        function toggleWallpaperPicker(): void { bar.toggleModule("wallpaper") }
        function toggleNotifications(): void { bar.toggleModule("notifications") }
        function toggleSettings(): void { bar.toggleSettings() }
        // Opens Settings on a page: modules, theme (Appearance), sound, network, notifications, profile, clock, updates, power, displays, input, about.
        function openSettings(page: string): void { bar.openSettings(page) }
        function volumeUp(): void { osd.adjustVolume(0.03) }
        function volumeDown(): void { osd.adjustVolume(-0.03) }
        function toggleMute(): void { osd.toggleMute() }
        function brightnessUp(): void { osd.showBrightness(bar.adjustBrightness(0.05)) }
        function brightnessDown(): void { osd.showBrightness(bar.adjustBrightness(-0.05)) }
        // mori-theme hands dark/light/toggle here so the switch can crossfade.
        function setTheme(mode: string): void { themeTransition.switchTo(mode) }
        // mori-lock calls this; lockPreview shows the lock screen without locking (Escape closes).
        function lock(): void { lockScreen.lock() }
        function lockPreview(): void { lockScreen.preview() }
    }
}
