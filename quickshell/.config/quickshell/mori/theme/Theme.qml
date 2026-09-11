pragma Singleton
import Quickshell
import QtQuick

Singleton {
    readonly property color fg: "#d3c6aa"
    readonly property color red: "#e67e80"
    readonly property color yellow: "#dbbc7f"
    readonly property color green: "#a7c080"
    readonly property color blue: "#7fbbb3"
    readonly property color purple: "#d699b6"
    readonly property color aqua: "#83c092"
    readonly property color orange: "#e69875"

    readonly property color grey: "#7a8478"
    readonly property color grey1: "#859289"
    readonly property color grey2: "#9da9a0"

    readonly property color bgdim: "#1e2326"
    readonly property color bg: "#272e33"
    readonly property color bg1: "#2e383c"
    readonly property color bg2: "#374145"
    readonly property color bg3: "#414b50"
    readonly property color bg4: "#495156"
    readonly property color bg5: "#4f5b58"

    readonly property color bgred: "#493b40"
    readonly property color bgyellow: "#45443c"
    readonly property color bggreen: "#3c4841"
    readonly property color bgblue: "#384b55"
    readonly property color bgpurple: "#463f48"
    readonly property color bgorange: "#4a4037"
    readonly property color bgvisual: "#4c3743"

    // Check the exact family name with: fc-list | grep -i nerd
    readonly property string fontFamily: "sans-serif"
    readonly property string nerdFontFamily: "FiraCode Nerd Font Propo"
    readonly property int fontSize: 13
}
