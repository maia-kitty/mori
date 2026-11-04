import QtQuick
import Quickshell.Io

// power-profiles-daemon through powerprofilesctl. One instance lives in shell.qml,
// shared by the Battery popup and Settings → Power profile; `available` is false
// without the daemon. (Not named PowerProfiles: that clashes with UPower's type.)
Item {
    id: root
    visible: false

    property bool available: false
    property bool performanceAvailable: false
    property string current: ""

    function probe() {
        if (!profileProbe.running)
            profileProbe.exec(["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && exec powerprofilesctl get"])
        if (!profileList.running)
            profileList.exec(["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && exec powerprofilesctl list"])
    }

    function select(profile) {
        if (!available || profileSet.running || (profile === "performance" && !performanceAvailable))
            return
        profileSet.exec(["powerprofilesctl", "set", profile])
    }

    Process {
        id: profileProbe
        stdout: StdioCollector {
            onStreamFinished: root.current = this.text.trim()
        }
        onExited: exitCode => {
            root.available = exitCode === 0
            if (exitCode !== 0)
                root.current = ""
        }
    }

    Process {
        id: profileList
        stdout: StdioCollector {
            onStreamFinished: root.performanceAvailable = /^\s*\*?\s*performance:/m.test(this.text)
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.performanceAvailable = false
        }
    }

    Process {
        id: profileSet
        onExited: exitCode => root.probe()
    }
}
