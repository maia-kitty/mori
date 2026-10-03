import QtQuick
import Quickshell
import Quickshell.Io
import "./theme"

Item {
    id: root
    visible: false

    property bool calendarEnabled: true
    property bool mediaEnabled: true
    property bool kdeConnectEnabled: true
    property bool systemTrayEnabled: true
    property bool networkEnabled: true
    property bool volumeEnabled: true
    property bool brightnessEnabled: true
    property bool mediaCompact: false
    property bool networkCompact: false
    property bool volumeCompact: false
    property bool brightnessCompact: false
    property bool wallpaperEnabled: true
    property bool notificationsEnabled: true
    property bool powerMenuEnabled: true
    property bool batteryEnabled: true
    property bool workspacesEnabled: true
    property var leftModuleOrder: ["calendar", "media", "kdeConnect"]
    property var centerModuleOrder: ["workspaces"]
    property var rightModuleOrder: [
        "systemTray", "network", "volume", "brightness", "wallpaper", "notifications", "battery",
        "powerMenu"
    ]
    property var moduleColors: ({
        "calendar": "fg",
        "media": "aqua",
        "kdeConnect": "orange",
        "systemTray": "fg",
        "network": "blue",
        "volume": "yellow",
        "brightness": "yellow",
        "wallpaper": "green",
        "notifications": "purple",
        "battery": "green",
        "workspaces": "fg",
        "powerMenu": "red"
    })

    // Delegates use this to update bindings that access a setting by name.
    property int revision: 0
    property bool loading: true
    property string saveError: ""

    readonly property string xdgConfigHome: Quickshell.env("XDG_CONFIG_HOME") || ""
    readonly property string configRoot: xdgConfigHome.length > 0
        ? xdgConfigHome
        : Quickshell.env("HOME") + "/.config"

    function moduleEnabled(name) {
        switch (name) {
        case "calendar": return calendarEnabled
        case "media": return mediaEnabled
        case "kdeConnect": return kdeConnectEnabled
        case "systemTray": return systemTrayEnabled
        case "network": return networkEnabled
        case "volume": return volumeEnabled
        case "brightness": return brightnessEnabled
        case "wallpaper": return wallpaperEnabled
        case "notifications": return notificationsEnabled
        case "powerMenu": return powerMenuEnabled
        case "battery": return batteryEnabled
        case "workspaces": return workspacesEnabled
        default: return false
        }
    }

    function setModuleEnabled(name, enabled) {
        switch (name) {
        case "calendar": calendarEnabled = enabled; break
        case "media": mediaEnabled = enabled; break
        case "kdeConnect": kdeConnectEnabled = enabled; break
        case "systemTray": systemTrayEnabled = enabled; break
        case "network": networkEnabled = enabled; break
        case "volume": volumeEnabled = enabled; break
        case "brightness": brightnessEnabled = enabled; break
        case "wallpaper": wallpaperEnabled = enabled; break
        case "notifications": notificationsEnabled = enabled; break
        case "powerMenu": powerMenuEnabled = enabled; break
        case "battery": batteryEnabled = enabled; break
        case "workspaces": workspacesEnabled = enabled; break
        default: return
        }

        revision++
        if (!loading)
            save()
    }

    function compactMode(name) {
        switch (name) {
        case "media": return mediaCompact
        case "network": return networkCompact
        case "volume": return volumeCompact
        case "brightness": return brightnessCompact
        default: return false
        }
    }

    function setCompactMode(name, compact) {
        switch (name) {
        case "media": mediaCompact = compact; break
        case "network": networkCompact = compact; break
        case "volume": volumeCompact = compact; break
        case "brightness": brightnessCompact = compact; break
        default: return
        }
        revision++
        if (!loading)
            save()
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
        revision++
        if (!loading)
            save()
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
        revision++
        if (!loading)
            save()
    }

    function normalizedOrders(leftCandidate, centerCandidate, rightCandidate) {
        const defaultLeft = ["calendar", "media", "kdeConnect"]
        const defaultCenter = ["workspaces"]
        const defaultRight = [
            "systemTray", "network", "volume", "brightness", "wallpaper",
            "notifications", "battery", "powerMenu"
        ]
        const allowed = defaultLeft.concat(defaultCenter, defaultRight)
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
        const contents = settingsFile.text()
        if (contents.trim().length > 0) {
            try {
                const parsed = JSON.parse(contents)
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
                for (const name of ["media", "network", "volume", "brightness"]) {
                    if (typeof compact[name] === "boolean")
                        setCompactMode(name, compact[name])
                }
            } catch (error) {
                console.warn("Could not parse Mori settings:", error)
            }
        }

        loading = false
        revision++
    }

    function save() {
        const contents = {
            "modules": {
                "calendar": calendarEnabled,
                "media": mediaEnabled,
                "kdeConnect": kdeConnectEnabled,
                "systemTray": systemTrayEnabled,
                "network": networkEnabled,
                "volume": volumeEnabled,
                "brightness": brightnessEnabled,
                "wallpaper": wallpaperEnabled,
                "notifications": notificationsEnabled,
                "battery": batteryEnabled,
                "workspaces": workspacesEnabled,
                "powerMenu": powerMenuEnabled
            },
            "order": {
                "left": leftModuleOrder,
                "center": centerModuleOrder,
                "right": rightModuleOrder
            },
            "colors": moduleColors,
            "compact": {
                "media": mediaCompact,
                "network": networkCompact,
                "volume": volumeCompact,
                "brightness": brightnessCompact
            }
        }
        settingsFile.setText(JSON.stringify(contents, null, 2) + "\n")
    }

    Component.onCompleted: load()

    FileView {
        id: settingsFile
        path: root.configRoot + "/quickshell/mori-settings.json"
        blockLoading: true
        printErrors: false
        atomicWrites: true
        onSaved: root.saveError = ""
        onSaveFailed: error => {
            root.saveError = FileViewError.toString(error)
            console.warn("Could not save Mori settings:", root.saveError)
        }
    }
}
