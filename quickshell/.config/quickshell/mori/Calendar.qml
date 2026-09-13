import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./theme"

Item {
    id: root

    required property var panelWindow
    required property var popupCoordinator
    property date shownMonth: new Date(new Date().getFullYear(), new Date().getMonth(), 1, 12)
    property date selectedDate: new Date(new Date().getFullYear(), new Date().getMonth(), new Date().getDate(), 12)
    property var events: []
    property var eventDays: []
    property string errorMessage: ""
    property string syncMessage: ""
    property bool queryPending: false
    property bool monthQueryPending: false
    readonly property bool busy: syncProcess.running || eventQuery.running || monthQuery.running
    readonly property var weekdayNames: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
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

        errorMessage = ""
        const end = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate() + 1, 12)
        eventQuery.exec([
            "khal", "--no-color", "list", "--once",
            "--json", "title", "--json", "start-time", "--json", "end-time",
            "--json", "calendar", "--json", "calendar-color", "--json", "location",
            dateKey(selectedDate), dateKey(end)
        ])
    }

    function syncAndLoad() {
        if (busy)
            return

        syncMessage = "Syncing CalDAV…"
        errorMessage = ""
        syncProcess.exec(["vdirsyncer", "sync"])
    }

    function toggle() {
        if (popup.visible) {
            close()
        } else {
            popupCoordinator.showPopup(root)
            popup.visible = true
            const now = new Date()
            shownMonth = new Date(now.getFullYear(), now.getMonth(), 1, 12)
            selectedDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 12)
            syncAndLoad()
            queryMonthEvents()
        }
    }

    function close() {
        popup.visible = false
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: clockLabel
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "[ yyyy/MM/dd   hh:mm ]")
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize

        TapHandler { onTapped: root.toggle() }
    }

    Process {
        id: syncProcess

        stderr: StdioCollector { id: syncError }

        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.syncMessage = "Synced just now"
            } else {
                const detail = syncError.text.trim().split(/\r?\n/).pop()
                root.syncMessage = "Using local calendar"
                if (detail.length)
                    root.errorMessage = detail
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
            x: root.panelWindow.popupAnchorX(root, popup.implicitWidth)
            y: parentWindow.height + 6
            width: 1
            height: 1
        }
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left

        onVisibleChanged: if (!visible) root.popupCoordinator.hidePopup(root)

        PopupSurface {
            anchors.fill: parent
            shown: popup.visible
            color: Theme.bg1
            border.width: 2
            border.color: Theme.fg

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Item {
                    width: parent.width
                    height: 24

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "‹"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                        TapHandler { onTapped: root.changeMonth(-1) }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: Qt.formatDate(root.shownMonth, "MMMM yyyy")
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.headingFontSize
                        TapHandler { onTapped: root.goToToday() }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: Theme.fg
                        font.family: Theme.fontFamily
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

                        delegate: Text {
                            required property string modelData
                            width: (parent.width - 12) / 7
                            height: 20
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData
                            color: Theme.grey1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }

                    Repeater {
                        model: 42

                        delegate: Rectangle {
                            id: dayCell
                            required property int index
                            readonly property date value: root.dateForCell(index)
                            readonly property bool selected: root.sameDay(value, root.selectedDate)
                            readonly property bool current: root.sameDay(value, root.today)
                            readonly property bool inMonth: value.getMonth() === root.shownMonth.getMonth()

                            width: (parent.width - 12) / 7
                            height: 28
                            color: selected ? Theme.bg3 : "transparent"
                            border.width: current ? 1 : 0
                            border.color: Theme.fg

                            Text {
                                anchors.centerIn: parent
                                text: dayCell.value.getDate()
                                color: dayCell.selected ? Theme.fg
                                     : dayCell.inMonth ? Theme.fg : Theme.grey
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 3
                                width: 4
                                height: 4
                                radius: 2
                                visible: dayCell.inMonth && root.hasEvent(dayCell.value)
                                color: Theme.fg
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

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDate(root.selectedDate, "dddd, MMMM d")
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.busy ? "Working…" : "↻ " + root.syncMessage
                        color: root.busy ? Theme.yellow : Theme.grey1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                        TapHandler { enabled: !root.busy; onTapped: root.syncAndLoad() }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.errorMessage.length > 0
                    text: root.errorMessage
                    color: Theme.red
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: !root.busy && root.events.length === 0 && root.errorMessage.length === 0
                    text: "No events"
                    color: Theme.grey
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Flickable {
                    width: parent.width
                    height: Math.max(0, popup.implicitHeight - y - 24)
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
                                           ? modelData["calendar-color"] : Theme.fg
                                }

                                Column {
                                    id: eventText
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 6
                                    anchors.leftMargin: 10
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: modelData.title || "Untitled event"
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: (modelData["start-time"]
                                               ? modelData["start-time"] + "–" + modelData["end-time"]
                                               : "All day")
                                              + (modelData.calendar ? " · " + modelData.calendar : "")
                                              + (modelData.location ? " · " + modelData.location : "")
                                        color: Theme.grey1
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 2
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        visible: popup.visible
        anchors { top: true; bottom: true; left: true; right: true }
        margins.top: root.panelWindow.height
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }
}
