import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./theme"

Item {
    id: root

    required property var panelWindow
    required property var popupCoordinator
    required property var settings

    width: 0
    height: 0

    property string page: "home"
    property string draggingModule: ""
    property string dragSourceSide: ""
    property int dragSourceIndex: -1
    property string dropSide: ""
    property int dropIndex: -1
    property real dragStartY: 0
    property real dragY: 0
    property var displays: []
    property string displayError: ""
    property string displayStatus: ""
    property string selectedDisplay: ""
    property var targetScreen: null
    property bool focusQueryResolved: false
    property string previousOutputConfiguration: ""
    property var previousDisplays: []
    property string displaySavePhase: "idle"
    property bool awaitingDisplayConfirmation: false
    property int displayConfirmationSeconds: 15
    property real displayViewScale: 0.1
    property real displayOriginX: 0
    property real displayOriginY: 0
    property real displayLayoutWidth: 1
    property real displayLayoutHeight: 1

    readonly property var allModules: [
        "calendar", "media", "kdeConnect", "systemTray", "network",
        "volume", "brightness", "wallpaper", "notifications", "battery", "workspaces",
        "powerMenu"
    ]
    readonly property var colorChoices: [
        { "name": "White", "token": "fg", "color": Theme.fg },
        { "name": "Red", "token": "red", "color": Theme.red },
        { "name": "Yellow", "token": "yellow", "color": Theme.yellow },
        { "name": "Green", "token": "green", "color": Theme.green },
        { "name": "Blue", "token": "blue", "color": Theme.blue },
        { "name": "Purple", "token": "purple", "color": Theme.purple },
        { "name": "Aqua", "token": "aqua", "color": Theme.aqua },
        { "name": "Orange", "token": "orange", "color": Theme.orange }
    ]

    function moduleLabel(name) {
        switch (name) {
        case "calendar": return "Calendar"
        case "media": return "Media"
        case "kdeConnect": return "KDE Connect"
        case "systemTray": return "System tray"
        case "network": return "Network"
        case "volume": return "Volume"
        case "brightness": return "Brightness"
        case "wallpaper": return "Wallpaper picker"
        case "notifications": return "Notifications"
        case "powerMenu": return "Power menu"
        case "battery": return "Battery"
        case "workspaces": return "Workspaces"
        default: return name
        }
    }

    function pageTitle() {
        switch (page) {
        case "modules": return "Modules"
        case "appearance": return "Appearance"
        case "displays": return "Displays"
        case "about": return "About"
        default: return "Mori settings"
        }
    }

    function toggle() {
        if (settingsWindow.visible) {
            close()
        } else {
            page = "home"
            focusQueryResolved = false
            if (!focusedOutputQuery.running)
                focusedOutputQuery.exec(["niri", "msg", "--json", "focused-output"])
        }
    }

    function screenByName(name) {
        for (const screen of Quickshell.screens) {
            if (screen.name === name)
                return screen
        }
        return null
    }

    function openOnFocusedOutput(text) {
        if (focusQueryResolved)
            return
        focusQueryResolved = true
        try {
            const output = JSON.parse(text)
            targetScreen = screenByName(output.name || output.connector)
                || panelWindow.screen
        } catch (error) {
            targetScreen = panelWindow.screen
        }
        popupCoordinator.showPopup(root)
        settingsWindow.visible = true
    }

    function close() {
        draggingModule = ""
        dragSourceSide = ""
        dragSourceIndex = -1
        dropSide = ""
        dropIndex = -1
        settingsWindow.visible = false
    }

    function openPage(name) {
        page = name
        if (name === "displays")
            refreshDisplays()
    }

    function refreshDisplays() {
        displayError = ""
        displayStatus = ""
        if (!displayQuery.running)
            displayQuery.exec(["niri", "msg", "--json", "outputs"])
    }

    function parseDisplays(text) {
        try {
            const parsed = JSON.parse(text)
            const result = []
            for (const connector of Object.keys(parsed)) {
                const output = parsed[connector]
                const enabled = output.logical !== null
                    && output.logical !== undefined
                const logical = output.logical || {}
                let mode = null
                if (typeof output.current_mode === "number" && Array.isArray(output.modes))
                    mode = output.modes[output.current_mode]
                else if (output.current_mode && typeof output.current_mode === "object")
                    mode = output.current_mode
                const scale = logical.scale || 1
                const modes = (output.modes || []).map(candidate => ({
                    "width": candidate.width,
                    "height": candidate.height,
                    "refreshRate": candidate.refresh_rate || 0,
                    "preferred": candidate.is_preferred || false
                }))
                let modeIndex = typeof output.current_mode === "number"
                    ? output.current_mode : modes.findIndex(candidate => mode
                        && candidate.width === mode.width
                        && candidate.height === mode.height
                        && candidate.refreshRate === (mode.refresh_rate || 0))
                if (!mode && modes.length > 0) {
                    modeIndex = modes.findIndex(candidate => candidate.preferred)
                    if (modeIndex < 0)
                        modeIndex = 0
                    mode = {
                        "width": modes[modeIndex].width,
                        "height": modes[modeIndex].height,
                        "refresh_rate": modes[modeIndex].refreshRate
                    }
                }
                if (mode && modeIndex < 0) {
                    modes.push({
                        "width": mode.width,
                        "height": mode.height,
                        "refreshRate": mode.refresh_rate || 0,
                        "preferred": false
                    })
                    modeIndex = modes.length - 1
                }
                result.push({
                    "connector": connector,
                    "label": displayName(Object.assign({}, output, { "connector": connector })),
                    "enabled": enabled,
                    "x": logical.x || 0,
                    "y": logical.y || 0,
                    "width": logical.width || (mode ? mode.width / scale : 640),
                    "height": logical.height || (mode ? mode.height / scale : 360),
                    "scale": scale,
                    "transform": normalizeTransform(logical.transform || "normal"),
                    "modeWidth": mode ? mode.width : 0,
                    "modeHeight": mode ? mode.height : 0,
                    "refreshRate": mode && mode.refresh_rate ? mode.refresh_rate : 0,
                    "modes": modes,
                    "modeIndex": Math.max(0, modeIndex)
                })
            }
            displays = result
            selectedDisplay = result.length > 0 ? result[0].connector : ""
            displayError = ""
            Qt.callLater(fitDisplayLayout)
        } catch (error) {
            displays = []
            displayError = "Could not read Niri outputs"
        }
    }

    function displayName(output) {
        const description = [output.make, output.model].filter(value => value).join(" ")
        return description.length > 0 ? description : output.connector
    }

    function displayDetails(output) {
        const size = output.modeWidth > 0
            ? output.modeWidth + "×" + output.modeHeight : "disabled"
        const refresh = output.refreshRate
            ? " @ " + (output.refreshRate / 1000).toFixed(2) + " Hz" : ""
        const scale = output.scale ? "  ·  " + output.scale + "×" : ""
        const transform = output.transform && output.transform !== "Normal"
            ? "  ·  " + output.transform : ""
        return size + refresh + scale + transform
    }

    function normalizeTransform(value) {
        const normalized = String(value || "normal").toLowerCase()
            .replace(/^_/, "").replace(/_/g, "-")
        switch (normalized) {
        case "flipped90": return "flipped-90"
        case "flipped180": return "flipped-180"
        case "flipped270": return "flipped-270"
        default: return normalized
        }
    }

    function geometryForMode(modeWidth, modeHeight, scale, transform) {
        const rotated = transform === "90" || transform === "270"
            || transform === "flipped-90" || transform === "flipped-270"
        return {
            "width": (rotated ? modeHeight : modeWidth) / scale,
            "height": (rotated ? modeWidth : modeHeight) / scale
        }
    }

    function updateSelectedDisplay(changes) {
        const updated = displays.map(output => {
            if (output.connector !== selectedDisplay)
                return output
            const changed = Object.assign({}, output, changes)
            const geometry = geometryForMode(
                changed.modeWidth, changed.modeHeight, changed.scale, changed.transform)
            changed.width = geometry.width
            changed.height = geometry.height
            return changed
        })
        displays = updated
        displayStatus = "Unsaved display changes"
        Qt.callLater(fitDisplayLayout)
    }

    function availableResolutions(output) {
        if (!output)
            return []
        const resolutions = []
        for (const mode of output.modes) {
            const exists = resolutions.some(resolution =>
                resolution.width === mode.width && resolution.height === mode.height)
            if (!exists)
                resolutions.push({ "width": mode.width, "height": mode.height })
        }
        return resolutions
    }

    function availableRefreshRates(output) {
        if (!output)
            return []
        const rates = []
        for (const mode of output.modes) {
            if (mode.width !== output.modeWidth || mode.height !== output.modeHeight)
                continue
            if (rates.indexOf(mode.refreshRate) < 0)
                rates.push(mode.refreshRate)
        }
        return rates
    }

    function cycleSelectedResolution(offset) {
        const output = selectedDisplayData()
        const resolutions = availableResolutions(output)
        if (!output || resolutions.length === 0)
            return
        let index = resolutions.findIndex(resolution =>
            resolution.width === output.modeWidth && resolution.height === output.modeHeight)
        if (index < 0)
            index = 0
        index = (index + offset + resolutions.length) % resolutions.length
        const resolution = resolutions[index]
        const candidates = output.modes.filter(mode =>
            mode.width === resolution.width && mode.height === resolution.height)
        let mode = candidates.find(candidate =>
            candidate.refreshRate === output.refreshRate)
        if (!mode)
            mode = candidates.find(candidate => candidate.preferred)
        if (!mode)
            mode = candidates[0]
        const modeIndex = output.modes.findIndex(candidate =>
            candidate.width === mode.width && candidate.height === mode.height
                && candidate.refreshRate === mode.refreshRate)
        updateSelectedDisplay({
            "modeIndex": modeIndex,
            "modeWidth": mode.width,
            "modeHeight": mode.height,
            "refreshRate": mode.refreshRate
        })
    }

    function cycleSelectedRefreshRate(offset) {
        const output = selectedDisplayData()
        const rates = availableRefreshRates(output)
        if (!output || rates.length === 0)
            return
        let index = rates.indexOf(output.refreshRate)
        if (index < 0)
            index = 0
        index = (index + offset + rates.length) % rates.length
        const refreshRate = rates[index]
        const modeIndex = output.modes.findIndex(mode =>
            mode.width === output.modeWidth && mode.height === output.modeHeight
                && mode.refreshRate === refreshRate)
        updateSelectedDisplay({
            "modeIndex": modeIndex,
            "refreshRate": refreshRate
        })
    }

    function adjustSelectedScale(offset) {
        const output = selectedDisplayData()
        if (!output)
            return
        const scale = Math.max(0.5, Math.min(4,
            Math.round((output.scale + offset) * 4) / 4))
        updateSelectedDisplay({ "scale": scale })
    }

    function enabledDisplayCount() {
        return displays.filter(output => output.enabled).length
    }

    function setSelectedDisplayEnabled(enabled) {
        const output = selectedDisplayData()
        if (!output || output.enabled === enabled)
            return
        if (!enabled && enabledDisplayCount() <= 1) {
            displayError = "At least one display must remain enabled"
            return
        }
        displayError = ""
        updateSelectedDisplay({ "enabled": enabled })
    }

    function cycleSelectedTransform(offset) {
        const output = selectedDisplayData()
        if (!output)
            return
        const transforms = [
            "normal", "90", "180", "270",
            "flipped", "flipped-90", "flipped-180", "flipped-270"
        ]
        let index = transforms.indexOf(output.transform)
        if (index < 0)
            index = 0
        index = (index + offset + transforms.length) % transforms.length
        updateSelectedDisplay({ "transform": transforms[index] })
    }

    function fitDisplayLayout() {
        if (displays.length === 0 || !displayCanvas)
            return
        let minX = displays[0].x
        let minY = displays[0].y
        let maxX = displays[0].x + displays[0].width
        let maxY = displays[0].y + displays[0].height
        for (const output of displays) {
            minX = Math.min(minX, output.x)
            minY = Math.min(minY, output.y)
            maxX = Math.max(maxX, output.x + output.width)
            maxY = Math.max(maxY, output.y + output.height)
        }
        displayOriginX = minX
        displayOriginY = minY
        displayLayoutWidth = Math.max(1, maxX - minX)
        displayLayoutHeight = Math.max(1, maxY - minY)
        displayViewScale = Math.min(
            (displayCanvas.width - 40) / displayLayoutWidth,
            (displayCanvas.height - 40) / displayLayoutHeight)
    }

    function displayCanvasX(output) {
        return (displayCanvas.width - displayLayoutWidth * displayViewScale) / 2
            + (output.x - displayOriginX) * displayViewScale
    }

    function displayCanvasY(output) {
        return (displayCanvas.height - displayLayoutHeight * displayViewScale) / 2
            + (output.y - displayOriginY) * displayViewScale
    }

    function snapDisplayPosition(connector, proposedX, proposedY) {
        const moving = displays.find(output => output.connector === connector)
        if (!moving)
            return { "x": proposedX, "y": proposedY }
        let x = proposedX
        let y = proposedY
        const threshold = 60
        for (const output of displays) {
            if (output.connector === connector)
                continue
            const xCandidates = [output.x, output.x + output.width,
                output.x - moving.width]
            const yCandidates = [output.y, output.y + output.height,
                output.y - moving.height]
            for (const candidate of xCandidates) {
                if (Math.abs(x - candidate) < threshold)
                    x = candidate
            }
            for (const candidate of yCandidates) {
                if (Math.abs(y - candidate) < threshold)
                    y = candidate
            }
        }
        return { "x": Math.round(x), "y": Math.round(y) }
    }

    function updateDisplayPosition(connector, proposedX, proposedY) {
        const snapped = snapDisplayPosition(connector, proposedX, proposedY)
        const updated = displays.map(output => output.connector === connector
            ? Object.assign({}, output, snapped) : output)
        displays = updated
        selectedDisplay = connector
        displayStatus = "Unsaved layout changes"
        Qt.callLater(fitDisplayLayout)
    }

    function selectedDisplayData() {
        return displays.find(output => output.connector === selectedDisplay) || null
    }

    function regexEscape(value) {
        return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    }

    function braceDelta(line) {
        return (line.match(/\{/g) || []).length - (line.match(/\}/g) || []).length
    }

    function updateOutputConfiguration(contents, output) {
        const lines = contents.length > 0 ? contents.split(/\r?\n/) : []
        const outputPattern = new RegExp("^\\s*output\\s+\\\""
            + regexEscape(output.connector) + "\\\"\\s*\\{")
        let start = -1
        let end = -1
        let positionLine = -1
        let modeLine = -1
        let scaleLine = -1
        let transformLine = -1
        let offLine = -1
        let depth = 0
        for (let index = 0; index < lines.length; ++index) {
            if (start < 0) {
                if (outputPattern.test(lines[index])) {
                    start = index
                    depth = braceDelta(lines[index])
                }
                continue
            }
            if (depth === 1 && /^\s*position\b/.test(lines[index]))
                positionLine = index
            if (depth === 1 && /^\s*mode\b/.test(lines[index]))
                modeLine = index
            if (depth === 1 && /^\s*scale\b/.test(lines[index]))
                scaleLine = index
            if (depth === 1 && /^\s*transform\b/.test(lines[index]))
                transformLine = index
            if (depth === 1 && /^\s*off\s*(?:\/\/.*)?$/.test(lines[index]))
                offLine = index
            depth += braceDelta(lines[index])
            if (depth === 0) {
                end = index
                break
            }
        }

        const position = "    position x=" + Math.round(output.x)
            + " y=" + Math.round(output.y)
        const mode = "    mode \"" + output.modeWidth + "x" + output.modeHeight
            + "@" + (output.refreshRate / 1000).toFixed(3) + "\""
        const scale = "    scale " + Number(output.scale.toFixed(2))
        const transform = "    transform \"" + output.transform + "\""
        if (start < 0) {
            if (lines.length > 0 && lines[lines.length - 1].length > 0)
                lines.push("")
            lines.push("output \"" + output.connector.replace(/\\/g, "\\\\")
                .replace(/\"/g, "\\\"") + "\" {")
            lines.push(mode)
            lines.push(scale)
            lines.push(transform)
            lines.push(position)
            if (!output.enabled)
                lines.push("    off")
            lines.push("}")
        } else {
            const replacements = [
                { "index": modeLine, "value": mode },
                { "index": scaleLine, "value": scale },
                { "index": transformLine, "value": transform },
                { "index": positionLine, "value": position }
            ]
            const missing = []
            for (const replacement of replacements) {
                if (replacement.index >= 0) {
                    const indent = /^\s*/.exec(lines[replacement.index])[0]
                    lines[replacement.index] = indent
                        + replacement.value.replace(/^\s+/, "")
                } else {
                    missing.push(replacement.value)
                }
            }
            if (end >= 0 && missing.length > 0)
                lines.splice(end, 0, ...missing)
            if (!output.enabled && offLine < 0) {
                lines.splice(end + missing.length, 0, "    off")
            } else if (output.enabled && offLine >= 0) {
                lines.splice(offLine, 1)
            }
        }
        return lines.join("\n")
    }

    function saveDisplayLayout() {
        if (displaySavePhase !== "idle" || awaitingDisplayConfirmation)
            return
        let contents = outputsFile.text()
        previousOutputConfiguration = contents
        previousDisplays = JSON.parse(JSON.stringify(displays))
        for (const output of displays)
            contents = updateOutputConfiguration(contents, output)
        if (contents.length > 0 && !contents.endsWith("\n"))
            contents += "\n"
        const currentScreenName = settingsWindow.screen ? settingsWindow.screen.name : ""
        const currentOutput = displays.find(output => output.connector === currentScreenName)
        if (currentOutput && !currentOutput.enabled) {
            const fallback = displays.find(output => output.enabled)
            const fallbackScreen = fallback ? screenByName(fallback.connector) : null
            if (fallbackScreen)
                targetScreen = fallbackScreen
        }
        displaySavePhase = "applying"
        outputsFile.setText(contents)
        displayStatus = "Applying display changes…"
    }

    function keepDisplayConfiguration() {
        displayConfirmationTimer.stop()
        awaitingDisplayConfirmation = false
        previousOutputConfiguration = ""
        previousDisplays = []
        displaySavePhase = "idle"
        displayStatus = "Display settings kept"
    }

    function revertDisplayConfiguration(reason) {
        if (previousOutputConfiguration.length === 0)
            return
        displayConfirmationTimer.stop()
        awaitingDisplayConfirmation = false
        displaySavePhase = "reverting"
        displayStatus = reason || "Reverting display settings…"
        if (previousDisplays.length > 0) {
            displays = JSON.parse(JSON.stringify(previousDisplays))
            Qt.callLater(fitDisplayLayout)
        }
        outputsFile.setText(previousOutputConfiguration)
    }

    function beginDrag(row) {
        const position = row.mapToItem(settingsCard, 0, 0)
        draggingModule = row.moduleKey
        dragSourceSide = row.moduleSide
        dragSourceIndex = row.modelIndex
        dropSide = row.moduleSide
        dropIndex = row.modelIndex
        dragStartY = position.y
        dragY = position.y
    }

    function updateDrag(translationY) {
        dragY = Math.max(0, Math.min(settingsCard.height - 38, dragStartY + translationY))
    }

    function setDropTarget(side, index) {
        if (draggingModule.length === 0)
            return
        dropSide = side
        dropIndex = index
    }

    function modulePreviewOffset(side, index, moduleKey) {
        if (draggingModule.length === 0 || moduleKey === draggingModule)
            return 0
        const rowHeight = 38
        if (dragSourceSide !== dropSide) {
            if (side === dragSourceSide && index > dragSourceIndex)
                return -rowHeight
            if (side === dropSide && index >= dropIndex)
                return rowHeight
            return 0
        }
        if (side !== dragSourceSide)
            return 0
        let insertionIndex = dropIndex
        if (dragSourceIndex < dropIndex)
            insertionIndex--
        if (insertionIndex > dragSourceIndex
                && index > dragSourceIndex && index <= insertionIndex)
            return -rowHeight
        if (insertionIndex < dragSourceIndex
                && index >= insertionIndex && index < dragSourceIndex)
            return rowHeight
        return 0
    }

    function anchorHeightAdjustment(side) {
        if (draggingModule.length === 0 || dragSourceSide === dropSide)
            return 0
        if (side === dragSourceSide)
            return -38
        if (side === dropSide)
            return 38
        return 0
    }

    function finishDrag() {
        if (draggingModule.length === 0)
            return
        const moduleKey = draggingModule
        const targetSide = dropSide
        const targetIndex = dropIndex
        Qt.callLater(() => {
            settings.moveModuleTo(moduleKey, targetSide, targetIndex)
            draggingModule = ""
            dragSourceSide = ""
            dragSourceIndex = -1
            dropSide = ""
            dropIndex = -1
        })
    }

    Process {
        id: displayQuery
        stdout: StdioCollector {
            onStreamFinished: root.parseDisplays(this.text)
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.displays = []
                root.displayError = "Could not connect to Niri"
            }
        }
    }

    Process {
        id: focusedOutputQuery
        stdout: StdioCollector {
            onStreamFinished: root.openOnFocusedOutput(this.text)
        }
        onExited: exitCode => {
            if (!root.focusQueryResolved)
                root.openOnFocusedOutput("")
        }
    }

    Process {
        id: configValidation
        onExited: exitCode => {
            if (root.displaySavePhase === "applying") {
                if (exitCode === 0) {
                    root.displayConfirmationSeconds = 15
                    root.awaitingDisplayConfirmation = true
                    root.displayStatus = "Keep these display settings?"
                    displayConfirmationTimer.start()
                } else {
                    root.displayError = "Invalid Niri output configuration"
                    root.revertDisplayConfiguration("Validation failed; reverting…")
                }
            } else if (root.displaySavePhase === "reverting") {
                root.displaySavePhase = "idle"
                root.previousOutputConfiguration = ""
                root.displayStatus = exitCode === 0
                    ? "Previous display settings restored"
                    : "Could not validate the restored display settings"
                displayRefreshAfterRevert.restart()
            }
        }
    }

    Timer {
        id: displayConfirmationTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.displayConfirmationSeconds--
            if (root.displayConfirmationSeconds <= 0)
                root.revertDisplayConfiguration("Timed out; reverting…")
        }
    }

    Timer {
        id: displayRefreshAfterRevert
        interval: 600
        onTriggered: {
            root.previousDisplays = []
            root.refreshDisplays()
        }
    }

    FileView {
        id: outputsFile
        path: root.settings.configRoot + "/niri/mori/outputs.kdl"
        blockLoading: true
        printErrors: false
        atomicWrites: true
        watchChanges: true
        onSaved: configValidation.exec([
            "niri", "validate", "-c",
            root.settings.configRoot + "/niri/config.kdl"
        ])
        onSaveFailed: error => {
            root.displaySavePhase = "idle"
            root.awaitingDisplayConfirmation = false
            root.previousOutputConfiguration = ""
            root.previousDisplays = []
            root.displayStatus = ""
            root.displayError = "Could not write outputs.kdl: "
                + FileViewError.toString(error)
        }
    }

    Component {
        id: moduleSettingDelegate

        Rectangle {
            id: moduleRow
            required property string modelData
            required property int index
            readonly property string moduleKey: modelData
            readonly property string moduleSide: root.settings.moduleSide(moduleKey)
            readonly property int modelIndex: index
            readonly property bool moduleEnabled: {
                const currentRevision = root.settings.revision
                return root.settings.moduleEnabled(moduleKey)
            }
            readonly property bool supportsCompact: ["network", "volume", "brightness"]
                .indexOf(moduleKey) >= 0
            readonly property bool moduleCompact: {
                const currentRevision = root.settings.revision
                return root.settings.compactMode(moduleKey)
            }

            width: parent ? parent.width : 0
            height: 38
            opacity: root.draggingModule === moduleKey ? 0 : 1
            color: hoverHandler.hovered ? Theme.bg2 : "transparent"

            transform: Translate {
                y: root.modulePreviewOffset(
                    moduleRow.moduleSide, moduleRow.modelIndex, moduleRow.moduleKey)
                Behavior on y {
                    NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: 80 }
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text {
                    text: "≡"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.headingFontSize + 2
                    DragHandler {
                        id: dragHandler
                        target: null
                        onActiveChanged: {
                            if (active) root.beginDrag(moduleRow)
                            else root.finishDrag()
                        }
                        onTranslationChanged: if (active) root.updateDrag(translation.y)
                    }
                }

                Text {
                    text: root.moduleLabel(moduleRow.moduleKey)
                    color: moduleRow.moduleEnabled ? Theme.fg : Theme.grey1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    TapHandler {
                        onTapped: root.settings.setModuleEnabled(
                            moduleRow.moduleKey, !moduleRow.moduleEnabled)
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Rectangle {
                    visible: moduleRow.supportsCompact
                    width: visible ? 88 : 0
                    height: 22
                    color: moduleRow.moduleCompact ? Theme.bg3 : Theme.bg1
                    border.width: 1
                    border.color: moduleRow.moduleCompact ? Theme.fg : Theme.bg4

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "Compact"
                            color: moduleRow.moduleCompact ? Theme.fg : Theme.grey1
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(10, Theme.fontSize - 1)
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            color: moduleRow.moduleCompact ? Theme.fg : "transparent"
                            border.width: 1
                            border.color: Theme.fg
                        }
                    }

                    TapHandler {
                        onTapped: root.settings.setCompactMode(
                            moduleRow.moduleKey, !moduleRow.moduleCompact)
                    }
                }

                Rectangle {
                    width: 36
                    height: 18
                    radius: 0
                    color: moduleRow.moduleEnabled ? Theme.fg : Theme.bg4
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 0
                        anchors.verticalCenter: parent.verticalCenter
                        x: moduleRow.moduleEnabled ? parent.width - width - 3 : 3
                        color: moduleRow.moduleEnabled ? Theme.bg : Theme.grey1
                        Behavior on x {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }
                    TapHandler {
                        onTapped: root.settings.setModuleEnabled(
                            moduleRow.moduleKey, !moduleRow.moduleEnabled)
                    }
                }
            }

            HoverHandler { id: hoverHandler }
            DropArea {
                anchors.fill: parent
                keys: ["mori-module"]
                onEntered: drag => root.setDropTarget(
                    moduleRow.moduleSide,
                    moduleRow.modelIndex + (drag.y >= height / 2 ? 1 : 0))
                onPositionChanged: drag => root.setDropTarget(
                    moduleRow.moduleSide,
                    moduleRow.modelIndex + (drag.y >= height / 2 ? 1 : 0))
            }
        }
    }

    PanelWindow {
        id: settingsWindow
        screen: root.targetScreen || root.panelWindow.screen
        anchors { top: true; bottom: true; left: true; right: true }
        visible: false
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        onVisibleChanged: if (!visible) root.popupCoordinator.hidePopup(root)

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        FocusScope {
            anchors.fill: parent
            focus: settingsWindow.visible
            Keys.onEscapePressed: event => {
                if (root.page !== "home") root.page = "home"
                else root.close()
                event.accepted = true
            }
        }

        Rectangle {
            id: settingsCard
            anchors.centerIn: parent
            width: Math.min(600, settingsWindow.width - 48)
            height: Math.min(650, settingsWindow.height - 48)
            color: Theme.bg
            border.width: 2
            border.color: Theme.fg

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => mouse.accepted = true
            }

            Row {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 18
                height: 28
                spacing: 10

                Text {
                    visible: root.page !== "home"
                    text: "‹"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 24
                    width: visible ? 20 : 0
                    TapHandler { onTapped: root.page = "home" }
                }
                Text {
                    text: root.pageTitle()
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.headingFontSize + 2
                    font.weight: Font.DemiBold
                }
            }

            Text {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 18
                text: "×"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 22
                TapHandler { onTapped: root.close() }
            }

            Rectangle {
                id: headerDivider
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                anchors.topMargin: 8
                height: 1
                color: Theme.fg
            }

            Item {
                id: pageArea
                anchors.top: headerDivider.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 18
                anchors.topMargin: 12

                Column {
                    visible: root.page === "home"
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Choose a category"
                        color: Theme.grey1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    Repeater {
                        model: [
                            { "key": "modules", "label": "Modules", "description": "Visibility and bar order" },
                            { "key": "appearance", "label": "Appearance", "description": "Module accent colors" },
                            { "key": "displays", "label": "Displays", "description": "Connected Niri outputs" },
                            { "key": "about", "label": "About", "description": "Mori shell information" }
                        ]
                        delegate: Rectangle {
                            id: categoryRow
                            required property var modelData
                            width: parent.width
                            height: 62
                            color: categoryHover.hovered ? Theme.bg2 : Theme.bg1
                            border.width: 1
                            border.color: categoryHover.hovered ? Theme.fg : Theme.bg4
                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3
                                Text {
                                    text: categoryRow.modelData.label
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.headingFontSize
                                }
                                Text {
                                    text: categoryRow.modelData.description
                                    color: Theme.grey1
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 24
                            }
                            HoverHandler { id: categoryHover }
                            TapHandler { onTapped: root.openPage(categoryRow.modelData.key) }
                        }
                    }
                }

                Flickable {
                    id: modulesFlick
                    anchors.fill: parent
                    visible: root.page === "modules"
                    clip: true
                    contentWidth: width
                    contentHeight: modulesColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: modulesColumn
                        width: modulesFlick.width
                        spacing: 8
                        Text {
                            text: "Drag ≡ to reorder or move a module between anchors."
                            color: Theme.grey1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        Repeater {
                            model: ["left", "center", "right"]
                            delegate: Rectangle {
                                id: anchorBox
                                required property string modelData
                                readonly property string anchorKey: modelData
                                readonly property var anchorOrder: anchorKey === "left"
                                    ? root.settings.leftModuleOrder
                                    : anchorKey === "center"
                                        ? root.settings.centerModuleOrder
                                        : root.settings.rightModuleOrder
                                width: parent.width
                                height: anchorColumn.implicitHeight + 16
                                    + root.anchorHeightAdjustment(anchorKey)
                                color: Theme.bg1
                                border.width: root.draggingModule.length > 0
                                    && root.dropSide === anchorKey ? 2 : 1
                                border.color: root.draggingModule.length > 0
                                    && root.dropSide === anchorKey ? Theme.fg : Theme.bg4

                                Behavior on height {
                                    NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                                }

                                Column {
                                    id: anchorColumn
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 8
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: anchorBox.anchorKey === "left" ? "Left"
                                            : anchorBox.anchorKey === "center" ? "Center"
                                            : "Right"
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        font.weight: Font.DemiBold
                                        DropArea {
                                            anchors.fill: parent
                                            keys: ["mori-module"]
                                            onEntered: root.setDropTarget(
                                                anchorBox.anchorKey, 0)
                                        }
                                    }

                                    Repeater {
                                        model: anchorBox.anchorOrder
                                        delegate: moduleSettingDelegate
                                    }

                                    Item {
                                        width: parent.width
                                        height: 8
                                        DropArea {
                                            anchors.fill: parent
                                            keys: ["mori-module"]
                                            onEntered: root.setDropTarget(
                                                anchorBox.anchorKey,
                                                anchorBox.anchorOrder.length)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Flickable {
                    id: appearanceFlick
                    anchors.fill: parent
                    visible: root.page === "appearance"
                    clip: true
                    contentWidth: width
                    contentHeight: appearanceColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: appearanceColumn
                        width: appearanceFlick.width
                        spacing: 6
                        Text {
                            text: "Module accents"
                            color: Theme.grey1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        Repeater {
                            model: root.allModules
                            delegate: Rectangle {
                                id: colorRow
                                required property string modelData
                                readonly property string moduleKey: modelData
                                width: parent.width
                                height: 48
                                color: colorHover.hovered ? Theme.bg2 : "transparent"
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.moduleLabel(colorRow.moduleKey)
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }
                                Row {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 7
                                    Repeater {
                                        model: root.colorChoices
                                        delegate: Rectangle {
                                            id: swatch
                                            required property var modelData
                                            readonly property bool selected: {
                                                const currentRevision = root.settings.revision
                                                return root.settings.moduleColors[colorRow.moduleKey]
                                                    === modelData.token
                                            }
                                            width: 24
                                            height: 24
                                            color: modelData.color
                                            border.width: selected ? 3 : 1
                                            border.color: selected ? Theme.fg : Theme.bg4
                                            TapHandler {
                                                onTapped: root.settings.setModuleColor(
                                                    colorRow.moduleKey, swatch.modelData.token)
                                            }
                                        }
                                    }
                                }
                                HoverHandler { id: colorHover }
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: root.page === "displays"

                    Column {
                        id: displaysColumn
                        anchors.fill: parent
                        spacing: 10

                        Row {
                            spacing: 10

                            Rectangle {
                                width: refreshLabel.implicitWidth + 20
                                height: 30
                                color: refreshHover.hovered ? Theme.bg2 : Theme.bg1
                                border.width: 1
                                border.color: Theme.fg
                                Text {
                                    id: refreshLabel
                                    anchors.centerIn: parent
                                    text: displayQuery.running ? "Refreshing…" : "Refresh"
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }
                                HoverHandler { id: refreshHover }
                                TapHandler {
                                    enabled: !displayQuery.running
                                    onTapped: root.refreshDisplays()
                                }
                            }

                            Rectangle {
                                width: saveLabel.implicitWidth + 20
                                height: 30
                                color: saveHover.hovered ? Theme.bg2 : Theme.bg1
                                border.width: 1
                                border.color: Theme.fg
                                Text {
                                    id: saveLabel
                                    anchors.centerIn: parent
                                    text: "Save displays"
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }
                                HoverHandler { id: saveHover }
                                TapHandler {
                                    enabled: root.displays.length > 0
                                        && root.displaySavePhase === "idle"
                                        && !root.awaitingDisplayConfirmation
                                    onTapped: root.saveDisplayLayout()
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.displayError.length > 0
                                    ? root.displayError : root.displayStatus
                                color: root.displayError.length > 0 ? Theme.red : Theme.grey1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                        }

                        Text {
                            text: "Drag displays to arrange them. Nearby edges snap together."
                            color: Theme.grey1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        Row {
                            spacing: 8
                            Repeater {
                                model: root.displays
                                delegate: Rectangle {
                                    id: displaySelector
                                    required property var modelData
                                    width: selectorLabel.implicitWidth + 18
                                    height: 26
                                    color: root.selectedDisplay === modelData.connector
                                        ? Theme.bg3 : Theme.bg1
                                    border.width: 1
                                    border.color: Theme.fg
                                    opacity: modelData.enabled ? 1 : 0.6
                                    Text {
                                        id: selectorLabel
                                        anchors.centerIn: parent
                                        text: displaySelector.modelData.connector
                                            + (displaySelector.modelData.enabled ? "" : " · off")
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                    }
                                    TapHandler {
                                        onTapped: root.selectedDisplay
                                            = displaySelector.modelData.connector
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: displayCanvas
                            width: parent.width
                            height: Math.max(110, pageArea.height - 360)
                            color: Theme.bgdim
                            border.width: 1
                            border.color: Theme.bg4
                            clip: true
                            onWidthChanged: Qt.callLater(root.fitDisplayLayout)
                            onHeightChanged: Qt.callLater(root.fitDisplayLayout)

                            Repeater {
                                model: root.displays

                                delegate: Rectangle {
                                    id: displayTile
                                    required property var modelData
                                    property real dragOffsetX: 0
                                    property real dragOffsetY: 0
                                    property real dragStartLogicalX: 0
                                    property real dragStartLogicalY: 0

                                    x: root.displayCanvasX(modelData) + dragOffsetX
                                    y: root.displayCanvasY(modelData) + dragOffsetY
                                    width: Math.max(54, modelData.width * root.displayViewScale)
                                    height: Math.max(42, modelData.height * root.displayViewScale)
                                    z: displayDrag.active ? 10 : 1
                                    color: root.selectedDisplay === modelData.connector
                                        ? Theme.bg3 : Theme.bg1
                                    opacity: modelData.enabled ? 1 : 0.55
                                    border.width: root.selectedDisplay === modelData.connector ? 2 : 1
                                    border.color: Theme.fg

                                    Column {
                                        anchors.centerIn: parent
                                        width: parent.width - 10
                                        spacing: 2
                                        Text {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            text: displayTile.modelData.connector
                                            color: Theme.fg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            text: Math.round(displayTile.modelData.x) + ", "
                                                + Math.round(displayTile.modelData.y)
                                                + (displayTile.modelData.enabled ? "" : "  ·  OFF")
                                            color: Theme.grey1
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Math.max(9, Theme.fontSize - 2)
                                        }
                                    }

                                    HoverHandler { id: displayHover }
                                    TapHandler {
                                        onTapped: root.selectedDisplay = displayTile.modelData.connector
                                    }
                                    DragHandler {
                                        id: displayDrag
                                        target: null
                                        onActiveChanged: {
                                            if (active) {
                                                root.selectedDisplay = displayTile.modelData.connector
                                                displayTile.dragStartLogicalX = displayTile.modelData.x
                                                displayTile.dragStartLogicalY = displayTile.modelData.y
                                            } else {
                                                const newX = displayTile.dragStartLogicalX
                                                    + displayTile.dragOffsetX / root.displayViewScale
                                                const newY = displayTile.dragStartLogicalY
                                                    + displayTile.dragOffsetY / root.displayViewScale
                                                displayTile.dragOffsetX = 0
                                                displayTile.dragOffsetY = 0
                                                Qt.callLater(() => root.updateDisplayPosition(
                                                    displayTile.modelData.connector, newX, newY))
                                            }
                                        }
                                        onTranslationChanged: {
                                            if (active) {
                                                displayTile.dragOffsetX = translation.x
                                                displayTile.dragOffsetY = translation.y
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: displayEditor
                            width: parent.width
                            height: 180
                            color: Theme.bg1
                            border.width: 1
                            border.color: Theme.bg4

                            readonly property var output: root.selectedDisplayData()

                            Rectangle {
                                id: displayEnabledButton
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 10
                                width: displayEnabledLabel.implicitWidth + 18
                                height: 26
                                color: displayEnabledHover.hovered ? Theme.bg2 : Theme.bgdim
                                border.width: 1
                                border.color: Theme.fg
                                opacity: displayEditor.output
                                    && (displayEditor.output.enabled
                                        ? root.enabledDisplayCount() > 1 : true) ? 1 : 0.45

                                Text {
                                    id: displayEnabledLabel
                                    anchors.centerIn: parent
                                    text: displayEditor.output && displayEditor.output.enabled
                                        ? "Disable" : "Enable"
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }
                                HoverHandler { id: displayEnabledHover }
                                TapHandler {
                                    enabled: displayEditor.output
                                        && (!displayEditor.output.enabled
                                            || root.enabledDisplayCount() > 1)
                                    onTapped: root.setSelectedDisplayEnabled(
                                        !displayEditor.output.enabled)
                                }
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 12
                                spacing: 6

                                Text {
                                    text: displayEditor.output
                                        ? displayEditor.output.label + "  ("
                                            + displayEditor.output.connector + ")"
                                        : "No display selected"
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    font.weight: Font.DemiBold
                                }

                                Row {
                                    spacing: 8
                                    Text {
                                        width: 76
                                        text: "Resolution"
                                        color: Theme.grey1
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                    }
                                    Text {
                                        text: "‹"
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.headingFontSize
                                        TapHandler { onTapped: root.cycleSelectedResolution(-1) }
                                    }
                                    Text {
                                        width: 220
                                        text: displayEditor.output
                                            ? displayEditor.output.modeWidth + "×"
                                                + displayEditor.output.modeHeight
                                            : "—"
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Text {
                                        text: "›"
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.headingFontSize
                                        TapHandler { onTapped: root.cycleSelectedResolution(1) }
                                    }
                                }

                                Row {
                                    spacing: 8
                                    Text {
                                        width: 76
                                        text: "Refresh"
                                        color: Theme.grey1
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                    }
                                    Text {
                                        text: "‹"
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.headingFontSize
                                        TapHandler { onTapped: root.cycleSelectedRefreshRate(-1) }
                                    }
                                    Text {
                                        width: 220
                                        text: displayEditor.output
                                            ? (displayEditor.output.refreshRate / 1000)
                                                .toFixed(2) + " Hz"
                                            : "—"
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Text {
                                        text: "›"
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.headingFontSize
                                        TapHandler { onTapped: root.cycleSelectedRefreshRate(1) }
                                    }
                                }

                                Row {
                                    spacing: 8
                                    Text {
                                        width: 76
                                        text: "Scale"
                                        color: Theme.grey1
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                    }
                                    Text {
                                        text: "−"
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.headingFontSize
                                        TapHandler { onTapped: root.adjustSelectedScale(-0.25) }
                                    }
                                    Text {
                                        width: 220
                                        text: displayEditor.output
                                            ? displayEditor.output.scale.toFixed(2) + "×" : "—"
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Text {
                                        text: "+"
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.headingFontSize
                                        TapHandler { onTapped: root.adjustSelectedScale(0.25) }
                                    }
                                }

                                Row {
                                    spacing: 8
                                    Text {
                                        width: 76
                                        text: "Transform"
                                        color: Theme.grey1
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                    }
                                    Text {
                                        text: "‹"
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.headingFontSize
                                        TapHandler { onTapped: root.cycleSelectedTransform(-1) }
                                    }
                                    Text {
                                        width: 220
                                        text: displayEditor.output
                                            ? displayEditor.output.transform : "—"
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Text {
                                        text: "›"
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.headingFontSize
                                        TapHandler { onTapped: root.cycleSelectedTransform(1) }
                                    }
                                }

                                Text {
                                    text: displayEditor.output
                                        ? "Position  " + Math.round(displayEditor.output.x) + ", "
                                            + Math.round(displayEditor.output.y) : ""
                                    color: Theme.grey1
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Math.max(10, Theme.fontSize - 1)
                                }
                            }
                        }

                        Text {
                            text: "Save writes enabled state, position, mode, scale, and transform; other output settings and comments are preserved."
                            width: parent.width
                            wrapMode: Text.WordWrap
                            color: Theme.grey1
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(10, Theme.fontSize - 1)
                        }
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    width: Math.min(440, parent.width - 36)
                    height: 66
                    z: 100
                    visible: root.awaitingDisplayConfirmation
                    color: Theme.bg1
                    border.width: 2
                    border.color: Theme.fg

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Keep display settings?  "
                            + root.displayConfirmationSeconds + "s"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            width: keepLabel.implicitWidth + 18
                            height: 30
                            color: keepHover.hovered ? Theme.bg3 : Theme.bg2
                            border.width: 1
                            border.color: Theme.fg
                            Text {
                                id: keepLabel
                                anchors.centerIn: parent
                                text: "Keep"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            HoverHandler { id: keepHover }
                            TapHandler { onTapped: root.keepDisplayConfiguration() }
                        }

                        Rectangle {
                            width: revertLabel.implicitWidth + 18
                            height: 30
                            color: revertHover.hovered ? Theme.bg3 : Theme.bg2
                            border.width: 1
                            border.color: Theme.fg
                            Text {
                                id: revertLabel
                                anchors.centerIn: parent
                                text: "Revert"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            HoverHandler { id: revertHover }
                            TapHandler {
                                onTapped: root.revertDisplayConfiguration(
                                    "Reverting display settings…")
                            }
                        }
                    }
                }

                Column {
                    visible: root.page === "about"
                    width: parent.width
                    spacing: 12
                    Text {
                        text: "Mori 森"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.headingFontSize + 4
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "A personal Quickshell configuration built around Niri and the Everforest palette."
                        color: Theme.grey1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    Text {
                        text: "Settings are saved to ~/.config/quickshell/mori-settings.json"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }
            }

            Rectangle {
                id: dragGhost
                x: 18
                y: root.dragY
                z: 100
                width: settingsCard.width - 36
                height: 38
                visible: root.draggingModule.length > 0
                color: Theme.bg3
                border.width: 2
                border.color: Theme.fg
                opacity: 0.96
                Drag.active: visible
                Drag.source: dragGhost
                Drag.keys: ["mori-module"]
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.moduleLabel(root.draggingModule)
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "≡"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.headingFontSize + 2
                }
            }
        }
    }
}
