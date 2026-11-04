import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./theme"

// A small text or password prompt in the Settings style (replaces zenity).
// prompt.ask({ title, text, password, accept }, value => ..., () => ...)
// One prompt at a time: a new ask() replaces the open one (cancelling it).
Scope {
    id: root

    property var request: null
    property var acceptedCallback: null
    property var cancelledCallback: null
    property var targetScreen: null
    property bool reveal: false
    readonly property bool open: request !== null && targetScreen !== null

    function ask(options, accepted, cancelled) {
        const replacing = request !== null
        if (replacing) {
            const previous = cancelledCallback
            acceptedCallback = null
            cancelledCallback = null
            if (previous) previous()
        }
        request = options || {}
        acceptedCallback = accepted || null
        cancelledCallback = cancelled || null
        reveal = false
        if (replacing && targetScreen) {
            // Same window stays up; start the new request with an empty field.
            input.text = ""
            Qt.callLater(() => input.forceActiveFocus())
            return
        }
        targetScreen = null
        if (!focusQuery.running)
            focusQuery.exec(["niri", "msg", "--json", "focused-output"])
    }

    function finish(accepted, value) {
        const callback = accepted ? acceptedCallback : cancelledCallback
        request = null
        targetScreen = null
        acceptedCallback = null
        cancelledCallback = null
        if (callback) callback(accepted ? value : undefined)
    }

    function screenNamed(name) {
        for (const screen of Quickshell.screens)
            if (screen.name === name) return screen
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    Process {
        id: focusQuery
        stdout: StdioCollector {
            onStreamFinished: {
                let name = ""
                try {
                    const output = JSON.parse(this.text)
                    name = output.name || output.connector || ""
                } catch (error) {}
                if (root.request) root.targetScreen = root.screenNamed(name)
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 && root.request) root.targetScreen = root.screenNamed("")
        }
    }

    PanelWindow {
        visible: root.open
        screen: root.targetScreen
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "mori-prompt"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: {
            if (!visible) return
            input.text = ""
            Qt.callLater(() => input.forceActiveFocus())
        }

        // Clicking outside the card cancels.
        MouseArea {
            anchors.fill: parent
            onClicked: root.finish(false)
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 420
            height: content.implicitHeight + 32
            color: Theme.bg1
            border.width: 2
            border.color: Theme.fg

            // Swallow clicks so only the area outside the card cancels.
            MouseArea { anchors.fill: parent }

            Column {
                id: content
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
                spacing: 10

                WidgetHeader {
                    text: root.request ? root.request.title || "" : ""
                    color: Theme.fg
                }

                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: root.request ? root.request.text || "" : ""
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Theme.grey2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Rectangle {
                    width: parent.width
                    height: Theme.controlHeight + 4
                    color: Theme.bg
                    border.width: 1
                    border.color: input.activeFocus ? Theme.fg : Theme.bg4

                    TextInput {
                        id: input
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: Theme.fg
                        selectionColor: Theme.bg4
                        selectedTextColor: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        echoMode: root.request && root.request.password && !root.reveal
                            ? TextInput.Password : TextInput.Normal
                        passwordCharacter: "•"
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.finish(true, input.text)
                            } else if (event.key === Qt.Key_Escape) {
                                root.finish(false)
                            } else if (event.key === Qt.Key_Tab && root.request && root.request.password) {
                                root.reveal = !root.reveal
                            } else return
                            event.accepted = true
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    spacing: 8

                    Repeater {
                        model: [false, true]
                        delegate: Rectangle {
                            id: button
                            required property bool modelData
                            width: buttonLabel.implicitWidth + 24
                            height: Theme.controlHeight
                            color: Theme.controlBackground(modelData, false, buttonHover.hovered)
                            border.width: 1
                            border.color: Theme.controlBorder(modelData, false, buttonHover.hovered)
                            Text {
                                id: buttonLabel
                                anchors.centerIn: parent
                                text: button.modelData
                                    ? (root.request && root.request.accept) || "OK" : "Cancel"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            HoverHandler { id: buttonHover }
                            TapHandler {
                                onTapped: {
                                    if (button.modelData) root.finish(true, input.text)
                                    else root.finish(false)
                                }
                            }
                        }
                    }
                }

                KeyboardHint {
                    width: parent.width
                    text: "Enter: " + ((root.request && root.request.accept) || "OK").toLowerCase()
                        + " · Esc: cancel" + (root.request && root.request.password ? " · Tab: show / hide" : "")
                }
            }
        }
    }
}
