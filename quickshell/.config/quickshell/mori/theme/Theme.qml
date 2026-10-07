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

    readonly property color bgdim: "#232a2e"
    readonly property color bg: "#2d353b"
    readonly property color bg1: "#343f44"
    readonly property color bg2: "#3d484d"
    readonly property color bg3: "#475258"
    readonly property color bg4: "#4f585e"
    readonly property color bg5: "#56635f"

    readonly property color bgred: "#5c3f4f"
    readonly property color bgyellow: "#4d4c43"
    readonly property color bggreen: "#425047"
    readonly property color bgblue: "#3a515d"
    readonly property color bgpurple: "#4a444e"
    readonly property color bgorange: "#4a4037"
    readonly property color bgvisual: "#543a48"

    readonly property int controlHeight: 30
    readonly property color disabledText: grey1

    function controlBackground(selected, focused, hovered) {
        return focused || hovered ? bg2 : bg1
    }

    function controlBorder(selected, focused, hovered, accent) {
        return selected || focused || hovered ? (accent === undefined ? fg : accent) : bg4
    }

    // Text uses Old Standard TT; icon-only labels use Symbols Nerd Font.
    readonly property string fontFamily: "Old Standard TT"
    readonly property string nerdFontFamily: "Symbols Nerd Font"
    readonly property int fontSize: 14
    readonly property int barContentHeight: 22
    readonly property int headingFontSize: fontSize + 2
}
