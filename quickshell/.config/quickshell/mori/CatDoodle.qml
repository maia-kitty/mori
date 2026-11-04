import QtQuick
import QtQuick.Effects
import "./theme"

// The cat doodle on the About page. Each drawing is split into one mask per
// colour (assets/cat<-season>.<token>.png, made by assets/split-cat.py), and
// every mask is filled with the live Theme colour, so it follows light/dark.
// All drawings share one frame, so the cat is the same size in each.
Item {
    id: root

    property string season: ""
    readonly property var drawings: ({
        "": ["line"],
        "christmas": ["line", "red", "snow"],
        "halloween": ["line"],
        "valentine": ["line", "red", "purple", "green"],
        "birthday": ["line", "yellow"]
    })
    readonly property string name: season in drawings ? season : ""
    readonly property var layers: drawings[name]

    // "line" is the cat itself; "snow" is white in both modes (Christmas fuzz).
    function tokenColor(token) {
        if (token === "line") return Theme.grey1
        if (token === "snow") return Theme.dark ? Theme.fg : Theme.bg
        return Theme[token]
    }

    implicitWidth: sizer.implicitWidth
    implicitHeight: sizer.implicitHeight

    // All layers of a drawing share one size.
    Image {
        id: sizer
        visible: false
        source: Qt.resolvedUrl("assets/cat" + (root.name ? "-" + root.name : "") + "." + root.layers[0] + ".png")
    }

    Repeater {
        model: root.layers
        delegate: Item {
            id: layer
            required property string modelData
            anchors.fill: parent

            Image {
                id: mask
                anchors.fill: parent
                source: Qt.resolvedUrl("assets/cat" + (root.name ? "-" + root.name : "") + "." + layer.modelData + ".png")
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: false
                layer.enabled: true
            }
            Rectangle {
                id: fill
                anchors.fill: parent
                color: root.tokenColor(layer.modelData)
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: parent
                source: fill
                maskEnabled: true
                maskSource: mask
            }
        }
    }
}
