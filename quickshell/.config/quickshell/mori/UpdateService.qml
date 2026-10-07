import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    required property var settings
    readonly property bool active: !settings.loading && settings.updatesEnabled
    property bool checking: false
    property bool updating: false
    property bool launching: false
    property string errorMessage: ""
    property var report: null
    readonly property int count: report ? report.total : 0
    readonly property bool incomplete: report && report.sources.some(source => source.count === null)
    readonly property bool rebootRequired: !!(report && report.reboot && report.reboot.required)
    readonly property string cacheRoot: (Quickshell.env("XDG_CACHE_HOME")
        || Quickshell.env("HOME") + "/.cache") + "/mori-update"
    readonly property string status: checking ? "checking" : updating ? "updating"
        : errorMessage.length > 0 ? "error" : report ? report.status : "unknown"

    function acceptReport(value) {
        if (!value || value.version !== 1 || typeof value.busy !== "boolean")
            throw new Error("Unsupported update status")
        if (value.busy) {
            updating = true
            retry.interval = 30000
            retry.restart()
            return
        }
        if (!Array.isArray(value.sources) || !Number.isInteger(value.total) || value.total < 0
                || !["error", "unknown", "updates", "up-to-date"].includes(value.status)
                || !value.sources.every(source => typeof source.name === "string"
                    && Array.isArray(source.packages)
                    && (source.count === null || Number.isInteger(source.count) && source.count >= 0)))
            throw new Error("Invalid update status")
        report = value
        updating = false
        errorMessage = value.status === "error" ? "Some update sources could not be checked." : ""
        retry.stop()
    }

    function check() {
        if (!active || checking || launching)
            return
        checking = true
        errorMessage = ""
        checker.exec(["mori-update", "--json", "--timeout", "120"])
    }

    function launch() {
        if (checking || updating || launching)
            return
        launching = true
        updating = true
        errorMessage = ""
        launcher.exec(["mori-update", "--launch"])
    }

    onActiveChanged: {
        if (active) initialCheck.restart()
        else { initialCheck.stop(); retry.stop() }
    }
    Component.onCompleted: if (active) initialCheck.restart()

    Timer { id: initialCheck; interval: 2000; onTriggered: root.check() }
    Timer {
        interval: Math.max(1, root.settings.updateIntervalMinutes) * 60000
        running: root.active && root.settings.updateIntervalMinutes > 0
        repeat: true
        onTriggered: root.check()
    }
    Timer { id: retry; interval: 30000; onTriggered: root.check() }

    Process {
        id: checker
        stdout: StdioCollector { id: checkOutput }
        stderr: StdioCollector { id: checkError }
        onExited: exitCode => {
            root.checking = false
            try {
                root.acceptReport(JSON.parse(checkOutput.text))
            } catch (error) {
                root.errorMessage = checkError.text.trim().slice(0, 1000)
                    || "Could not read update status. Check that mori-update is installed."
            }
        }
        onRunningChanged: if (!running) Qt.callLater(() => {
            if (root.checking && !checker.running) {
                root.checking = false
                root.errorMessage = "Could not start mori-update. Stow the bin package and check your PATH."
            }
        })
    }

    Process {
        id: launcher
        stderr: StdioCollector { id: launchError }
        onExited: exitCode => {
            root.launching = false
            if (exitCode !== 0) {
                root.updating = false
                root.errorMessage = launchError.text.trim() || "Could not open the updater in Foot."
            } else {
                // The terminal is detached. Probe its lock if no completion
                // event has arrived yet (also handles a terminal startup failure).
                retry.interval = 15000
                retry.restart()
            }
        }
        onRunningChanged: if (!running) Qt.callLater(() => {
            if (root.launching && !launcher.running) {
                root.launching = false
                root.updating = false
                root.errorMessage = "Could not launch mori-update. Stow the bin package and check your PATH."
            }
        })
    }

    FileView {
        id: savedStatus
        path: root.cacheRoot + "/status.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            if (root.checking) return
            try { root.acceptReport(JSON.parse(text())) }
            catch (error) { /* An older or incomplete cache will be rechecked. */ }
        }
    }

    FileView {
        id: sessionEvent
        path: root.cacheRoot + "/last-session"
        printErrors: false
        watchChanges: true
        onFileChanged: {
            reload()
            root.updating = false
            retry.interval = 1000
            retry.restart()
        }
    }
}
