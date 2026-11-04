import QtQuick

// Kiri: a screenshot dissolving into fog and soft boxes (shaders/kiri.frag).
// progress 0 shows the screenshot as is, 1 the settled fog.
ShaderEffect {
    id: root

    property url image: ""
    property real progress: 0
    property real seed: 0
    property bool arcs: false

    readonly property alias ready: screenshot.status
    readonly property Image source: screenshot
    readonly property real aspect: height > 0 ? width / height : 1
    readonly property real maxLod: Math.max(1, Math.floor(Math.log2(Math.max(screenshot.sourceSize.width, screenshot.sourceSize.height, 2))))

    fragmentShader: Qt.resolvedUrl("shaders/kiri.frag.qsb")

    Image {
        id: screenshot
        source: root.image
        visible: false
        cache: false
        mipmap: true
        smooth: true
        asynchronous: false
    }
}
