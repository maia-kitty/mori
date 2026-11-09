import QtQuick
import Quickshell
import Quickshell.Io
import "./theme"
import "PowerCommands.js" as PowerCommands

Item {
    id: root
    visible: false

    property bool calendarEnabled: true
    property bool mediaEnabled: true
    property bool kdeConnectEnabled: true
    property bool systemTrayEnabled: true
    property bool updatesEnabled: true
    property int updateIntervalMinutes: 60
    // upkeep source keys (its --no-<key> flags) that the bar skips.
    property var disabledUpdateSources: []
    readonly property var updateSourceKeys: ["system", "aur", "flatpak", "nix", "fwupd"]
    property bool networkEnabled: true
    property bool volumeEnabled: true
    property bool brightnessEnabled: true
    property bool mediaCompact: false
    property bool networkCompact: false
    property bool volumeCompact: false
    property bool brightnessCompact: false
    property string clockTimeFormat: "24h"
    property string clockDateFormat: "yyyy/MM/dd"
    property bool clockShowSeconds: false
    property bool wallpaperEnabled: true
    property bool notificationsEnabled: true
    property bool powerMenuEnabled: true
    property var powerCommands: ({})
    property bool batteryEnabled: true
    property bool workspacesEnabled: true
    property bool themeEnabled: true
    // Light/dark schedule: "off", "sun" (sunrise to sunset) or "times" (fixed).
    property string themeSchedule: "off"
    property int themeLightTime: 420
    property int themeDarkTime: 1140
    property real themeLatitude: 0
    property real themeLongitude: 0
    // Hides notification popups; notifications still reach the notification centre.
    property bool doNotDisturb: false
    property string wallpaperFolder: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property var defaultLeftOrder: ["calendar", "media", "kdeConnect"]
    readonly property var defaultCenterOrder: ["workspaces"]
    readonly property var defaultRightOrder: [
        "systemTray", "updates", "network", "volume", "brightness", "wallpaper", "theme", "notifications",
        "battery", "powerMenu"
    ]
    // Every module key; each has a `<key>Enabled` property above.
    readonly property var moduleNames: defaultLeftOrder.concat(defaultCenterOrder, defaultRightOrder)
    readonly property var compactNames: ["media", "network", "volume", "brightness"]
    property var leftModuleOrder: defaultLeftOrder
    property var centerModuleOrder: defaultCenterOrder
    property var rightModuleOrder: defaultRightOrder
    property var moduleColors: ({
        "calendar": "fg",
        "media": "aqua",
        "kdeConnect": "orange",
        "systemTray": "fg",
        "updates": "green",
        "network": "blue",
        "volume": "yellow",
        "brightness": "yellow",
        "wallpaper": "green",
        "theme": "yellow",
        "notifications": "purple",
        "battery": "green",
        "workspaces": "fg",
        "powerMenu": "red"
    })

    // Delegates use this to update bindings that access a setting by name.
    property int revision: 0
    // True until the first load; stays false on later reloads so nothing restarts.
    property bool loading: true
    // True while load() applies the file, so its setters don't save.
    property bool reading: false
    property string saveError: ""

    readonly property string xdgConfigHome: Quickshell.env("XDG_CONFIG_HOME") || ""
    readonly property string configRoot: xdgConfigHome.length > 0
        ? xdgConfigHome
        : Quickshell.env("HOME") + "/.config"

    function noteChange() {
        // load() bumps revision once when it's done.
        if (reading) return
        revision++
        if (!loading)
            save()
    }

    function setPowerCommands(commands) {
        if (!commands || typeof commands !== "object" || Array.isArray(commands))
            return false
        for (const name of ["suspend", "reboot", "poweroff"]) {
            if (name in commands && !PowerCommands.valid(commands[name]))
                return false
        }
        powerCommands = Object.assign({}, commands)
        noteChange()
        return true
    }

    function moduleEnabled(name) {
        return moduleNames.indexOf(name) >= 0 && root[name + "Enabled"]
    }

    function setModuleEnabled(name, enabled) {
        if (moduleNames.indexOf(name) < 0) return
        root[name + "Enabled"] = enabled
        noteChange()
    }

    function setUpdateInterval(minutes) {
        if ([0, 15, 60, 180].indexOf(minutes) < 0 || updateIntervalMinutes === minutes)
            return
        updateIntervalMinutes = minutes
        noteChange()
    }

    function updateSourceEnabled(key) {
        return disabledUpdateSources.indexOf(key) < 0
    }

    function setUpdateSourceEnabled(key, enabled) {
        if (updateSourceKeys.indexOf(key) < 0 || updateSourceEnabled(key) === enabled)
            return
        disabledUpdateSources = enabled
            ? disabledUpdateSources.filter(name => name !== key)
            : disabledUpdateSources.concat([key])
        noteChange()
    }

    function compactMode(name) {
        return compactNames.indexOf(name) >= 0 && root[name + "Compact"]
    }

    function setCompactMode(name, compact) {
        if (compactNames.indexOf(name) < 0) return
        root[name + "Compact"] = compact
        noteChange()
    }

    function setClockOption(name, value) {
        if (name === "timeFormat" && ["24h", "12h"].indexOf(value) >= 0) {
            if (clockTimeFormat === value) return
            clockTimeFormat = value
        } else if (name === "dateFormat"
                && ["yyyy/MM/dd", "dd/MM/yyyy", "MM/dd/yyyy"].indexOf(value) >= 0) {
            if (clockDateFormat === value) return
            clockDateFormat = value
        } else if (name === "showSeconds" && typeof value === "boolean") {
            if (clockShowSeconds === value) return
            clockShowSeconds = value
        } else return
        noteChange()
        // The login screen copies the clock format.
        if (name === "timeFormat") Quickshell.execDetached(["mori-greeter-sync"])
    }

    function setThemeOption(name, value) {
        if (name === "schedule" && ["off", "sun", "times"].indexOf(value) >= 0) {
            if (themeSchedule === value) return
            themeSchedule = value
        } else if ((name === "lightTime" || name === "darkTime")
                && Number.isInteger(value) && value >= 0 && value < 1440) {
            if (name === "lightTime") {
                if (themeLightTime === value) return
                themeLightTime = value
            } else {
                if (themeDarkTime === value) return
                themeDarkTime = value
            }
        } else if (name === "latitude" && typeof value === "number" && value >= -90 && value <= 90) {
            if (themeLatitude === value) return
            themeLatitude = value
        } else if (name === "longitude" && typeof value === "number" && value >= -180 && value <= 180) {
            if (themeLongitude === value) return
            themeLongitude = value
        } else return
        noteChange()
    }

    function setDoNotDisturb(enabled) {
        if (typeof enabled !== "boolean" || doNotDisturb === enabled) return
        doNotDisturb = enabled
        noteChange()
    }

    function setWallpaperFolder(path) {
        if (typeof path !== "string" || !path.startsWith("/") || wallpaperFolder === path) return
        wallpaperFolder = path
        noteChange()
    }

    function moduleColor(name) {
        switch (moduleColors[name]) {
        case "red": return Theme.red
        case "yellow": return Theme.yellow
        case "green": return Theme.green
        case "blue": return Theme.blue
        case "purple": return Theme.purple
        case "aqua": return Theme.aqua
        case "orange": return Theme.orange
        default: return Theme.fg
        }
    }

    function setModuleColor(name, colorName) {
        if (!(name in moduleColors) || moduleColors[name] === colorName)
            return
        const updated = Object.assign({}, moduleColors)
        updated[name] = colorName
        moduleColors = updated
        noteChange()
    }

    function moduleSide(name) {
        if (leftModuleOrder.indexOf(name) >= 0)
            return "left"
        if (centerModuleOrder.indexOf(name) >= 0)
            return "center"
        return "right"
    }

    function moveModuleTo(name, targetSide, targetIndex) {
        const left = leftModuleOrder.slice()
        const center = centerModuleOrder.slice()
        const right = rightModuleOrder.slice()
        const leftIndex = left.indexOf(name)
        const centerIndex = center.indexOf(name)
        const rightIndex = right.indexOf(name)
        let sourceSide = ""
        let sourceIndex = -1

        if (leftIndex >= 0) {
            left.splice(leftIndex, 1)
            sourceSide = "left"
            sourceIndex = leftIndex
        } else if (centerIndex >= 0) {
            center.splice(centerIndex, 1)
            sourceSide = "center"
            sourceIndex = centerIndex
        } else if (rightIndex >= 0) {
            right.splice(rightIndex, 1)
            sourceSide = "right"
            sourceIndex = rightIndex
        } else {
            return
        }

        const destination = targetSide === "left" ? left
            : targetSide === "center" ? center : right
        let insertionIndex = targetIndex
        if (sourceSide === targetSide && sourceIndex < targetIndex)
            insertionIndex--
        insertionIndex = Math.max(0, Math.min(insertionIndex, destination.length))
        destination.splice(insertionIndex, 0, name)

        leftModuleOrder = left
        centerModuleOrder = center
        rightModuleOrder = right
        noteChange()
    }

    function normalizedOrders(leftCandidate, centerCandidate, rightCandidate) {
        const defaultLeft = defaultLeftOrder
        const defaultCenter = defaultCenterOrder
        const defaultRight = defaultRightOrder
        const allowed = moduleNames
        const left = []
        const center = []
        const right = []
        const seen = []

        function append(candidate, destination) {
            if (!Array.isArray(candidate))
                return
            for (const name of candidate) {
                if (allowed.indexOf(name) >= 0 && seen.indexOf(name) < 0) {
                    destination.push(name)
                    seen.push(name)
                }
            }
        }

        append(leftCandidate, left)
        append(centerCandidate, center)
        append(rightCandidate, right)
        for (const name of defaultLeft) {
            if (seen.indexOf(name) < 0)
                left.push(name)
        }
        for (const name of defaultCenter) {
            if (seen.indexOf(name) < 0)
                center.push(name)
        }
        for (const name of defaultRight) {
            if (seen.indexOf(name) < 0)
                right.push(name)
        }
        return { "left": left, "center": center, "right": right }
    }

    function load() {
        reading = true
        const contents = settingsFile.text()
        if (contents.trim().length > 0) {
            try {
                const parsed = JSON.parse(contents)
                powerCommands = Object.prototype.hasOwnProperty.call(parsed, "power")
                    ? parsed.power : ({})
                const modules = parsed.modules || {}
                for (const name of Object.keys(modules)) {
                    if (typeof modules[name] === "boolean")
                        setModuleEnabled(name, modules[name])
                }

                const order = parsed.order || {}
                const normalized = normalizedOrders(
                    order.left, order.center, order.right)
                leftModuleOrder = normalized.left
                centerModuleOrder = normalized.center
                rightModuleOrder = normalized.right

                const colors = parsed.colors || {}
                const updatedColors = Object.assign({}, moduleColors)
                for (const name of Object.keys(updatedColors)) {
                    if (typeof colors[name] === "string" && colors[name].length > 0)
                        updatedColors[name] = colors[name]
                }
                moduleColors = updatedColors

                const compact = parsed.compact || {}
                for (const name of compactNames) {
                    if (typeof compact[name] === "boolean")
                        setCompactMode(name, compact[name])
                }

                const clock = parsed.clock || {}
                const updates = parsed.updates || {}
                if ([0, 15, 60, 180].indexOf(updates.intervalMinutes) >= 0)
                    updateIntervalMinutes = updates.intervalMinutes
                if (Array.isArray(updates.disabledSources))
                    disabledUpdateSources = updateSourceKeys.filter(
                        key => updates.disabledSources.indexOf(key) >= 0)
                if (["24h", "12h"].indexOf(clock.timeFormat) >= 0)
                    clockTimeFormat = clock.timeFormat
                if (["yyyy/MM/dd", "dd/MM/yyyy", "MM/dd/yyyy"].indexOf(clock.dateFormat) >= 0)
                    clockDateFormat = clock.dateFormat
                if (typeof clock.showSeconds === "boolean")
                    clockShowSeconds = clock.showSeconds

                const notifications = parsed.notifications || {}
                if ("doNotDisturb" in notifications)
                    setDoNotDisturb(notifications.doNotDisturb)

                const wallpaper = parsed.wallpaper || {}
                if ("folder" in wallpaper)
                    setWallpaperFolder(wallpaper.folder)

                const theme = parsed.theme || {}
                for (const name of ["schedule", "lightTime", "darkTime", "latitude", "longitude"]) {
                    if (name in theme)
                        setThemeOption(name, theme[name])
                }
            } catch (error) {
                console.warn("Could not parse Mori settings:", error)
            }
        }

        reading = false
        loading = false
        revision++
    }

    // { name: root[name + suffix] } for the saved file.
    function valuesOf(names, suffix) {
        const values = {}
        for (const name of names) values[name] = root[name + suffix]
        return values
    }

    function save() {
        const contents = {
            "modules": valuesOf(moduleNames, "Enabled"),
            "order": {
                "left": leftModuleOrder,
                "center": centerModuleOrder,
                "right": rightModuleOrder
            },
            "colors": moduleColors,
            "updates": { "intervalMinutes": updateIntervalMinutes, "disabledSources": disabledUpdateSources },
            "power": powerCommands,
            "compact": valuesOf(compactNames, "Compact"),
            "clock": {
                "timeFormat": clockTimeFormat,
                "dateFormat": clockDateFormat,
                "showSeconds": clockShowSeconds
            },
            "notifications": { "doNotDisturb": doNotDisturb },
            "wallpaper": { "folder": wallpaperFolder },
            "theme": {
                "schedule": themeSchedule,
                "lightTime": themeLightTime,
                "darkTime": themeDarkTime,
                "latitude": themeLatitude,
                "longitude": themeLongitude
            }
        }
        settingsFile.setText(JSON.stringify(contents, null, 2) + "\n")
    }

    Component.onCompleted: load()

    FileView {
        id: settingsFile
        path: root.configRoot + "/quickshell/mori-settings.json"
        blockLoading: true
        // This file is tiny, and shell settings save as soon as they change.
        blockWrites: true
        printErrors: false
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.load()
        onSaved: root.saveError = ""
        onSaveFailed: error => {
            root.saveError = FileViewError.toString(error)
            console.warn("Could not save Mori settings:", root.saveError)
        }
    }
}
