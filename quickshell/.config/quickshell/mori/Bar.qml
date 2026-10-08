import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._ToplevelManagement
import "./theme"

PanelWindow {
    id: barWindow
    required property var niriEvents
    required property var notificationServer
    required property bool overviewOpen
    required property var settings
    required property var updateService
    readonly property bool fullscreen: {
        const active = ToplevelManager.activeToplevel
        if (!active || !active.fullscreen || !barWindow.screen)
            return false

        for (let i = 0; i < active.screens.length; ++i) {
            const activeScreen = active.screens[i]
            if (activeScreen === barWindow.screen
                    || (activeScreen && activeScreen.name === barWindow.screen.name))
                return true
        }
        return false
    }
    property var activePopup: null
    property real contentOpacity: (overviewOpen || fullscreen) ? 0 : 1
    readonly property int componentSpacing: 20
    readonly property int bracketSpacing: 6
    readonly property int edgeMargin: 2

    // The panel window already starts 2px in from each screen edge. Clamp a
    // popup inside that window so it shares, rather than doubles, that gutter.
    function popupAnchorX(item, popupWidth, popupVisible) {
        const currentLayoutRevision = settings.revision
        const visibilityRevision = popupVisible
        const position = item.mapToItem(barContent, 0, 0)
        const centered = position.x + item.width / 2 + popupWidth / 2
        return Math.max(popupWidth, Math.min(width, centered))
    }

    function showPopup(owner) {
        if (activePopup && activePopup !== owner)
            activePopup.close()
        activePopup = owner
    }

    function hidePopup(owner) {
        if (activePopup === owner)
            activePopup = null
    }

    function componentForModule(name) {
        switch (name) {
        case "calendar": return calendarComponent
        case "media": return mediaComponent
        case "kdeConnect": return kdeConnectComponent
        case "systemTray": return systemTrayComponent
        case "updates": return updatesComponent
        case "network": return networkComponent
        case "volume": return volumeComponent
        case "brightness": return brightnessComponent
        case "wallpaper": return wallpaperComponent
        case "notifications": return notificationComponent
        case "battery": return batteryComponent
        case "workspaces": return workspacesComponent
        case "powerMenu": return powerMenuComponent
        default: return null
        }
    }

    function loadedModule(name) {
        const repeaters = [leftModuleRepeater, centerModuleRepeater, rightModuleRepeater]
        for (const repeater of repeaters) {
            for (let index = 0; index < repeater.count; ++index) {
                const loader = repeater.itemAt(index)
                if (loader && loader.moduleKey === name && loader.item)
                    return loader.item.module
            }
        }
        return null
    }

    function togglePowerMenu() {
        const module = loadedModule("powerMenu")
        if (module) module.toggle()
    }
    function toggleWallpaperPicker() {
        const module = loadedModule("wallpaper")
        if (module) module.toggle()
    }
    function toggleNotifications() {
        const module = loadedModule("notifications")
        if (module) module.toggle()
    }
    function toggleSettings() { settingsPanel.toggle() }
    function volumeUp() {
        const module = loadedModule("volume")
        if (module) module.adjustVolume(0.03)
    }
    function volumeDown() {
        const module = loadedModule("volume")
        if (module) module.adjustVolume(-0.03)
    }
    function toggleMute() {
        const module = loadedModule("volume")
        if (module) module.toggleMute()
    }

    onOverviewOpenChanged: {
        if (overviewOpen && activePopup)
            activePopup.close()
    }

    onFullscreenChanged: {
        if (fullscreen && activePopup)
            activePopup.close()
    }

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 34
    // Keep the layer mapped during overview, but remove it completely during
    // fullscreen so its input region cannot intercept clicks.
    visible: !fullscreen
    Behavior on contentOpacity {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }
    // The panel stays mapped only to reserve its exclusive zone; the faded
    // content item below is responsible for all visible bar pixels.
    color: "transparent"
    margins { top: barWindow.edgeMargin; left: barWindow.edgeMargin; right: barWindow.edgeMargin }
    // Popup dismiss layers cover the desktop while a popup is open. Keep the
    // bar above them so a click can switch directly to another widget.
    WlrLayershell.layer: WlrLayer.Overlay

    Component {
        id: calendarComponent
        Row {
            height: Theme.barContentHeight
            readonly property alias module: calendar
            Calendar {
                id: calendar
                panelWindow: barWindow
                popupCoordinator: barWindow
                settings: barWindow.settings
                accent: barWindow.settings.moduleColor("calendar")
            }
        }
    }

    Component {
        id: mediaComponent
        Row {
            height: Theme.barContentHeight
            readonly property alias module: media
            Media {
                id: media
                panelWindow: barWindow
                popupCoordinator: barWindow
                accent: barWindow.settings.moduleColor("media")
                compactMode: barWindow.settings.mediaCompact
            }
        }
    }

    Component {
        id: kdeConnectComponent
        Row {
            height: Theme.barContentHeight
            readonly property var module: kdeConnectLoader.item
            readonly property bool available: kdeConnectLoader.status === Loader.Ready
                && kdeConnectLoader.item !== null

            // Keep KDE Connect's QML import out of Bar.qml's required types.
            // If its package is absent, only this loader fails.
            Loader {
                id: kdeConnectLoader
                Component.onCompleted: setSource(Qt.resolvedUrl("KdeConnect.qml"), {
                    "panelWindow": barWindow,
                    "popupCoordinator": barWindow,
                    "accent": barWindow.settings.moduleColor("kdeConnect")
                })
            }
            Row {
                visible: !parent.available
                spacing: barWindow.bracketSpacing
                BarLabel { text: "["; color: Theme.grey1 }
                BarLabel {
                    text: String.fromCodePoint(0xf011c)
                    color: Theme.grey1
                    font.family: Theme.nerdFontFamily
                }
                BarLabel { text: "Unavailable"; color: Theme.grey1 }
                BarLabel { text: "]"; color: Theme.grey1 }
            }
            Binding {
                target: kdeConnectLoader.item
                property: "accent"
                value: barWindow.settings.moduleColor("kdeConnect")
                when: kdeConnectLoader.item !== null
            }
        }
    }

    Component {
        id: systemTrayComponent
        Row {
            height: Theme.barContentHeight
            readonly property alias module: systemTray
            spacing: barWindow.bracketSpacing
            BarBracket { text: "["; color: barWindow.settings.moduleColor("systemTray") }
            SystemTray { id: systemTray; panelWindow: barWindow; anchors.verticalCenter: parent.verticalCenter }
            BarBracket { text: "]"; color: barWindow.settings.moduleColor("systemTray") }
        }
    }

    Component {
        id: updatesComponent
        Row {
            height: Theme.barContentHeight
            readonly property alias module: updates
            spacing: barWindow.bracketSpacing
            BarBracket { text: "["; color: updates.statusColor; action: () => updates.toggle() }
            Updates {
                id: updates
                panelWindow: barWindow
                popupCoordinator: barWindow
                updateService: barWindow.updateService
                accent: barWindow.settings.moduleColor("updates")
            }
            BarBracket { text: "]"; color: updates.statusColor; action: () => updates.toggle() }
        }
    }

    Component {
        id: networkComponent
        Row {
            height: Theme.barContentHeight
            readonly property alias module: network
            spacing: barWindow.bracketSpacing
            BarBracket { text: "["; color: network.accent; action: () => network.toggle() }
            Network {
                id: network
                panelWindow: barWindow
                popupCoordinator: barWindow
                accent: barWindow.settings.moduleColor("network")
                compactMode: barWindow.settings.networkCompact
            }
            BarBracket { text: "]"; color: network.accent; action: () => network.toggle() }
        }
    }

    Component {
        id: volumeComponent
        Row {
            height: Theme.barContentHeight
            readonly property alias module: volume
            spacing: barWindow.bracketSpacing
            BarBracket { text: "["; color: volume.accent; action: () => volume.togglePopup() }
            Volume {
                id: volume
                panelWindow: barWindow
                popupCoordinator: barWindow
                accent: barWindow.settings.moduleColor("volume")
                compactMode: barWindow.settings.volumeCompact
            }
            BarBracket { text: "]"; color: volume.accent; action: () => volume.togglePopup() }
        }
    }

    Component {
        id: brightnessComponent
        Row {
            height: Theme.barContentHeight
            readonly property alias module: brightness
            spacing: barWindow.bracketSpacing
            BarBracket { text: "["; color: brightness.errorMessage.length > 0 ? Theme.red : brightness.available ? brightness.accent : Theme.grey1; action: () => brightness.togglePopup() }
            Brightness {
                id: brightness
                accent: barWindow.settings.moduleColor("brightness")
                compactMode: barWindow.settings.brightnessCompact
                panelWindow: barWindow
                popupCoordinator: barWindow
            }
            BarBracket { text: "]"; color: brightness.errorMessage.length > 0 ? Theme.red : brightness.available ? brightness.accent : Theme.grey1; action: () => brightness.togglePopup() }
        }
    }

    Component {
        id: wallpaperComponent
        Row {
            height: Theme.barContentHeight
            readonly property alias module: wallpaperPicker
            spacing: barWindow.bracketSpacing
            BarBracket { text: "["; color: wallpaperPicker.accent; action: () => wallpaperPicker.toggle() }
            WallpaperPicker {
                id: wallpaperPicker
                panelWindow: barWindow
                popupCoordinator: barWindow
                accent: barWindow.settings.moduleColor("wallpaper")
            }
            BarBracket { text: "]"; color: wallpaperPicker.accent; action: () => wallpaperPicker.toggle() }
        }
    }

    Component {
        id: notificationComponent
        Row {
            height: Theme.barContentHeight
            readonly property alias module: notificationCenter
            spacing: barWindow.bracketSpacing
            BarBracket { text: "["; color: notificationCenter.accent; action: () => notificationCenter.toggle() }
            NotificationCenter {
                id: notificationCenter
                panelWindow: barWindow
                notificationServer: barWindow.notificationServer
                popupCoordinator: barWindow
                accent: barWindow.settings.moduleColor("notifications")
            }
            BarBracket { text: "]"; color: notificationCenter.accent; action: () => notificationCenter.toggle() }
        }
    }

    Component {
        id: batteryComponent
        Row {
            height: Theme.barContentHeight
            readonly property alias module: battery
            spacing: barWindow.bracketSpacing
            BarBracket { text: "["; color: battery.accent; action: () => battery.toggle() }
            Battery {
                id: battery
                panelWindow: barWindow
                popupCoordinator: barWindow
                accent: barWindow.settings.moduleColor("battery")
            }
            BarBracket { text: "]"; color: battery.accent; action: () => battery.toggle() }
        }
    }

    Component {
        id: workspacesComponent
        Row {
            height: Theme.barContentHeight
            readonly property alias module: workspaces
            Workspaces {
                id: workspaces
                niriEvents: barWindow.niriEvents
                panelWindow: barWindow
                accent: barWindow.settings.moduleColor("workspaces")
            }
        }
    }

    Component {
        id: powerMenuComponent
        Row {
            height: Theme.barContentHeight
            readonly property alias module: powerMenu
            spacing: barWindow.bracketSpacing
            BarBracket { text: "["; color: powerMenu.accent; action: () => powerMenu.toggle() }
            PowerMenu {
                id: powerMenu
                panelWindow: barWindow
                popupCoordinator: barWindow
                accent: barWindow.settings.moduleColor("powerMenu")
            }
            BarBracket { text: "]"; color: powerMenu.accent; action: () => powerMenu.toggle() }
        }
    }

    Item {
        id: barContent
        anchors.fill: parent
        opacity: barWindow.contentOpacity
        enabled: !barWindow.overviewOpen && !barWindow.fullscreen
        visible: !barWindow.overviewOpen || opacity > 0

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            border.width: 2
            border.color: Theme.fg
        }

        Row {
            id: leftModules
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: barWindow.componentSpacing

            Repeater {
                id: leftModuleRepeater
                model: barWindow.settings.leftModuleOrder

                delegate: Loader {
                    required property string modelData
                    height: Theme.barContentHeight
                    readonly property string moduleKey: modelData
                    active: barWindow.settings.moduleEnabled(moduleKey)
                    visible: active
                    sourceComponent: barWindow.componentForModule(moduleKey)
                }
            }
        }

        Row {
            id: centerModules
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: barWindow.componentSpacing

            Repeater {
                id: centerModuleRepeater
                model: barWindow.settings.centerModuleOrder

                delegate: Loader {
                    required property string modelData
                    height: Theme.barContentHeight
                    readonly property string moduleKey: modelData
                    active: barWindow.settings.moduleEnabled(moduleKey)
                    visible: active
                    sourceComponent: barWindow.componentForModule(moduleKey)
                }
            }
        }

        Row {
            id: rightModules
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: barWindow.componentSpacing

            Repeater {
                id: rightModuleRepeater
                model: barWindow.settings.rightModuleOrder

                delegate: Loader {
                    required property string modelData
                    height: Theme.barContentHeight
                    readonly property string moduleKey: modelData
                    active: barWindow.settings.moduleEnabled(moduleKey)
                    visible: active
                    sourceComponent: barWindow.componentForModule(moduleKey)
                }
            }

        }

        Loader {
            active: barWindow.settings.notificationsEnabled
            sourceComponent: NotificationPopup {
                accent: barWindow.settings.moduleColor("notifications")
                panelWindow: barWindow
                notificationServer: barWindow.notificationServer
                suppressed: barWindow.overviewOpen || barWindow.fullscreen
                doNotDisturb: {
                    const currentRevision = barWindow.settings.revision
                    const center = barWindow.loadedModule("notifications")
                    return center ? center.doNotDisturb : false
                }
            }
        }
    }

    MoriSettings {
        id: settingsPanel
        panelWindow: barWindow
        popupCoordinator: barWindow
        settings: barWindow.settings
    }
}
