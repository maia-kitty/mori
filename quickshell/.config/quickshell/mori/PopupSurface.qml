import QtQuick

Rectangle {
    id: root

    radius: 0

    // PopupWindow itself becomes visible immediately, so animate its content
    // to give every popup a small, consistent entrance.
    property bool shown: false
    property bool initialized: false

    opacity: 0

    function updateEntrance() {
        entrance.stop()
        opacity = 0
        entranceOffset.y = -6
        if (shown) entrance.start()
    }

    Component.onCompleted: {
        // Loader-created contents may start with shown already true, so the
        // entrance must also run on creation, not only on visibility changes.
        initialized = true
        updateEntrance()
    }
    onShownChanged: if (initialized) updateEntrance()

    transform: Translate {
        id: entranceOffset
        y: -6
    }

    ParallelAnimation {
        id: entrance
        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: 140
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: entranceOffset
            property: "y"
            from: -6
            to: 0
            duration: 140
            easing.type: Easing.OutCubic
        }
    }
}
