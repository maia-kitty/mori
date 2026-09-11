import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._ToplevelManagement
import "./theme"

PanelWindow {
    id: barWindow
    required property var notificationServer
    required property bool overviewOpen
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

    function showPopup(owner) {
        if (activePopup && activePopup !== owner)
            activePopup.close()
        activePopup = owner
    }

    function hidePopup(owner) {
        if (activePopup === owner)
            activePopup = null
    }

    function togglePowerMenu() { powerMenu.toggle() }
    function toggleWallpaperPicker() { wallpaperPicker.toggle() }
    function toggleNotifications() { notificationCenter.toggle() }
    function volumeUp() { volume.adjustVolume(0.03) }
    function volumeDown() { volume.adjustVolume(-0.03) }
    function toggleMute() { volume.toggleMute() }

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
    margins { top: 2; left: 2; right: 2 }
    // Popup dismiss layers cover the desktop while a popup is open. Keep the
    // bar above them so a click can switch directly to another widget.
    WlrLayershell.layer: WlrLayer.Overlay

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

    PowerMenu {
        id: powerMenu
        anchors.right: powerClose.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: barWindow.bracketSpacing
        panelWindow: barWindow
        popupCoordinator: barWindow
    }

    BarBracket {
        id: powerOpen
        anchors.right: powerMenu.left
        anchors.rightMargin: barWindow.bracketSpacing
        anchors.verticalCenter: parent.verticalCenter
        text: "["
        color: Theme.red
        action: () => powerMenu.toggle()
    }

    BarBracket {
        id: powerClose
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "]"
        color: Theme.red
        action: () => powerMenu.toggle()
    }

    // The clock owns the CalDAV-backed calendar and agenda popup.
    Calendar {
        id: clockText
        panelWindow: barWindow
        popupCoordinator: barWindow
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
    }

    KdeConnect {
        id: kdeConnect
        panelWindow: barWindow
        popupCoordinator: barWindow
        anchors.left: clockText.right
        anchors.leftMargin: barWindow.componentSpacing
        anchors.verticalCenter: parent.verticalCenter
    }

    WallpaperPicker {
        id: wallpaperPicker
        panelWindow: barWindow
        popupCoordinator: barWindow
        anchors.right: wallpaperClose.left
        anchors.rightMargin: barWindow.bracketSpacing
        anchors.verticalCenter: parent.verticalCenter
    }

    Network {
        id: network
        panelWindow: barWindow
        popupCoordinator: barWindow
        anchors.right: networkClose.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: barWindow.bracketSpacing
    }

    Volume {
        id: volume
        panelWindow: barWindow
        popupCoordinator: barWindow
        anchors.right: volumeClose.left
        anchors.rightMargin: barWindow.bracketSpacing
        anchors.verticalCenter: parent.verticalCenter
    }

    SystemTray {
        id: systemTray
        panelWindow: barWindow
        anchors.right: trayClose.left
        anchors.rightMargin: barWindow.bracketSpacing
        anchors.verticalCenter: parent.verticalCenter
    }

    NotificationCenter {
        id: notificationCenter
        panelWindow: barWindow
        notificationServer: barWindow.notificationServer
        popupCoordinator: barWindow
        anchors.right: notificationClose.left
        anchors.rightMargin: barWindow.bracketSpacing
        anchors.verticalCenter: parent.verticalCenter

    }

    BarBracket {
        id: notificationOpen
        anchors.right: notificationCenter.left
        anchors.rightMargin: barWindow.bracketSpacing
        anchors.verticalCenter: parent.verticalCenter
        text: "["
        color: Theme.purple
        action: () => notificationCenter.toggle()
    }

    BarBracket {
        id: notificationClose
        anchors.right: powerOpen.left
        anchors.rightMargin: barWindow.componentSpacing
        anchors.verticalCenter: parent.verticalCenter
        text: "]"
        color: Theme.purple
        action: () => notificationCenter.toggle()
    }

    BarBracket {
        id: wallpaperOpen
        anchors.right: wallpaperPicker.left
        anchors.rightMargin: barWindow.bracketSpacing
        anchors.verticalCenter: parent.verticalCenter
        text: "["
        color: Theme.green
        action: () => wallpaperPicker.toggle()
    }

    BarBracket {
        id: wallpaperClose
        anchors.right: notificationOpen.left
        anchors.rightMargin: barWindow.componentSpacing
        anchors.verticalCenter: parent.verticalCenter
        text: "]"
        color: Theme.green
        action: () => wallpaperPicker.toggle()
    }

    BarBracket {
        id: volumeOpen
        anchors.right: volume.left
        anchors.rightMargin: barWindow.bracketSpacing
        anchors.verticalCenter: parent.verticalCenter
        text: "["
        color: Theme.yellow
        action: () => volume.togglePopup()
    }

    BarBracket {
        id: volumeClose
        anchors.right: wallpaperOpen.left
        anchors.rightMargin: barWindow.componentSpacing
        anchors.verticalCenter: parent.verticalCenter
        text: "]"
        color: Theme.yellow
        action: () => volume.togglePopup()
    }

    BarBracket {
        id: networkOpen
        anchors.right: network.left
        anchors.rightMargin: barWindow.bracketSpacing
        anchors.verticalCenter: parent.verticalCenter
        text: "["
        color: Theme.blue
        action: () => network.toggle()
    }

    BarBracket {
        id: networkClose
        anchors.right: volumeOpen.left
        anchors.rightMargin: barWindow.componentSpacing
        anchors.verticalCenter: parent.verticalCenter
        text: "]"
        color: Theme.blue
        action: () => network.toggle()
    }

    BarBracket {
        id: trayOpen
        anchors.right: systemTray.left
        anchors.rightMargin: barWindow.bracketSpacing
        anchors.verticalCenter: parent.verticalCenter
        text: "["
        color: Theme.fg
    }

    BarBracket {
        id: trayClose
        anchors.right: networkOpen.left
        anchors.rightMargin: barWindow.componentSpacing
        anchors.verticalCenter: parent.verticalCenter
        text: "]"
        color: Theme.fg
    }

    NotificationPopup {
        id: notificationPopup
        panelWindow: barWindow
        notificationServer: barWindow.notificationServer
        popupCoordinator: barWindow
        doNotDisturb: notificationCenter.doNotDisturb
    }
    }
}
