import QtQuick
import "./theme"

// A notification's action buttons, while the app still has it open.
Flow {
    id: root
    required property var service
    required property int liveId
    property color accent: Theme.purple
    readonly property var actions: { service.liveRevision; return service.actions(liveId) }

    width: parent ? parent.width : 0
    visible: actions.length > 0
    spacing: 12

    Repeater {
        model: root.actions

        MoriText {
            required property var modelData
            text: modelData ? modelData.text : ""
            color: root.accent

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.modelData.invoke()
            }
        }
    }
}
