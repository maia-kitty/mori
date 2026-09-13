import QtQuick

Rectangle {
    id: root

    // Mori popups use square corners. Keep the default here so individual
    // popup modules only specify it when intentionally deviating.
    radius: 0

    // PopupWindow itself becomes visible immediately, so animate its content
    // to give every popup a small, consistent entrance.
    property bool shown: false

    opacity: shown ? 1 : 0

    transform: Translate {
        y: root.shown ? 0 : -6

        Behavior on y {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }
}
