import QtQuick
import Quickshell
import "./theme"

PanelWindow {
    id: barWindow
    required property var notificationServer
    property var activePopup: null
    property int componentSpacing: 20
    property int bracketSpacing: 6

    function showPopup(owner) {
        if (activePopup && activePopup !== owner)
            activePopup.close()
        activePopup = owner
    }

    function hidePopup(owner) {
        if (activePopup === owner)
            activePopup = null
    }

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 34
    color: Theme.bg
    margins { top: 2; left: 2; right: 2 }

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

    ClockText {
        id: clockText
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
    }

    ActiveApp {
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
