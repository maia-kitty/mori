pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    // ~/.local/state/mori/mode is written by mori-theme; a missing file means dark.
    // The login screen points MORI_MODE_FILE at its copy in /var/lib/mori-greeter.
    readonly property bool dark: modeFile.text().trim() !== "light"

    FileView {
        id: modeFile
        path: Quickshell.env("MORI_MODE_FILE") || Quickshell.env("HOME") + "/.local/state/mori/mode"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    // "Key: action · Key: action" as styled text: the keys in the text colour,
    // the rest in the label's own (grey) colour. On each line the arrow keys
    // come first, then the other keys.
    function keyHint(text) {
        const escape = part => part.replace(/&/g, "&amp;").replace(/</g, "&lt;")
        const arrow = part => /[←→↑↓]|Arrows/.test(part.key)
        return text.split("\n").map(line => {
            let parts = line.split(" · ").map(part => {
                const colon = part.indexOf(": ")
                return colon < 0 ? { "action": part }
                    : { "key": part.slice(0, colon), "action": part.slice(colon + 2) }
            })
            // A line with plain words in it keeps its order.
            if (parts.every(part => part.key))
                parts = parts.filter(arrow).concat(parts.filter(part => !arrow(part)))
            return parts.map(part => (part.key
                ? '<font color="' + fg + '">' + escape(part.key) + '</font> ' : "")
                + escape(part.action)).join(" · ")
        }).join("<br>")
    }

    readonly property color fg: dark ? "#d3c6aa" : "#5c6a72"
    readonly property color red: dark ? "#e67e80" : "#f85552"
    readonly property color yellow: dark ? "#dbbc7f" : "#dfa000"
    readonly property color green: dark ? "#a7c080" : "#8da101"
    readonly property color blue: dark ? "#7fbbb3" : "#3a94c5"
    readonly property color purple: dark ? "#d699b6" : "#df69ba"
    readonly property color aqua: dark ? "#83c092" : "#35a77c"
    readonly property color orange: dark ? "#e69875" : "#f57d26"

    readonly property color grey: dark ? "#7a8478" : "#a6b0a0"
    readonly property color grey1: dark ? "#859289" : "#939f91"
    readonly property color grey2: dark ? "#9da9a0" : "#829181"

    readonly property color bgdim: dark ? "#232a2e" : "#efebd4"
    readonly property color bg: dark ? "#2d353b" : "#fdf6e3"
    readonly property color bg1: dark ? "#343f44" : "#f4f0d9"
    readonly property color bg2: dark ? "#3d484d" : "#efebd4"
    readonly property color bg3: dark ? "#475258" : "#e6e2cc"
    readonly property color bg4: dark ? "#4f585e" : "#e0dcc7"
    readonly property color bg5: dark ? "#56635f" : "#bdc3af"

    readonly property color bgred: dark ? "#5c3f4f" : "#fbe3da"
    readonly property color bgyellow: dark ? "#4d4c43" : "#faedcd"
    readonly property color bggreen: dark ? "#425047" : "#f0f1d2"
    readonly property color bgblue: dark ? "#3a515d" : "#e9f0e9"
    readonly property color bgpurple: dark ? "#4a444e" : "#fae8e2"
    readonly property color bgorange: dark ? "#4a4037" : "#fce8d6"
    readonly property color bgvisual: dark ? "#543a48" : "#eaedc8"

    readonly property int controlHeight: 30
    readonly property color disabledText: grey1

    function controlBackground(selected, focused, hovered) {
        return focused || hovered ? bg2 : bg1
    }

    function controlBorder(selected, focused, hovered, accent) {
        if (selected) return accent === undefined ? fg : accent
        return focused || hovered ? bg5 : bg4
    }

    readonly property string fontFamily: "Literata"
    readonly property string nerdFontFamily: "Symbols Nerd Font"
    readonly property int fontSize: 14
    readonly property int barContentHeight: 22
    readonly property int headingFontSize: fontSize + 2
}
