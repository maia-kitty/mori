import QtQuick
import Quickshell.Io

// Received notifications: the history, the live objects behind it (kept
// tracked so their actions still work) and focusing the sending app. One
// instance lives in shell.qml; the toasts and the notification centre are
// views of it.
Item {
    id: root
    visible: false

    required property var server
    // The notifications module; while it's off nothing is kept.
    property bool enabled: true
    readonly property int historyLimit: 500
    readonly property alias history: history
    readonly property int count: history.count
    // Server id → tracked Notification. Plain JS, so bump liveRevision when it changes.
    property var live: ({})
    property int liveRevision: 0
    // Server id → history entries showing it; at 0 the notification is dismissed.
    property var refs: ({})
    property var pending: []
    property var closedPending: []
    property int nextEntryId: 0

    // A new notification, or a replacement of one (same liveId) the app updated in place.
    signal arrived(var entry)
    signal liveClosed(int liveId)

    onEnabledChanged: if (!enabled) clear()

    function copy(notification) {
        return {
            "notificationId": nextEntryId++,
            "liveId": notification.id,
            "receivedAt": Date.now(),
            "appName": String(notification.appName || "Notification"),
            "desktopEntry": String(notification.desktopEntry || ""),
            "summary": String(notification.summary || ""),
            "body": String(notification.body || "")
        }
    }

    function track(notification) {
        if (!enabled) return
        // Tracked, the app can update it in place and its actions stay invokable.
        notification.tracked = true
        const liveId = notification.id
        live[liveId] = notification
        notification.closed.connect(() => forget(liveId))
        notification.summaryChanged.connect(() => queue(notification))
        notification.bodyChanged.connect(() => queue(notification))
        queue(notification)
    }

    function queue(notification) {
        // A replacement changes summary and body one after another: keep one copy.
        const last = pending[pending.length - 1]
        if (last && last.liveId === notification.id)
            pending.pop()
        pending.push(copy(notification))
        flushTimer.restart()
    }

    function forget(liveId) {
        delete live[liveId]
        closedPending.push(liveId)
        flushTimer.restart()
    }

    function flush() {
        const arrivals = pending
        const closed = closedPending
        pending = []
        closedPending = []
        for (const entry of arrivals) {
            history.insert(0, entry)
            refs[entry.liveId] = (refs[entry.liveId] || 0) + 1
            arrived(entry)
        }
        for (let i = history.count - 1; i >= historyLimit; i--)
            unref(history.get(i).liveId)
        if (history.count > historyLimit)
            history.remove(historyLimit, history.count - historyLimit)
        if (arrivals.length > 0 || closed.length > 0) liveRevision++
        for (const liveId of closed) liveClosed(liveId)
    }

    function unref(liveId) {
        refs[liveId] = (refs[liveId] || 1) - 1
        if (refs[liveId] > 0) return
        delete refs[liveId]
        if (live[liveId]) live[liveId].dismiss()
    }

    function remove(notificationId) {
        for (let i = 0; i < history.count; ++i) {
            if (history.get(i).notificationId === notificationId) {
                const liveId = history.get(i).liveId
                history.remove(i)
                unref(liveId)
                return
            }
        }
    }

    function clear() {
        const liveIds = []
        for (let i = 0; i < history.count; ++i) liveIds.push(history.get(i).liveId)
        history.clear()
        for (const liveId of liveIds) unref(liveId)
    }

    // Actions other than "default", which is the click on the notification itself.
    function actions(liveId) {
        const notification = live[liveId]
        return notification ? Array.from(notification.actions).filter(a => a.identifier !== "default") : []
    }

    function activate(liveId, desktopEntry) {
        const notification = live[liveId]
        const action = notification ? Array.from(notification.actions).find(a => a.identifier === "default") : null
        if (action) action.invoke()
        // Niri won't let the app raise itself without an activation token, so focus it here too.
        focusApplication(desktopEntry)
    }

    function desktopId(value) {
        return String(value || "").toLowerCase().replace(/\.desktop$/, "")
    }

    function launchApplication(entry) {
        const desktopEntry = desktopId(entry)
        if (desktopEntry.length)
            applicationLaunch.exec(["gtk-launch", desktopEntry])
    }

    function focusApplication(entry) {
        const desktopEntry = desktopId(entry)
        if (!desktopEntry.length)
            return

        // A second click while the window list is in flight still gets a
        // useful result, without racing a shared Process instance.
        if (windowQuery.running) {
            launchApplication(desktopEntry)
            return
        }

        windowQuery.desktopEntry = desktopEntry
        windowQuery.exec(["niri", "msg", "--json", "windows"])
    }

    ListModel { id: history }

    // Mutate models after the DBus callback returns; doing it inside the
    // callback crashed Qt while a Repeater regenerated.
    Timer {
        id: flushTimer
        interval: 0
        repeat: false
        onTriggered: root.flush()
    }

    Connections {
        target: root.server

        function onNotification(notification) { root.track(notification) }
    }

    Process { id: applicationLaunch }
    Process { id: windowFocus }

    Process {
        id: windowQuery
        property string desktopEntry: ""
        stdout: StdioCollector { id: windowList }

        onExited: exitCode => {
            const entry = desktopEntry
            if (exitCode !== 0) {
                root.launchApplication(entry)
                return
            }

            let windows = []
            try {
                windows = JSON.parse(windowList.text)
            } catch (error) {
                console.warn("Could not parse Niri window list:", error)
            }

            let match = null
            for (let i = 0; i < windows.length; ++i) {
                const appId = root.desktopId(windows[i].app_id)
                if (appId === entry || appId.endsWith("." + entry)
                        || entry.endsWith("." + appId)) {
                    match = windows[i]
                    break
                }
            }

            if (match)
                windowFocus.exec(["niri", "msg", "action", "focus-window", "--id", String(match.id)])
            else
                root.launchApplication(entry)
        }
    }
}
