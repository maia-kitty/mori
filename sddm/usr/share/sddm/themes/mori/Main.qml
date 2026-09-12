import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#2d353b"

    readonly property color bg: "#2d353b"
    readonly property color panel: "#343f44"
    readonly property color panelRaised: "#3d484d"
    readonly property color fg: "#d3c6aa"
    readonly property color muted: "#9da9a0"
    readonly property color accent: "#a7c080"
    readonly property color red: "#e67e80"
    readonly property string uiFont: "Geist"
    property int sessionIndex: session.index

    TextConstants { id: textConstants }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            status.text = textConstants.loginSucceeded
            status.color = root.accent
        }

        function onLoginFailed() {
            password.text = ""
            password.focus = true
            status.text = textConstants.loginFailed
            status.color = root.red
        }

        function onInformationMessage(message) {
            status.text = message
            status.color = root.red
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.bg
    }

    // Quiet geometry to give the otherwise flat screen some depth.
    Rectangle {
        width: parent.width * 0.62
        height: 1
        x: parent.width * 0.08
        y: parent.height * 0.22
        color: "#56635f"
        opacity: 0.52
    }

    Rectangle {
        width: 1
        height: parent.height * 0.56
        x: parent.width * 0.18
        y: parent.height * 0.22
        color: "#56635f"
        opacity: 0.30
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: Math.max(34, parent.width * 0.08)
        anchors.top: parent.top
        anchors.topMargin: Math.max(28, parent.height * 0.11)
        text: "MORI"
        color: root.accent
        font.family: root.uiFont
        font.bold: true
        font.letterSpacing: 7
        font.pixelSize: 18
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: Math.max(34, parent.width * 0.08)
        anchors.top: parent.top
        anchors.topMargin: Math.max(58, parent.height * 0.18)
        text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
        color: root.muted
        font.family: root.uiFont
        font.pixelSize: 14
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: Math.max(34, parent.width * 0.08)
        anchors.top: parent.top
        anchors.topMargin: Math.max(80, parent.height * 0.21)
        text: Qt.formatTime(new Date(), "HH:mm")
        color: root.fg
        font.family: root.uiFont
        font.pixelSize: Math.max(42, Math.min(78, parent.height * 0.09))
        font.weight: Font.Light
    }

    Rectangle {
        id: loginCard
        width: Math.min(410, parent.width - 48)
        height: form.implicitHeight + 64
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        color: root.panel
        border.width: 2
        border.color: root.fg

        Column {
            id: form
            width: parent.width - 56
            anchors.centerIn: parent
            spacing: 14

            Text {
                text: "welcome back"
                color: root.fg
                font.family: root.uiFont
                font.pixelSize: 21
                font.bold: true
            }

            Text {
                text: "sign in to start niri"
                color: root.muted
                font.family: root.uiFont
                font.pixelSize: 12
            }

            Item { width: 1; height: 4 }

            Text {
                text: textConstants.userName
                color: root.muted
                font.family: root.uiFont
                font.pixelSize: 11
            }

            TextBox {
                id: name
                width: parent.width
                height: 38
                text: userModel.lastUser
                font.family: root.uiFont
                font.pixelSize: 14
                KeyNavigation.tab: password
                KeyNavigation.backtab: loginButton
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        sddm.login(name.text, password.text, root.sessionIndex)
                        event.accepted = true
                    }
                }
            }

            Text {
                text: textConstants.password
                color: root.muted
                font.family: root.uiFont
                font.pixelSize: 11
            }

            PasswordBox {
                id: password
                width: parent.width
                height: 38
                font.family: root.uiFont
                font.pixelSize: 14
                KeyNavigation.tab: session
                KeyNavigation.backtab: name
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        sddm.login(name.text, password.text, root.sessionIndex)
                        event.accepted = true
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 10
                // SddmComponents renders the ComboBox popup within this
                // item. Keep it above the form fields that follow it.
                z: 100

                ComboBox {
                    id: session
                    width: parent.width - keyboardLabel.width - parent.spacing
                    height: 34
                    model: sessionModel
                    index: sessionModel.lastIndex
                    font.family: root.uiFont
                    font.pixelSize: 12
                    z: 101
                    KeyNavigation.tab: loginButton
                    KeyNavigation.backtab: password
                }

                Rectangle {
                    id: keyboardLabel
                    width: 92
                    height: 34
                    color: root.panelRaised
                    border.width: 1
                    border.color: "#56635f"

                    Text {
                        anchors.centerIn: parent
                        text: "SK · QWERTZ"
                        color: root.accent
                        font.family: root.uiFont
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            Text {
                id: status
                width: parent.width
                height: 16
                text: textConstants.prompt
                color: root.muted
                font.family: root.uiFont
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Rectangle {
                id: loginButton
                width: parent.width
                height: 40
                color: loginMouse.containsMouse ? root.accent : root.panelRaised
                border.width: 1
                border.color: root.accent
                focus: true
                KeyNavigation.tab: powerRow
                KeyNavigation.backtab: session
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        sddm.login(name.text, password.text, root.sessionIndex)
                        event.accepted = true
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "LOG IN  →"
                    color: loginMouse.containsMouse ? root.bg : root.fg
                    font.family: root.uiFont
                    font.pixelSize: 13
                    font.bold: true
                    font.letterSpacing: 1
                }

                MouseArea {
                    id: loginMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: sddm.login(name.text, password.text, root.sessionIndex)
                }
            }

            Row {
                id: powerRow
                width: parent.width
                spacing: 16

                Text {
                    text: "POWER OFF"
                    color: powerMouse.containsMouse ? root.fg : root.muted
                    font.family: root.uiFont
                    font.pixelSize: 11

                    MouseArea {
                        id: powerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: sddm.powerOff()
                    }
                }

                Text {
                    text: "REBOOT"
                    color: rebootMouse.containsMouse ? root.fg : root.muted
                    font.family: root.uiFont
                    font.pixelSize: 11

                    MouseArea {
                        id: rebootMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: sddm.reboot()
                    }
                }
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: Math.max(34, parent.width * 0.05)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(24, parent.height * 0.06)
        text: "ENTER  log in     •     SK / QWERTZ"
        color: root.muted
        font.family: root.uiFont
        font.pixelSize: 11
    }

    Component.onCompleted: {
        if (name.text === "")
            name.focus = true
        else
            password.focus = true
    }
}
