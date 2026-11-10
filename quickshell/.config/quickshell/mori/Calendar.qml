import QtQuick
import Quickshell
import Quickshell.Io
import "./theme"

Item {
    id: root

    required property var panelWindow
    required property var popupCoordinator
    required property var settings
    property color accent: Theme.fg
    property date shownMonth: new Date(new Date().getFullYear(), new Date().getMonth(), 1, 12)
    property date selectedDate: new Date(new Date().getFullYear(), new Date().getMonth(), new Date().getDate(), 12)
    property var events: []
    property var eventDays: []
    property string errorMessage: ""
    // Why the last vdirsyncer run failed; shown until the next sync.
    property string syncError: ""
    property string syncMessage: ""
    property bool queryPending: false
    // When vdirsyncer last succeeded (ms); reopening soon after doesn't sync again.
    property double lastSync: 0
    property bool monthQueryPending: false
    property bool dayNavigation: false
    readonly property bool busy: syncProcess.running || eventQuery.running || monthQuery.running
    readonly property var weekdayNames: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    readonly property int monthCellCount: Math.ceil(((shownMonth.getDay() + 6) % 7
        + new Date(shownMonth.getFullYear(), shownMonth.getMonth() + 1, 0).getDate()) / 7) * 7
    readonly property date today: clock.date

    implicitWidth: clockLabel.implicitWidth
    implicitHeight: clockLabel.implicitHeight
    width: implicitWidth
    height: implicitHeight

    function dateKey(value) {
        const year = value.getFullYear()
        const month = String(value.getMonth() + 1).padStart(2, "0")
        const day = String(value.getDate()).padStart(2, "0")
        return year + "-" + month + "-" + day
    }

    function formatEventTime(value) {
        const original = String(value || "")
        const match = /^\s*(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?\s*$/i.exec(original)
        if (!match) return original
        let hour = Number(match[1])
        const minute = match[2]
        const period = match[3] ? match[3].toUpperCase() : ""
        if (period)
            hour = (hour % 12) + (period === "PM" ? 12 : 0)
        if (hour > 23 || Number(minute) > 59) return original
        if (settings.clockTimeFormat === "12h")
            return String(hour % 12 || 12) + ":" + minute + (hour < 12 ? " AM" : " PM")
        return String(hour).padStart(2, "0") + ":" + minute
    }

    function sameDay(left, right) {
        return left.getFullYear() === right.getFullYear()
            && left.getMonth() === right.getMonth()
            && left.getDate() === right.getDate()
    }

    function dateForCell(index) {
        const mondayOffset = (shownMonth.getDay() + 6) % 7
        return new Date(shownMonth.getFullYear(), shownMonth.getMonth(), index - mondayOffset + 1, 12)
    }

    function hasEvent(value) {
        return eventDays.indexOf(dateKey(value)) >= 0
    }

    function selectDate(value) {
        selectedDate = value
        queryEvents()
    }

    function changeMonth(offset) {
        shownMonth = new Date(shownMonth.getFullYear(), shownMonth.getMonth() + offset, 1, 12)
        selectDate(new Date(shownMonth.getFullYear(), shownMonth.getMonth(), 1, 12))
        queryMonthEvents()
    }

    function goToToday() {
        const now = new Date()
        shownMonth = new Date(now.getFullYear(), now.getMonth(), 1, 12)
        selectDate(new Date(now.getFullYear(), now.getMonth(), now.getDate(), 12))
        queryMonthEvents()
    }

    function navigateDay(offset) {
        const next = new Date(selectedDate.getFullYear(), selectedDate.getMonth(),
            selectedDate.getDate() + offset, 12)
        if (next.getFullYear() !== shownMonth.getFullYear()
                || next.getMonth() !== shownMonth.getMonth()) {
            shownMonth = new Date(next.getFullYear(), next.getMonth(), 1, 12)
            queryMonthEvents()
        }
        selectDate(next)
    }

    function parseEvents(output) {
        const parsed = []
        for (const line of output.split(/\r?\n/)) {
            if (!line.trim().length)
                continue

            try {
                const group = JSON.parse(line)
                if (Array.isArray(group))
                    parsed.push(...group)
            } catch (error) {
                console.warn("Could not parse khal output:", error)
            }
        }
        events = parsed
    }

    function parseMonthEvents(output) {
        const days = []
        for (const line of output.split(/\r?\n/)) {
            if (!line.trim().length)
                continue
            try {
                const group = JSON.parse(line)
                if (!Array.isArray(group))
                    continue
                for (const event of group) {
                    const day = event["start-date"]
                    if (day && days.indexOf(day) < 0)
                        days.push(day)
                }
            } catch (error) {
                console.warn("Could not parse khal month output:", error)
            }
        }
        eventDays = days
    }

    function queryMonthEvents() {
        if (monthQuery.running) {
            monthQueryPending = true
            return
        }

        const end = new Date(shownMonth.getFullYear(), shownMonth.getMonth() + 1, 1, 12)
        monthQuery.exec([
            "khal", "--no-color", "list", "--once", "--json", "start-date",
            dateKey(shownMonth), dateKey(end)
        ])
    }

    function queryEvents() {
        if (eventQuery.running) {
            queryPending = true
            return
        }

        errorMessage = syncError
        eventQuery.exec([
            "khal", "--no-color", "list", "--once",
            "--json", "title", "--json", "start-time", "--json", "end-time",
            "--json", "calendar", "--json", "calendar-color", "--json", "location",
            dateKey(selectedDate), "1d"
        ])
    }

    function syncAndLoad() {
        if (syncProcess.running)
            return

        syncMessage = "Syncing CalDAV…"
        syncError = ""
        errorMessage = ""
        syncProcess.exec(["vdirsyncer", "sync"])
    }

    function toggle() {
        if (popup.visible) {
            close()
        } else {
            popupCoordinator.showPopup(root)
            popup.visible = true
            dayNavigation = false
            const now = new Date()
            shownMonth = new Date(now.getFullYear(), now.getMonth(), 1, 12)
            selectedDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 12)
            // Show the local calendar at once; the sync refreshes it when it's done.
            queryEvents()
            queryMonthEvents()
            if (Date.now() - lastSync > 5 * 60000)
                syncAndLoad()
        }
    }

    function close() {
        popup.visible = false
    }

    function handleKeyPressed(event) {
        if (event.key === Qt.Key_Tab) {
            dayNavigation = !dayNavigation
            event.accepted = true
        } else if (event.key === Qt.Key_Backtab) {
            dayNavigation = false
            event.accepted = true
        } else if (dayNavigation && event.key === Qt.Key_Left) {
            navigateDay(-1)
            event.accepted = true
        } else if (dayNavigation && event.key === Qt.Key_Right) {
            navigateDay(1)
            event.accepted = true
        } else if (dayNavigation && event.key === Qt.Key_Up) {
            navigateDay(-7)
            event.accepted = true
        } else if (dayNavigation && event.key === Qt.Key_Down) {
            navigateDay(7)
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            changeMonth(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            changeMonth(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            close()
            event.accepted = true
        }
    }

    SystemClock {
        id: clock
        precision: root.settings.clockShowSeconds
            ? SystemClock.Seconds : SystemClock.Minutes
    }

    BarLabel {
        id: clockLabel
        anchors.centerIn: parent
        text: "[ " + Qt.formatDate(clock.date, root.settings.clockDateFormat)
            + "   " + Qt.formatTime(clock.date, root.settings.clockTimeFormat === "12h"
                ? (root.settings.clockShowSeconds ? "h:mm:ss AP" : "h:mm AP")
                : (root.settings.clockShowSeconds ? "HH:mm:ss" : "HH:mm")) + " ]"
        color: root.accent

        TapHandler { onTapped: root.toggle() }
    }

    Process {
        id: syncProcess

        stderr: StdioCollector { id: syncStderr }

        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.lastSync = Date.now()
                root.syncMessage = "Synced " + root.formatEventTime(Qt.formatTime(new Date(), "HH:mm"))
            } else {
                const detail = syncStderr.text.trim().split(/\r?\n/).pop()
                root.syncMessage = "Using local calendar"
                root.syncError = detail
            }
            root.queryEvents()
            root.queryMonthEvents()
        }
    }

    Process {
        id: eventQuery

        stdout: StdioCollector {
            onStreamFinished: root.parseEvents(this.text)
        }
        stderr: StdioCollector { id: queryError }

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.events = []
                const detail = queryError.text.trim().split(/\r?\n/).pop()
                root.errorMessage = detail.length ? detail : "Could not read calendars"
            }
            if (root.queryPending) {
                root.queryPending = false
                Qt.callLater(root.queryEvents)
            }
        }
    }

    Process {
        id: monthQuery

        stdout: StdioCollector {
            onStreamFinished: root.parseMonthEvents(this.text)
        }
        onExited: function(exitCode) {
            if (exitCode !== 0)
                root.eventDays = []
            if (root.monthQueryPending) {
                root.monthQueryPending = false
                Qt.callLater(root.queryMonthEvents)
            }
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: popup.visible
        onTriggered: root.syncAndLoad()
    }

    PopupWindow {
        id: popup
        implicitWidth: 380
        implicitHeight: 450
        visible: false
        color: "transparent"
        grabFocus: false

        anchor.window: root.panelWindow
        anchor.rect {
            x: root.panelWindow.popupAnchorX(root, popup.implicitWidth, popup.visible)
            y: parentWindow.height + 2
            width: 1
            height: 1
        }
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left

        onVisibleChanged: if (!visible) root.popupCoordinator.hidePopup(root)

        Loader {
            id: popupContent
            anchors.fill: parent
            active: popup.visible

            sourceComponent: Component {
                PopupSurface {
                    anchors.fill: parent
                    shown: popup.visible
                    color: Theme.bg1
                    border.width: 2
                    border.color: root.accent

                    Column {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: calendarHint.top
                        anchors.margins: 12
                        anchors.bottomMargin: 10
                        spacing: 8

                        Item {
                            width: parent.width
                            height: 24

                            MoriText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "‹"
                                color: root.accent
                                font.pixelSize: 20
                                TapHandler { onTapped: root.changeMonth(-1) }
                            }

                            WidgetHeader {
                                anchors.centerIn: parent
                                text: Qt.formatDate(root.shownMonth, "MMMM yyyy")
                                color: root.accent
                                TapHandler { onTapped: root.goToToday() }
                            }

                            MoriText {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"
                                color: root.accent
                                font.pixelSize: 20
                                TapHandler { onTapped: root.changeMonth(1) }
                            }
                        }

                        Grid {
                            width: parent.width
                            columns: 7
                            rowSpacing: 2
                            columnSpacing: 2

                            Repeater {
                                model: root.weekdayNames

                                delegate: MoriText {
                                    required property string modelData
                                    width: (parent.width - 12) / 7
                                    height: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData
                                    color: Theme.grey1
                                    font.pixelSize: Theme.fontSize - 2
                                }
                            }

                            Repeater {
                                model: root.monthCellCount

                                delegate: Rectangle {
                                    id: dayCell
                                    required property int index
                                    readonly property date value: root.dateForCell(index)
                                    readonly property bool selected: root.sameDay(value, root.selectedDate)
                                    readonly property bool keyboardFocused: root.dayNavigation && selected
                                    readonly property bool current: root.sameDay(value, root.today)
                                    readonly property bool inMonth: value.getMonth() === root.shownMonth.getMonth()

                                    opacity: inMonth ? 1 : 0
                                    enabled: inMonth
                                    width: (parent.width - 12) / 7
                                    height: Theme.controlHeight
                                    color: Theme.controlBackground(selected, keyboardFocused, dayHover.hovered)
                                    border.width: 1
                                    border.color: Theme.controlBorder(selected || current, keyboardFocused, dayHover.hovered, root.accent)
                                    HoverHandler { id: dayHover }

                                    MoriText {
                                        anchors.centerIn: parent
                                        text: (dayCell.keyboardFocused ? "› " : "") + dayCell.value.getDate()
                                        color: dayCell.selected ? root.accent
                                             : dayCell.inMonth ? Theme.grey1 : Theme.grey
                                    }

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 3
                                        width: 4
                                        height: 4
                                        radius: 2
                                        visible: dayCell.inMonth && root.hasEvent(dayCell.value)
                                        color: root.accent
                                    }

                                    TapHandler { onTapped: root.selectDate(dayCell.value) }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.bg4
                        }

                        Item {
                            width: parent.width
                            height: 22

                            MoriText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatDate(root.selectedDate, "dddd, MMMM d")
                                color: root.accent
                            }

                            MoriText {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.busy ? "Working…" : "↻ " + root.syncMessage
                                color: root.busy ? Theme.yellow : Theme.grey1
                                font.pixelSize: Theme.fontSize - 2
                                TapHandler { enabled: !root.busy; onTapped: root.syncAndLoad() }
                            }
                        }

                        MoriText {
                            width: parent.width
                            visible: root.errorMessage.length > 0
                            text: root.errorMessage
                            color: Theme.red
                            font.pixelSize: Theme.fontSize - 2
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        MoriText {
                            width: parent.width
                            visible: !root.busy && root.events.length === 0 && root.errorMessage.length === 0
                            text: "No events"
                            color: Theme.grey
                        }

                        Flickable {
                            width: parent.width
                            height: Math.max(0, parent.height - y)
                            contentHeight: eventList.height
                            clip: true

                            Column {
                                id: eventList
                                width: parent.width
                                spacing: 6

                                Repeater {
                                    model: root.events

                                    delegate: Rectangle {
                                        required property var modelData
                                        width: eventList.width
                                        height: eventText.height + 12
                                        color: Theme.bg2

                                        Rectangle {
                                            width: 3
                                            height: parent.height
                                            color: /^#[0-9a-fA-F]{6}$/.test(modelData["calendar-color"] || "")
                                                   ? modelData["calendar-color"] : root.accent
                                        }

                                        Column {
                                            id: eventText
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 6
                                            anchors.leftMargin: 10
                                            spacing: 2

                                            MoriText {
                                                width: parent.width
                                                text: modelData.title || "Untitled event"
                                                color: root.accent
                                                elide: Text.ElideRight
                                            }

                                            MoriText {
                                                width: parent.width
                                                text: (modelData["start-time"]
                                                       ? root.formatEventTime(modelData["start-time"])
                                                           + "–" + root.formatEventTime(modelData["end-time"])
                                                       : "All day")
                                                      + (modelData.calendar ? " · " + modelData.calendar : "")
                                                      + (modelData.location ? " · " + modelData.location : "")
                                                color: Theme.grey1
                                                font.pixelSize: Theme.fontSize - 2
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    KeyboardHint {
                        id: calendarHint
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 12
                        text: root.dayNavigation
                            ? "Days: arrows move date · Tab: months"
                            : "Months: ← / → · Tab: days"
                    }
                }
            }
        }
    }
}
