import QtQuick
import Quickshell
import Quickshell.Services.SystemTray as Tray
import Quickshell.Widgets

Item {
    id: root
    implicitWidth: trayRow.implicitWidth
    implicitHeight: trayRow.implicitHeight
    required property var panelWindow

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
                            if (modelData.onlyMenu && modelData.hasMenu) {
                                const anchorPosition = parent.mapToItem(root.parent, 0, parent.height)
                                modelData.display(root.panelWindow, anchorPosition.x, anchorPosition.y)
                            }
                            else
                                modelData.activate()
                        } else if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate()
                        } else if (modelData.hasMenu) {
                            const anchorPosition = parent.mapToItem(root.parent, 0, parent.height)
                            modelData.display(root.panelWindow, anchorPosition.x, anchorPosition.y)
                        }
                    }
                }
            }
        }
    }
}
