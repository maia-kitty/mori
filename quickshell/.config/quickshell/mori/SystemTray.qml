import QtQuick
import Quickshell
import Quickshell.Services.SystemTray as Tray
import Quickshell.Widgets

Item {
    id: root
    implicitWidth: trayRow.implicitWidth
    implicitHeight: trayRow.implicitHeight
    required property var panelWindow

    function showMenu(item, icon) {
        // display() takes coordinates relative to the bar window, so map from
        // the scene (window) rather than this module's row; open below the bar.
        const position = icon.mapToItem(null, 0, 0)
        item.display(panelWindow, Math.round(position.x), panelWindow.height)
    }

    Row {
        id: trayRow
        spacing: 4

        Repeater {
            model: Tray.SystemTray.items

            delegate: Item {
                required property var modelData
                width: 18
                height: 18

                IconImage {
                    anchors.fill: parent
                    source: modelData.icon
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            if (modelData.onlyMenu && modelData.hasMenu)
                                root.showMenu(modelData, parent)
                            else
                                modelData.activate()
                        } else if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate()
                        } else if (modelData.hasMenu) {
                            root.showMenu(modelData, parent)
                        }
                    }
                }
            }
        }
    }
}
