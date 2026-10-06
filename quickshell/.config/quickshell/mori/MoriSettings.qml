import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./theme"
import "PowerCommands.js" as PowerCommands

Item {
    id: root
    // Page controls exist only while that page is open. Saving and rollback
    // state stays in this controller when a page or the window closes.
    readonly property var modulesFlick: modulesPage.item
    readonly property var anchorRepeater: modulesPage.item ? modulesPage.item.anchorRows : null
    readonly property var appearanceFlick: appearancePage.item
    readonly property var colorRows: appearancePage.item ? appearancePage.item.rows : null
    readonly property var powerFlick: powerPage.item
    readonly property var powerRows: powerPage.item ? powerPage.item.rows : null
    readonly property var inputRows: inputPage.item ? inputPage.item.rows : null
    readonly property var displayCanvas: displaysPage.item ? displaysPage.item.canvas : null

    required property var panelWindow
    required property var popupCoordinator
    required property var settings

    width: 0
    height: 0

    property string page: "home"
    onPageChanged: {
        if (page !== "input" && editingKeyboardLayout)
            keyboardScope.forceActiveFocus()
        if (page !== "power" && editingPowerCommand)
            keyboardScope.forceActiveFocus()
    }
    property int keyboardCategoryIndex: 0
    property string keyboardModule: ""
    property int keyboardColorRow: 0
    property int keyboardColorIndex: 0
    property int keyboardClockIndex: 0
    property int keyboardPowerIndex: 0
    property bool editingPowerCommand: false
    property var powerDrafts: ({})
    property var powerErrors: ({})
    property string powerBaseline: ""
    property bool powerDirty: false
    property string powerStatus: ""
    readonly property bool powerDraftsValid: powerOptions.every(option => !powerErrors[option.key])
    property string keyboardDisplaySection: "outputs"
    property int keyboardDisplayField: 0
    property int keyboardConfirmationIndex: 0
    property int keyboardInputIndex: 0
    property string keyboardLayout: ""
    property string keyboardLayoutDraft: ""
    property bool editingKeyboardLayout: false
    property real mouseSpeed: 0
    property real touchpadSpeed: 0
    property bool touchpadTap: false
    property bool touchpadNaturalScroll: false
    property bool touchpadDwt: false
    property string inputContents: ""
    property string inputError: ""
    property string inputStatus: ""
    property int inputRevision: 0
    property bool inputWritePending: false
    property bool inputDirty: false
    property bool inputApplyPending: false
    property bool inputRestoring: false
    property string inputBaselineContents: ""
    property bool closeAfterApply: false
    readonly property bool inputPendingChanges: inputDirty
        || keyboardLayoutDraft !== keyboardLayout
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
    property bool displayDirty: false
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
        "battery", "brightness", "calendar", "kdeConnect", "media", "network",
        "notifications", "powerMenu", "systemTray", "volume", "wallpaper", "workspaces"
    ]
    readonly property var categoryPages: ["modules", "appearance", "clock", "power", "displays", "input", "about"]
    readonly property var powerOptions: [
        { key: "suspend", label: "Suspend" },
        { key: "reboot", label: "Restart" },
        { key: "poweroff", label: "Power off" }
    ]
    readonly property var clockOptions: [
        { "key": "timeFormat", "label": "Time", "values": ["24h", "12h"],
            "labels": ["24-hour", "12-hour AM/PM"] },
        { "key": "showSeconds", "label": "Seconds", "values": [false, true],
            "labels": ["Off", "On"] },
        { "key": "dateFormat", "label": "Date order",
            "values": ["yyyy/MM/dd", "dd/MM/yyyy", "MM/dd/yyyy"],
            "labels": ["YYYY/MM/DD", "DD/MM/YYYY", "MM/DD/YYYY"] }
    ]
    readonly property var inputOptions: [
        { "key": "keyboardLayout", "label": "Keyboard layout", "device": "xkb",
            "setting": "layout", "kind": "layout" },
        { "key": "mouseSpeed", "label": "Mouse sensitivity", "device": "mouse",
            "setting": "accel-speed", "kind": "speed" },
        { "key": "touchpadSpeed", "label": "Touchpad sensitivity", "device": "touchpad",
            "setting": "accel-speed", "kind": "speed" },
        { "key": "touchpadTap", "label": "Tap to click", "device": "touchpad",
            "setting": "tap", "kind": "flag" },
        { "key": "touchpadNaturalScroll", "label": "Natural scrolling",
            "device": "touchpad", "setting": "natural-scroll", "kind": "flag" },
        { "key": "touchpadDwt", "label": "Disable while typing",
            "device": "touchpad", "setting": "dwt", "kind": "flag" }
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
        case "clock": return "Time & date"
        case "power": return "Power menu"
        case "displays": return "Displays"
        case "input": return "Input"
        case "about": return "About"
        default: return "Mori settings"
        }
    }

    function toggle() {
        if (settingsWindow.visible) {
            close()
        } else {
            if (closeAfterApply) {
                closeAfterApply = false
                settingsWindow.visible = true
                return
            }
            page = "home"
            keyboardCategoryIndex = 0
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
        if (awaitingDisplayConfirmation || displaySavePhase !== "idle")
            return
        if (inputApplyPending || inputRestoring) {
            // Let the menu dismiss immediately, but preserve the edit session
            // until the in-flight save/validation reports its result.
            closeAfterApply = true
            settingsWindow.visible = false
            return
        }
        finishClose()
    }

    function finishClose() {
        closeAfterApply = false
        inputDirty = false
        powerDirty = false
        powerStatus = ""
        inputWritePending = false
        keyboardLayoutDraft = keyboardLayout
        displayDirty = false
        displayError = ""
        displayStatus = ""
        draggingModule = ""
        dragSourceSide = ""
        dragSourceIndex = -1
        dropSide = ""
        dropIndex = -1
        settingsWindow.visible = false
    }

    function finishDeferredClose() {
        if (closeAfterApply && !inputApplyPending && !inputRestoring
                && !awaitingDisplayConfirmation && displaySavePhase === "idle")
            finishClose()
    }

    function stageKeyboardLayout() {
        const option = inputOptions[0]
        if (!setInputValue(option, keyboardLayoutDraft)) {
            page = "input"
            inputStatus = "Check keyboard layout"
            return false
        }
        keyboardLayoutDraft = keyboardLayout
        const editor = keyboardLayoutEditor()
        if (editor)
            editor.text = keyboardLayout
        keyboardScope.forceActiveFocus()
        return true
    }

    function keyboardLayoutEditor() {
        const row = inputRows ? inputRows.itemAt(0) : null
        return row ? row.editor : null
    }

    function applyInput() {
        if (inputApplyPending || inputRestoring) return
        if (keyboardLayoutDraft !== keyboardLayout && !stageKeyboardLayout())
            return
        if (!inputDirty) return
        inputApplyPending = true
        inputWritePending = true
        inputStatus = "Applying input settings…"
        inputFile.setText(inputContents)
    }

    function applyCurrentPage() {
        if (page === "input") applyInput()
        else if (page === "power") applyPowerCommands()
        else if (page === "displays" && displayDirty) saveDisplayLayout()
    }

    function openPage(name) {
        page = name
        if (name === "modules") {
            keyboardModule = orderedModules()[0] || ""
            Qt.callLater(scrollToKeyboardModule)
        } else if (name === "appearance") {
            keyboardColorRow = 0
            syncKeyboardColor()
        } else if (name === "clock") {
            keyboardClockIndex = 0
        } else if (name === "power") {
            keyboardPowerIndex = 0
            loadPowerDrafts()
        } else if (name === "displays") {
            keyboardDisplaySection = "outputs"
            keyboardDisplayField = 0
            if (!displayDirty)
                refreshDisplays()
        } else if (name === "input") {
            keyboardInputIndex = 0
            loadInputSettings()
        }
    }

    function loadPowerDrafts() {
        const stored = settings.powerCommands
        const validObject = stored && typeof stored === "object" && !Array.isArray(stored)
        const drafts = {}
        const errors = {}
        for (const option of powerOptions) {
            const name = option.key
            if (validObject && Object.prototype.hasOwnProperty.call(stored, name)) {
                if (PowerCommands.valid(stored[name])) {
                    drafts[name] = PowerCommands.format(stored[name])
                } else {
                    drafts[name] = JSON.stringify(stored[name]) || ""
                    errors[name] = "Replace the invalid saved command or choose Use automatic."
                }
            } else {
                drafts[name] = ""
            }
        }
        powerDrafts = drafts
        powerErrors = errors
        powerBaseline = JSON.stringify(drafts)
        powerDirty = !validObject
        powerStatus = validObject ? "" : "Invalid saved power settings"
    }

    function setPowerDraft(name, text) {
        powerDrafts = Object.assign({}, powerDrafts, { [name]: text })
        const errors = Object.assign({}, powerErrors)
        try {
            PowerCommands.parse(text)
            delete errors[name]
        } catch (error) {
            errors[name] = error.message
        }
        powerErrors = errors
        const stored = settings.powerCommands
        powerDirty = JSON.stringify(powerDrafts) !== powerBaseline
            || !stored || typeof stored !== "object" || Array.isArray(stored)
        powerStatus = ""
    }

    function applyPowerCommands() {
        if (!powerDirty || !powerDraftsValid)
            return
        const stored = settings.powerCommands
        const commands = stored && typeof stored === "object" && !Array.isArray(stored)
            ? Object.assign({}, stored) : {}
        for (const option of powerOptions) {
            const args = PowerCommands.parse(powerDrafts[option.key] || "")
            if (args.length > 0) commands[option.key] = args
            else delete commands[option.key]
        }
        if (settings.setPowerCommands(commands)) {
            loadPowerDrafts()
            powerStatus = settings.saveError ? "Not saved" : "Saved"
            keyboardScope.forceActiveFocus()
        }
    }

    function clockOptionValue(key) {
        if (key === "timeFormat") return settings.clockTimeFormat
        if (key === "showSeconds") return settings.clockShowSeconds
        return settings.clockDateFormat
    }

    function cycleClockOption(offset) {
        const option = clockOptions[keyboardClockIndex]
        const index = option.values.indexOf(clockOptionValue(option.key))
        const next = (index + offset + option.values.length) % option.values.length
        settings.setClockOption(option.key, option.values[next])
    }

    function clockPreview() {
        const sample = new Date(2026, 9, 3, 17, 8, 9)
        const timeFormat = settings.clockTimeFormat === "12h"
            ? (settings.clockShowSeconds ? "h:mm:ss AP" : "h:mm AP")
            : (settings.clockShowSeconds ? "HH:mm:ss" : "HH:mm")
        return "[ " + Qt.formatDate(sample, settings.clockDateFormat)
            + "   " + Qt.formatTime(sample, timeFormat) + " ]"
    }

    function inputBlock(lines, device) {
        let start = -1
        for (let i = 0; i < lines.length; ++i) {
            if (new RegExp("^\\s*" + device + "\\s*\\{\\s*$").test(lines[i])) {
                start = i
                break
            }
        }
        if (start < 0) return null
        let depth = 0
        for (let i = start; i < lines.length; ++i) {
            const code = lines[i].replace(/\/\/.*$/, "")
            depth += (code.match(/\{/g) || []).length
            depth -= (code.match(/\}/g) || []).length
            if (depth === 0) return { "start": start, "end": i }
        }
        return null
    }

    function readInputValue(lines, device, setting, kind) {
        const block = inputBlock(lines, device)
        if (!block) return kind === "speed" ? 0 : kind === "layout" ? "" : false
        const pattern = new RegExp("^\\s*" + setting + "(?:\\s+([^\\s/]+))?(?:\\s*//.*)?$")
        for (let i = block.start + 1; i < block.end; ++i) {
            const match = lines[i].match(pattern)
            if (match) {
                if (kind === "speed") return Number(match[1])
                if (kind === "layout") {
                    try { return JSON.parse(match[1]) }
                    catch (error) { return "" }
                }
                return true
            }
        }
        return kind === "speed" ? 0 : kind === "layout" ? "" : false
    }

    function loadInputSettings() {
        const preserveDraft = keyboardLayoutDraft !== keyboardLayout && inputContents.length > 0
        const draft = keyboardLayoutDraft
        if (!inputWritePending && !inputDirty) {
            inputContents = inputFile.text()
            inputBaselineContents = inputContents
        }
        const lines = inputContents.split(/\r?\n/)
        if (!inputBlock(lines, "xkb") || !inputBlock(lines, "mouse")
                || !inputBlock(lines, "touchpad")) {
            inputError = "Could not read keyboard, mouse, and touchpad sections in input.kdl"
            return
        }
        keyboardLayout = readInputValue(lines, "xkb", "layout", "layout")
        keyboardLayoutDraft = preserveDraft ? draft : keyboardLayout
        const editor = keyboardLayoutEditor()
        if (editor)
            editor.text = keyboardLayoutDraft
        mouseSpeed = readInputValue(lines, "mouse", "accel-speed", "speed")
        touchpadSpeed = readInputValue(lines, "touchpad", "accel-speed", "speed")
        touchpadTap = readInputValue(lines, "touchpad", "tap", "flag")
        touchpadNaturalScroll = readInputValue(lines, "touchpad", "natural-scroll", "flag")
        touchpadDwt = readInputValue(lines, "touchpad", "dwt", "flag")
        inputError = ""
        inputStatus = ""
        inputRevision++
    }

    function inputValue(key) { return root[key] }

    function setInputValue(option, value) {
        if (inputApplyPending)
            return false
        const lines = inputContents.split(/\r?\n/)
        const block = inputBlock(lines, option.device)
        if (!block) {
            inputError = "Could not update " + option.device + " in input.kdl"
            return false
        }
        const pattern = new RegExp("^\\s*" + option.setting + "(?:\\s+.*)?$")
        const normalized = option.kind === "speed"
            ? Math.max(-1, Math.min(1, Math.round(value * 20) / 20))
            : option.kind === "layout" ? String(value).trim() : !!value
        if (option.kind === "layout" && normalized.length > 0
                && !/^[A-Za-z0-9_-]+(?:,[A-Za-z0-9_-]+)*$/.test(normalized)) {
            inputError = "Use layout names such as us or us,sk"
            return false
        }
        let lineIndex = -1
        for (let i = block.start + 1; i < block.end; ++i) {
            if (pattern.test(lines[i])) {
                lineIndex = i
                break
            }
        }
        const indentation = (lines[block.start].match(/^\s*/) || [""])[0] + "    "
        const replacement = indentation + option.setting
            + (option.kind === "speed" ? " " + normalized.toFixed(2)
                : option.kind === "layout" ? " " + JSON.stringify(normalized) : "")
        if ((option.kind === "flag" && !normalized)
                || (option.kind === "layout" && normalized.length === 0)) {
            if (lineIndex >= 0) lines.splice(lineIndex, 1)
        } else if (lineIndex >= 0)
            lines[lineIndex] = replacement
        else
            lines.splice(block.end, 0, replacement)
        inputContents = lines.join("\n")
        root[option.key] = normalized
        inputRevision++
        inputError = ""
        inputStatus = "Input changes pending Apply"
        inputDirty = true
        return true
    }

    function orderedModules() {
        return settings.leftModuleOrder.concat(settings.centerModuleOrder,
            settings.rightModuleOrder)
    }

    function scrollIntoView(flick, item) {
        if (!flick || !item) return
        const y = item.mapToItem(flick.contentItem, 0, 0).y
        if (y < flick.contentY)
            flick.contentY = y
        else if (y + item.height > flick.contentY + flick.height)
            flick.contentY = y + item.height - flick.height
    }

    function scrollToKeyboardModule() {
        if (!anchorRepeater) return
        for (let i = 0; i < anchorRepeater.count; ++i) {
            const anchor = anchorRepeater.itemAt(i)
            if (!anchor) continue
            const index = anchor.anchorOrder.indexOf(keyboardModule)
            if (index >= 0) {
                scrollIntoView(modulesFlick, anchor.rowRepeater.itemAt(index))
                return
            }
        }
    }

    function moveKeyboardModule(offset) {
        const modules = orderedModules()
        if (modules.length === 0) return
        const index = Math.max(0, modules.indexOf(keyboardModule))
        keyboardModule = modules[Math.max(0, Math.min(modules.length - 1, index + offset))]
        Qt.callLater(scrollToKeyboardModule)
    }

    function moveKeyboardModuleInAnchor(offset) {
        if (!keyboardModule) return
        const side = settings.moduleSide(keyboardModule)
        const order = side === "left" ? settings.leftModuleOrder
            : side === "center" ? settings.centerModuleOrder : settings.rightModuleOrder
        const index = order.indexOf(keyboardModule)
        if (index < 0 || index + offset < 0 || index + offset >= order.length) return
        settings.moveModuleTo(keyboardModule, side, index + (offset > 0 ? 2 : -1))
        Qt.callLater(scrollToKeyboardModule)
    }

    function moveKeyboardModuleToAnchor(offset) {
        if (!keyboardModule) return
        const anchors = ["left", "center", "right"]
        const index = anchors.indexOf(settings.moduleSide(keyboardModule))
        const targetIndex = index + offset
        if (targetIndex < 0 || targetIndex >= anchors.length) return
        const target = anchors[targetIndex]
        const order = target === "left" ? settings.leftModuleOrder
            : target === "center" ? settings.centerModuleOrder : settings.rightModuleOrder
        settings.moveModuleTo(keyboardModule, target, order.length)
        Qt.callLater(scrollToKeyboardModule)
    }

    function syncKeyboardColor() {
        const name = allModules[keyboardColorRow]
        const token = settings.moduleColors[name]
        const index = colorChoices.findIndex(choice => choice.token === token)
        keyboardColorIndex = Math.max(0, index)
    }

    function moveKeyboardColorRow(offset) {
        keyboardColorRow = Math.max(0, Math.min(allModules.length - 1,
            keyboardColorRow + offset))
        syncKeyboardColor()
        Qt.callLater(() => scrollIntoView(appearanceFlick,
            colorRows ? colorRows.itemAt(keyboardColorRow) : null))
    }

    function handleSettingsKey(event) {
        const key = event.key
        if (page === "power" && editingPowerCommand) {
            if ((event.modifiers & Qt.ControlModifier)
                    && (key === Qt.Key_Return || key === Qt.Key_Enter)) {
                applyPowerCommands()
                event.accepted = true
            } else if (key === Qt.Key_Escape) {
                keyboardScope.forceActiveFocus()
                event.accepted = true
            }
            return
        }
        if (page === "input" && editingKeyboardLayout) {
            if (key === Qt.Key_Escape) {
                keyboardScope.forceActiveFocus()
                event.accepted = true
            }
            return
        }
        if (event.isAutoRepeat && key !== Qt.Key_Up && key !== Qt.Key_Down
                && key !== Qt.Key_Left && key !== Qt.Key_Right)
            return
        if (awaitingDisplayConfirmation) {
            if (key === Qt.Key_Left || key === Qt.Key_Right || key === Qt.Key_Tab)
                keyboardConfirmationIndex = key === Qt.Key_Tab
                    ? 1 - keyboardConfirmationIndex : key === Qt.Key_Left ? 0 : 1
            else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
                if (keyboardConfirmationIndex === 0) keepDisplayConfiguration()
                else revertDisplayConfiguration("Reverting display settings…")
            } else if (key === Qt.Key_Escape)
                revertDisplayConfiguration("Reverting display settings…")
            else return
            event.accepted = true
            return
        }
        if (key === Qt.Key_Escape || key === Qt.Key_Backspace) {
            if (page !== "home") page = "home"
            else close()
            event.accepted = true
            return
        }
        if ((event.modifiers & Qt.ControlModifier)
                && (key === Qt.Key_Return || key === Qt.Key_Enter)) {
            if (page !== "input" && page !== "displays" && page !== "power") return
            applyCurrentPage()
            event.accepted = true
            return
        }
        if (page === "home") {
            if (key === Qt.Key_Up || key === Qt.Key_Down)
                keyboardCategoryIndex = Math.max(0, Math.min(categoryPages.length - 1,
                    keyboardCategoryIndex + (key === Qt.Key_Up ? -1 : 1)))
            else if (key === Qt.Key_Return || key === Qt.Key_Enter)
                openPage(categoryPages[keyboardCategoryIndex])
            else return
        } else if (page === "modules") {
            if (event.modifiers & Qt.ShiftModifier
                    && (key === Qt.Key_Up || key === Qt.Key_Down))
                moveKeyboardModuleInAnchor(key === Qt.Key_Up ? -1 : 1)
            else if (event.modifiers & Qt.ShiftModifier
                    && (key === Qt.Key_Left || key === Qt.Key_Right))
                moveKeyboardModuleToAnchor(key === Qt.Key_Left ? -1 : 1)
            else if (key === Qt.Key_Up || key === Qt.Key_Down)
                moveKeyboardModule(key === Qt.Key_Up ? -1 : 1)
            else if ((key === Qt.Key_Return || key === Qt.Key_Enter) && keyboardModule)
                settings.setModuleEnabled(keyboardModule,
                    !settings.moduleEnabled(keyboardModule))
            else if (key === Qt.Key_C && keyboardModule
                    && ["media", "network", "volume", "brightness"].indexOf(keyboardModule) >= 0)
                settings.setCompactMode(keyboardModule,
                    !settings.compactMode(keyboardModule))
            else return
        } else if (page === "appearance") {
            if (key === Qt.Key_Up || key === Qt.Key_Down)
                moveKeyboardColorRow(key === Qt.Key_Up ? -1 : 1)
            else if (key === Qt.Key_Left || key === Qt.Key_Right)
                keyboardColorIndex = Math.max(0, Math.min(colorChoices.length - 1,
                    keyboardColorIndex + (key === Qt.Key_Left ? -1 : 1)))
            else if (key === Qt.Key_Return || key === Qt.Key_Enter)
                settings.setModuleColor(allModules[keyboardColorRow],
                    colorChoices[keyboardColorIndex].token)
            else return
        } else if (page === "clock") {
            if (key === Qt.Key_Up || key === Qt.Key_Down)
                keyboardClockIndex = Math.max(0, Math.min(clockOptions.length - 1,
                    keyboardClockIndex + (key === Qt.Key_Up ? -1 : 1)))
            else if (key === Qt.Key_Left || key === Qt.Key_Right
                    || key === Qt.Key_Return || key === Qt.Key_Enter)
                cycleClockOption(key === Qt.Key_Left ? -1 : 1)
            else return
        } else if (page === "power") {
            if (key === Qt.Key_Up || key === Qt.Key_Down) {
                keyboardPowerIndex = Math.max(0, Math.min(powerOptions.length - 1,
                    keyboardPowerIndex + (key === Qt.Key_Up ? -1 : 1)))
                Qt.callLater(() => scrollIntoView(powerFlick, powerRows ? powerRows.itemAt(keyboardPowerIndex) : null))
            } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
                const row = powerRows ? powerRows.itemAt(keyboardPowerIndex) : null
                if (row) row.editor.forceActiveFocus()
            } else return
        } else if (page === "input") {
            if (key === Qt.Key_Up || key === Qt.Key_Down)
                keyboardInputIndex = Math.max(0, Math.min(inputOptions.length - 1,
                    keyboardInputIndex + (key === Qt.Key_Up ? -1 : 1)))
            else if (key === Qt.Key_Left || key === Qt.Key_Right
                    || key === Qt.Key_Return || key === Qt.Key_Enter) {
                const option = inputOptions[keyboardInputIndex]
                if (option.kind === "layout") {
                    const editor = keyboardLayoutEditor()
                    if (editor && (key === Qt.Key_Return || key === Qt.Key_Enter))
                        editor.forceActiveFocus()
                } else if (option.kind === "speed") {
                    if (key === Qt.Key_Left || key === Qt.Key_Right)
                        setInputValue(option, inputValue(option.key)
                            + (key === Qt.Key_Left ? -0.05 : 0.05))
                } else {
                    const next = key === Qt.Key_Left ? false
                        : key === Qt.Key_Right ? true : !inputValue(option.key)
                    setInputValue(option, next)
                }
            } else if (key === Qt.Key_R && !inputApplyPending && !inputRestoring) {
                inputDirty = false
                keyboardLayoutDraft = keyboardLayout
                loadInputSettings()
            } else return
        } else if (page === "displays") {
            if (key === Qt.Key_R && !displayQuery.running) refreshDisplays()
            else if (key === Qt.Key_S && displays.length > 0
                    && displaySavePhase === "idle") {
                keyboardConfirmationIndex = 0
                applyCurrentPage()
            } else if (key === Qt.Key_Tab)
                keyboardDisplaySection = keyboardDisplaySection === "outputs"
                    ? "editor" : "outputs"
            else if (keyboardDisplaySection === "outputs") {
                if (key !== Qt.Key_Left && key !== Qt.Key_Right
                        && key !== Qt.Key_Up && key !== Qt.Key_Down) return
                if (displays.length > 0) {
                    const index = Math.max(0,
                        displays.findIndex(output => output.connector === selectedDisplay))
                    const offset = key === Qt.Key_Left || key === Qt.Key_Up ? -1 : 1
                    selectedDisplay = displays[Math.max(0,
                        Math.min(displays.length - 1, index + offset))].connector
                }
            } else if (key === Qt.Key_Up || key === Qt.Key_Down)
                keyboardDisplayField = Math.max(0, Math.min(4,
                    keyboardDisplayField + (key === Qt.Key_Up ? -1 : 1)))
            else if (key === Qt.Key_Left || key === Qt.Key_Right
                    || key === Qt.Key_Return || key === Qt.Key_Enter) {
                const offset = key === Qt.Key_Left ? -1 : 1
                if (keyboardDisplayField === 0) {
                    const output = selectedDisplayData()
                    if (output) {
                        if (key === Qt.Key_Return || key === Qt.Key_Enter)
                            setSelectedDisplayEnabled(!output.enabled)
                        else
                            setSelectedDisplayEnabled(key === Qt.Key_Right)
                    }
                } else if (keyboardDisplayField === 1) cycleSelectedResolution(offset)
                else if (keyboardDisplayField === 2) cycleSelectedRefreshRate(offset)
                else if (keyboardDisplayField === 3) adjustSelectedScale(offset * 0.25)
                else cycleSelectedTransform(offset)
            } else return
        } else return
        event.accepted = true
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
            displayDirty = false
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
        displayDirty = true
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
        displayDirty = true
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
        keyboardConfirmationIndex = 0
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
        displayDirty = false
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
            if (settingsWindow.visible)
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

    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (settingsWindow.visible && root.page === "displays")
                displayHotplugRefresh.restart()
        }
    }

    Timer {
        id: displayHotplugRefresh
        interval: 350
        onTriggered: {
            if (root.displaySavePhase !== "idle" || root.awaitingDisplayConfirmation
                    || !settingsWindow.visible || root.page !== "displays")
                return
            if (root.displayDirty) {
                root.displayStatus = "Outputs changed. Refresh to discard unsaved edits."
                return
            }
            root.refreshDisplays()
        }
    }

    FileView {
        id: inputFile
        path: root.settings.configRoot + "/niri/mori/input.kdl"
        blockLoading: true
        printErrors: false
        atomicWrites: true
        watchChanges: true
        onSaved: {
            if (root.inputRestoring) {
                root.inputRestoring = false
                root.inputWritePending = false
                root.inputApplyPending = false
                return
            }
            if (!inputValidation.running)
                inputValidation.exec(["niri", "validate", "-c",
                    root.settings.configRoot + "/niri/config.kdl"])
        }
        onSaveFailed: error => {
            root.inputApplyPending = false
            root.inputRestoring = false
            root.inputWritePending = false
            root.inputStatus = ""
            root.inputError = "Could not write input.kdl: "
                + FileViewError.toString(error)
        }
    }

    Process {
        id: inputValidation
        onExited: exitCode => {
            root.inputApplyPending = false
            if (exitCode === 0) {
                root.inputWritePending = false
                root.inputDirty = false
                root.inputBaselineContents = root.inputContents
                root.inputStatus = "Input settings saved"
                root.inputError = ""
            } else {
                root.inputContents = root.inputBaselineContents
                root.inputRestoring = true
                inputFile.setText(root.inputContents)
                root.loadInputSettings()
                root.inputDirty = false
                root.inputStatus = ""
                root.inputError = "Invalid input settings; restored previous config"
            }
        }
    }

    onInputApplyPendingChanged: finishDeferredClose()
    onInputRestoringChanged: finishDeferredClose()

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
            readonly property bool supportsCompact: ["media", "network", "volume", "brightness"]
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
                height: 26
                spacing: 10

                SettingsLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "≡"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.headingFontSize + 2
                    DragHandler {
                        id: dragHandler
                        target: null
                        onActiveChanged: {
                            if (active) {
                                root.keyboardModule = moduleRow.moduleKey
                                root.beginDrag(moduleRow)
                            }
                            else root.finishDrag()
                        }
                        onTranslationChanged: if (active) root.updateDrag(translation.y)
                    }
                }

                SettingsLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.keyboardModule === moduleRow.moduleKey ? "› " : "  ")
                        + root.moduleLabel(moduleRow.moduleKey)
                    color: root.keyboardModule === moduleRow.moduleKey
                        || moduleRow.moduleEnabled ? Theme.fg : Theme.grey1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    TapHandler {
                        onTapped: {
                            root.keyboardModule = moduleRow.moduleKey
                            root.settings.setModuleEnabled(
                                moduleRow.moduleKey, !moduleRow.moduleEnabled)
                        }
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
                        SettingsLabel {
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

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.keyboardModule = moduleRow.moduleKey
                            root.settings.setCompactMode(
                                moduleRow.moduleKey, !moduleRow.moduleCompact)
                        }
                    }
                }

                Rectangle {
                    width: 36
                    height: 18
                    anchors.verticalCenter: parent.verticalCenter
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
                        onTapped: {
                            root.keyboardModule = moduleRow.moduleKey
                            root.settings.setModuleEnabled(
                                moduleRow.moduleKey, !moduleRow.moduleEnabled)
                        }
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
        onVisibleChanged: {
            if (visible) Qt.callLater(() => keyboardScope.forceActiveFocus())
            else root.popupCoordinator.hidePopup(root)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        FocusScope {
            id: keyboardScope
            anchors.fill: parent
            focus: settingsWindow.visible
            Keys.onPressed: event => root.handleSettingsKey(event)
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

            Item {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 18
                height: 30

                Rectangle {
                    id: backButton
                    visible: root.page !== "home"
                    anchors.right: closeButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    color: Theme.bg1
                    border.width: 1
                    border.color: Theme.fg

                    SettingsLabel {
                        anchors.centerIn: parent
                        text: "←"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 2
                    }
                    TapHandler { onTapped: root.page = "home" }
                }
                SettingsLabel {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.pageTitle()
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.headingFontSize + 2
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    id: closeButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    color: Theme.bg1
                    border.width: 1
                    border.color: Theme.fg

                    SettingsLabel {
                        anchors.centerIn: parent
                        text: "×"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 2
                    }
                    TapHandler { onTapped: root.close() }
                }
            }

            Rectangle {
                id: applyButton
                readonly property bool ready: root.page === "input"
                    ? root.inputPendingChanges && !root.inputApplyPending && !root.inputRestoring
                    : root.page === "power" ? root.powerDirty && root.powerDraftsValid
                    : root.page === "displays" ? root.displayDirty
                        && root.displaySavePhase === "idle" && !root.awaitingDisplayConfirmation
                        : false
                visible: root.page === "input" || root.page === "displays" || root.page === "power"
                anchors.verticalCenter: header.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 90
                width: 84
                height: 28
                color: ready ? Theme.bg2 : Theme.bg1
                border.width: 1
                border.color: ready ? Theme.fg : Theme.bg4

                SettingsLabel {
                    anchors.centerIn: parent
                    text: "Apply"
                    color: applyButton.ready ? Theme.fg : Theme.grey1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                TapHandler {
                    enabled: applyButton.ready
                    onTapped: root.applyCurrentPage()
                }
            }

            SettingsLabel {
                anchors.right: applyButton.left
                anchors.rightMargin: 10
                anchors.verticalCenter: applyButton.verticalCenter
                width: 175
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                visible: applyButton.visible
                text: root.page === "input" ? root.inputStatus
                    : root.page === "power" ? root.powerStatus : root.displayStatus
                color: Theme.grey1
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
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

            Rectangle {
                id: saveErrorBanner
                visible: root.settings.saveError.length > 0
                anchors.top: headerDivider.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                height: Math.max(34, saveErrorText.implicitHeight + 12)
                color: Theme.bgred
                border.width: 1
                border.color: Theme.red

                Text {
                    id: saveErrorText
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.right: retrySave.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Settings not saved: " + root.settings.saveError
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    wrapMode: Text.Wrap
                }

                SettingsLabel {
                    id: retrySave
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Retry"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                    TapHandler { onTapped: root.settings.save() }
                }
            }

            Item {
                id: pageArea
                anchors.top: saveErrorBanner.visible
                    ? saveErrorBanner.bottom : headerDivider.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 18
                anchors.topMargin: 12

                Loader {
                    id: homePage
                    anchors.fill: parent
                    active: settingsWindow.visible && root.page === "home"

                    sourceComponent: Component {
                        Column {
                            visible: root.page === "home"
                            width: parent.width
                            spacing: 8

                            SettingsLabel {
                                text: "Choose a category · ↑↓ / Enter"
                                color: Theme.grey1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            Repeater {
                                id: categoryRepeater
                                model: [
                                    { "key": "modules", "label": "Modules", "description": "Visibility and bar order" },
                                    { "key": "appearance", "label": "Appearance", "description": "Module accent colors" },
                                    { "key": "clock", "label": "Time & date", "description": "Clock and calendar formats" },
                                    { "key": "power", "label": "Power menu", "description": "Automatic or custom power commands" },
                                    { "key": "displays", "label": "Displays", "description": "Connected Niri outputs" },
                                    { "key": "input", "label": "Input", "description": "Mouse and touchpad" },
                                    { "key": "about", "label": "About", "description": "Mori shell information" }
                                ]
                                delegate: Rectangle {
                                    id: categoryRow
                                    required property var modelData
                                    required property int index
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
                                        SettingsLabel {
                                            text: (categoryRow.index === root.keyboardCategoryIndex
                                                ? "› " : "  ") + categoryRow.modelData.label
                                            color: categoryRow.index === root.keyboardCategoryIndex
                                                || categoryHover.hovered ? Theme.fg : Theme.grey1
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.headingFontSize
                                        }
                                        SettingsLabel {
                                            text: categoryRow.modelData.description
                                            color: Theme.grey1
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize
                                        }
                                    }
                                    SettingsLabel {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "›"
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 24
                                    }
                                    HoverHandler { id: categoryHover }
                                    TapHandler {
                                        onTapped: {
                                            root.keyboardCategoryIndex = categoryRow.index
                                            root.openPage(categoryRow.modelData.key)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Loader {
                    id: modulesPage
                    anchors.fill: parent
                    active: settingsWindow.visible && root.page === "modules"

                    sourceComponent: Component {
                        Flickable {
                            readonly property alias anchorRows: anchorRepeater
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
                                SettingsLabel {
                                    text: "↑↓ select · Enter toggle · C compact · Shift+arrows move · drag ≡"
                                    color: Theme.grey1
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }
                                Repeater {
                                    id: anchorRepeater
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
                                        readonly property var rowRepeater: moduleRows
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

                                            SettingsLabel {
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
                                                id: moduleRows
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
                    }
                }

                Loader {
                    id: appearancePage
                    anchors.fill: parent
                    active: settingsWindow.visible && root.page === "appearance"

                    sourceComponent: Component {
                        Flickable {
                            readonly property alias rows: colorRows
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
                                SettingsLabel {
                                    text: "↑↓ module · ←→ color · Enter apply"
                                    color: Theme.grey1
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }
                                Repeater {
                                    id: colorRows
                                    model: root.allModules
                                    delegate: Rectangle {
                                        id: colorRow
                                        required property string modelData
                                        required property int index
                                        readonly property string moduleKey: modelData
                                        width: parent.width
                                        height: 48
                                        color: colorHover.hovered ? Theme.bg2 : "transparent"
                                        SettingsLabel {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: (colorRow.index === root.keyboardColorRow ? "› " : "  ")
                                                + root.moduleLabel(colorRow.moduleKey)
                                            color: colorRow.index === root.keyboardColorRow
                                                ? Theme.fg : Theme.grey1
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
                                                    required property int index
                                                    readonly property bool selected: {
                                                        const currentRevision = root.settings.revision
                                                        return root.settings.moduleColors[colorRow.moduleKey]
                                                            === modelData.token
                                                    }
                                                    width: 24
                                                    height: 24
                                                    color: modelData.color
                                                    border.width: root.keyboardColorRow === colorRow.index
                                                        && root.keyboardColorIndex === index ? 3 : 1
                                                    border.color: selected || root.keyboardColorRow === colorRow.index
                                                        && root.keyboardColorIndex === index
                                                        ? Theme.fg : Theme.bg4
                                                    TapHandler {
                                                        onTapped: {
                                                            root.keyboardColorRow = colorRow.index
                                                            root.keyboardColorIndex = swatch.index
                                                            root.settings.setModuleColor(
                                                                colorRow.moduleKey, swatch.modelData.token)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        HoverHandler { id: colorHover }
                                    }
                                }
                            }
                        }
                    }
                }

                Loader {
                    id: clockPage
                    anchors.fill: parent
                    active: settingsWindow.visible && root.page === "clock"

                    sourceComponent: Component {
                        Column {
                            visible: root.page === "clock"
                            width: parent.width
                            spacing: 12

                            SettingsLabel {
                                text: "↑↓ setting · ←→ / Enter change"
                                color: Theme.grey1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }

                            Repeater {
                                model: root.clockOptions
                                delegate: Column {
                                    id: clockRow
                                    required property var modelData
                                    required property int index
                                    width: parent.width
                                    spacing: 6

                                    SettingsLabel {
                                        text: (clockRow.index === root.keyboardClockIndex ? "› " : "  ")
                                            + clockRow.modelData.label
                                        color: clockRow.index === root.keyboardClockIndex
                                            ? Theme.fg : Theme.grey1
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                    }

                                    Row {
                                        spacing: 8
                                        Repeater {
                                            model: clockRow.modelData.values
                                            delegate: Rectangle {
                                                id: clockChoice
                                                required property var modelData
                                                required property int index
                                                readonly property bool selected: root.clockOptionValue(
                                                    clockRow.modelData.key) === modelData
                                                width: Math.max(92, choiceText.implicitWidth + 20)
                                                height: 30
                                                color: choiceHover.hovered ? Theme.bg2 : Theme.bg1
                                                border.width: 1
                                                border.color: Theme.bg4

                                                SettingsLabel {
                                                    id: choiceText
                                                    anchors.centerIn: parent
                                                    text: clockRow.modelData.labels[clockChoice.index]
                                                    color: clockChoice.selected || choiceHover.hovered
                                                        ? Theme.fg : Theme.grey1
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSize
                                                }
                                                HoverHandler { id: choiceHover }
                                                TapHandler {
                                                    onTapped: {
                                                        root.keyboardClockIndex = clockRow.index
                                                        root.settings.setClockOption(
                                                            clockRow.modelData.key, clockChoice.modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            SettingsLabel {
                                text: "Preview: " + root.clockPreview()
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            SettingsLabel {
                                text: "Time format also applies to calendar events."
                                color: Theme.grey1
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                            }
                        }
                    }
                }

                Loader {
                    id: powerPage
                    anchors.fill: parent
                    active: settingsWindow.visible && root.page === "power"

                    sourceComponent: Component {
                        ScrollableColumn {
                            readonly property alias rows: powerRows
                            id: powerFlick
                            visible: root.page === "power"
                            anchors.fill: parent
                            spacing: 16

                            Text {
                                width: parent.width
                                text: "Blank commands use automatic selection. Enter a custom command with its arguments, then Apply."
                                wrapMode: Text.WordWrap
                                color: Theme.grey1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }

                            Repeater {
                                id: powerRows
                                model: root.powerOptions
                                delegate: Column {
                                    id: powerRow
                                    required property var modelData
                                    required property int index
                                    readonly property alias editor: commandField
                                    width: parent.width
                                    spacing: 6

                                    Item {
                                        width: parent.width
                                        height: 24
                                        SettingsLabel {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: (powerRow.index === root.keyboardPowerIndex ? "› " : "  ")
                                                + powerRow.modelData.label
                                            color: powerRow.index === root.keyboardPowerIndex ? Theme.fg : Theme.grey1
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize
                                        }
                                        SettingsLabel {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Use automatic"
                                            color: (root.powerDrafts[powerRow.modelData.key] || "").length
                                                ? Theme.fg : Theme.grey1
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize
                                            TapHandler {
                                                onTapped: {
                                                    root.keyboardPowerIndex = powerRow.index
                                                    root.setPowerDraft(powerRow.modelData.key, "")
                                                    keyboardScope.forceActiveFocus()
                                                }
                                            }
                                        }
                                    }

                                    TextField {
                                        id: commandField
                                        width: parent.width
                                        height: 32
                                        text: root.powerDrafts[powerRow.modelData.key] || ""
                                        placeholderText: "Automatic"
                                        color: Theme.fg
                                        placeholderTextColor: Theme.grey1
                                        selectionColor: Theme.bg4
                                        selectedTextColor: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        leftPadding: 8
                                        rightPadding: 8
                                        background: Rectangle {
                                            color: Theme.bg2
                                            border.width: 1
                                            border.color: root.powerErrors[powerRow.modelData.key] ? Theme.red
                                                : commandField.activeFocus ? Theme.fg : Theme.bg4
                                        }
                                        onTextEdited: root.setPowerDraft(powerRow.modelData.key, text)
                                        onActiveFocusChanged: {
                                            root.editingPowerCommand = activeFocus
                                            if (activeFocus) root.keyboardPowerIndex = powerRow.index
                                        }
                                        Keys.onPressed: event => {
                                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                if (event.modifiers & Qt.ControlModifier)
                                                    root.applyPowerCommands()
                                                keyboardScope.forceActiveFocus()
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Escape) {
                                                keyboardScope.forceActiveFocus()
                                                event.accepted = true
                                            }
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        visible: (root.powerErrors[powerRow.modelData.key] || "").length > 0
                                        text: root.powerErrors[powerRow.modelData.key] || ""
                                        wrapMode: Text.WordWrap
                                        color: Theme.red
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Math.max(10, Theme.fontSize - 1)
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: "↑↓ action · Enter edit · Ctrl+Enter apply\nQuote paths or arguments containing spaces. Commands that need root should use your authorized wrapper."
                                wrapMode: Text.WordWrap
                                color: Theme.grey1
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.max(10, Theme.fontSize - 1)
                            }
                        }
                    }
                }

                Loader {
                    id: inputPage
                    anchors.fill: parent
                    active: settingsWindow.visible && root.page === "input"

                    sourceComponent: Component {
                        Column {
                            readonly property alias rows: inputRows
                            visible: root.page === "input"
                            width: parent.width
                            spacing: 10

                            SettingsLabel {
                                text: "Niri input · leave keyboard layout empty for the system default"
                                color: Theme.grey1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            SettingsLabel {
                                text: "↑↓ select · ←→ adjust · Enter edit/toggle · Ctrl+Enter apply"
                                color: Theme.grey1
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                            }
                            SettingsLabel {
                                text: "Sensitivity is Niri acceleration speed: −1 slower, +1 faster."
                                color: Theme.grey1
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                            }

                            Repeater {
                                id: inputRows
                                model: root.inputOptions
                                delegate: Rectangle {
                                    id: inputRow
                                    property alias editor: layoutField
                                    required property var modelData
                                    required property int index
                                    readonly property var option: modelData
                                    readonly property var currentValue: {
                                        const revision = root.inputRevision
                                        return root.inputValue(option.key)
                                    }
                                    width: parent.width
                                    height: 54
                                    color: Theme.bg1
                                    border.width: 1
                                    border.color: Theme.bg4

                                    SettingsLabel {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (inputRow.index === root.keyboardInputIndex ? "› " : "  ")
                                            + inputRow.option.label
                                        color: inputRow.index === root.keyboardInputIndex
                                            ? Theme.fg : Theme.grey1
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                    }

                                    TextField {
                                        id: layoutField
                                        text: root.keyboardLayoutDraft
                                        visible: inputRow.option.kind === "layout"
                                        anchors.right: parent.right
                                        anchors.rightMargin: 112
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 150
                                        height: 28
                                        placeholderText: "System default"
                                        verticalAlignment: TextInput.AlignVCenter
                                        leftPadding: 8
                                        rightPadding: 8
                                        topPadding: 0
                                        bottomPadding: 0
                                        color: Theme.fg
                                        placeholderTextColor: Theme.grey1
                                        selectionColor: Theme.bg4
                                        selectedTextColor: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        background: Rectangle {
                                            color: Theme.bg2
                                            border.width: 1
                                            border.color: layoutField.activeFocus ? Theme.fg : Theme.bg4
                                        }
                                        onTextChanged: if (visible) root.keyboardLayoutDraft = text
                                        onActiveFocusChanged: {
                                            root.editingKeyboardLayout = activeFocus
                                            if (activeFocus)
                                                root.keyboardInputIndex = inputRow.index
                                        }
                                        Keys.onPressed: event => {
                                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                keyboardScope.forceActiveFocus()
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Escape) {
                                                layoutField.text = root.keyboardLayout
                                                keyboardScope.forceActiveFocus()
                                                event.accepted = true
                                            }
                                        }
                                    }

                                    SettingsLabel {
                                        visible: inputRow.option.kind === "layout"
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Use system"
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Math.max(10, Theme.fontSize - 1)
                                        TapHandler {
                                            onTapped: {
                                                root.keyboardInputIndex = inputRow.index
                                                layoutField.text = ""
                                                keyboardScope.forceActiveFocus()
                                            }
                                        }
                                    }

                                    Row {
                                        visible: inputRow.option.kind === "speed"
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10

                                        Slider {
                                            id: speedSlider
                                            width: 175
                                            height: 22
                                            from: -1
                                            to: 1
                                            stepSize: 0.05
                                            value: Number(inputRow.currentValue)
                                            onMoved: root.setInputValue(inputRow.option, value)

                                            background: Rectangle {
                                                x: speedSlider.leftPadding
                                                y: speedSlider.topPadding
                                                    + speedSlider.availableHeight / 2 - height / 2
                                                width: speedSlider.availableWidth
                                                height: 4
                                                color: Theme.bg4
                                            }
                                            handle: Rectangle {
                                                x: speedSlider.leftPadding + speedSlider.visualPosition
                                                    * (speedSlider.availableWidth - width)
                                                y: speedSlider.topPadding
                                                    + speedSlider.availableHeight / 2 - height / 2
                                                width: 10
                                                height: 10
                                                color: Theme.fg
                                            }
                                        }
                                        SettingsLabel {
                                            width: 42
                                            anchors.verticalCenter: parent.verticalCenter
                                            horizontalAlignment: Text.AlignRight
                                            text: Number(inputRow.currentValue).toFixed(2)
                                            color: Theme.fg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize
                                        }
                                    }

                                    Rectangle {
                                        visible: inputRow.option.kind === "flag"
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 36
                                        height: 18
                                        color: inputRow.currentValue ? Theme.fg : Theme.bg4
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: inputRow.currentValue ? parent.width - width - 3 : 3
                                            width: 12
                                            height: 12
                                            color: inputRow.currentValue ? Theme.bg : Theme.grey1
                                        }
                                        TapHandler {
                                            onTapped: {
                                                root.keyboardInputIndex = inputRow.index
                                                root.setInputValue(inputRow.option, !inputRow.currentValue)
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: root.inputError.length > 0 || root.inputStatus.length > 0
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: root.inputError.length > 0 ? root.inputError : root.inputStatus
                                color: root.inputError.length > 0 ? Theme.red : Theme.grey1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                        }
                    }
                }

                Loader {
                    id: displaysPage
                    anchors.fill: parent
                    active: settingsWindow.visible && root.page === "displays"
                    onLoaded: Qt.callLater(root.fitDisplayLayout)
                    sourceComponent: Component {
                        Item {
                            readonly property alias canvas: displayCanvas
                            anchors.fill: parent
                            visible: root.page === "displays"

                            Column {
                                id: displaysColumn
                                anchors.fill: parent
                                spacing: 10

                                SettingsLabel {
                                    text: root.keyboardDisplaySection === "outputs"
                                        ? "Arrows: output · Tab: editor · R: refresh · S: Apply"
                                        : "↑↓: field · ←→: adjust · Enter: change · Tab: outputs"
                                    color: Theme.grey1
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                }

                                Row {
                                    spacing: 10

                                    Rectangle {
                                        width: refreshLabel.implicitWidth + 20
                                        height: 30
                                        color: refreshHover.hovered ? Theme.bg2 : Theme.bg1
                                        border.width: 1
                                        border.color: Theme.fg
                                        SettingsLabel {
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
                                                && root.displaySavePhase === "idle"
                                                && !root.awaitingDisplayConfirmation
                                            onTapped: root.refreshDisplays()
                                        }
                                    }

                                    SettingsLabel {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.displayError.length > 0
                                            ? root.displayError : root.displayStatus
                                        color: root.displayError.length > 0 ? Theme.red : Theme.grey1
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                    }
                                }

                                SettingsLabel {
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
                                            color: Theme.bg1
                                            border.width: 1
                                            border.color: Theme.bg4
                                            opacity: modelData.enabled ? 1 : 0.6
                                            SettingsLabel {
                                                id: selectorLabel
                                                anchors.centerIn: parent
                                                text: displaySelector.modelData.connector
                                                    + (displaySelector.modelData.enabled ? "" : " · off")
                                                color: root.selectedDisplay === displaySelector.modelData.connector
                                                    ? Theme.fg : Theme.grey1
                                                font.underline: root.keyboardDisplaySection === "outputs"
                                                    && root.selectedDisplay === displaySelector.modelData.connector
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
                                            height: Math.max(54, modelData.height * root.displayViewScale)
                                            z: displayDrag.active ? 10 : 1
                                            color: Theme.bg1
                                            opacity: modelData.enabled ? 1 : 0.55
                                            border.width: root.selectedDisplay === modelData.connector ? 2 : 1
                                            border.color: root.selectedDisplay === modelData.connector
                                                ? Theme.fg : Theme.bg4

                                            Column {
                                                anchors.centerIn: parent
                                                width: parent.width - 10
                                                spacing: 2
                                                SettingsLabel {
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                    text: displayTile.modelData.connector
                                                    color: root.selectedDisplay === displayTile.modelData.connector
                                                        ? Theme.fg : Theme.grey1
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSize
                                                    font.weight: Font.DemiBold
                                                }
                                                SettingsLabel {
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
                                    height: displayEditorColumn.implicitHeight + 24
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

                                        SettingsLabel {
                                            id: displayEnabledLabel
                                            anchors.centerIn: parent
                                            text: displayEditor.output && displayEditor.output.enabled
                                                ? "Disable" : "Enable"
                                            color: Theme.fg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize
                                            font.underline: root.keyboardDisplaySection === "editor"
                                                && root.keyboardDisplayField === 0
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
                                        id: displayEditorColumn
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 12
                                        spacing: 6

                                        SettingsLabel {
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
                                            SettingsLabel {
                                                width: 95
                                                text: root.keyboardDisplaySection === "editor"
                                                    && root.keyboardDisplayField === 1
                                                    ? "› Resolution" : "  Resolution"
                                                color: root.keyboardDisplaySection === "editor"
                                                    && root.keyboardDisplayField === 1 ? Theme.fg : Theme.grey1
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize
                                            }
                                            SettingsLabel {
                                                text: "‹"
                                                color: Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.headingFontSize
                                                TapHandler { onTapped: root.cycleSelectedResolution(-1) }
                                            }
                                            SettingsLabel {
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
                                            SettingsLabel {
                                                text: "›"
                                                color: Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.headingFontSize
                                                TapHandler { onTapped: root.cycleSelectedResolution(1) }
                                            }
                                        }

                                        Row {
                                            spacing: 8
                                            SettingsLabel {
                                                width: 95
                                                text: root.keyboardDisplaySection === "editor"
                                                    && root.keyboardDisplayField === 2
                                                    ? "› Refresh" : "  Refresh"
                                                color: root.keyboardDisplaySection === "editor"
                                                    && root.keyboardDisplayField === 2 ? Theme.fg : Theme.grey1
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize
                                            }
                                            SettingsLabel {
                                                text: "‹"
                                                color: Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.headingFontSize
                                                TapHandler { onTapped: root.cycleSelectedRefreshRate(-1) }
                                            }
                                            SettingsLabel {
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
                                            SettingsLabel {
                                                text: "›"
                                                color: Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.headingFontSize
                                                TapHandler { onTapped: root.cycleSelectedRefreshRate(1) }
                                            }
                                        }

                                        Row {
                                            spacing: 8
                                            SettingsLabel {
                                                width: 95
                                                text: root.keyboardDisplaySection === "editor"
                                                    && root.keyboardDisplayField === 3
                                                    ? "› Scale" : "  Scale"
                                                color: root.keyboardDisplaySection === "editor"
                                                    && root.keyboardDisplayField === 3 ? Theme.fg : Theme.grey1
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize
                                            }
                                            SettingsLabel {
                                                text: "−"
                                                color: Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.headingFontSize
                                                TapHandler { onTapped: root.adjustSelectedScale(-0.25) }
                                            }
                                            SettingsLabel {
                                                width: 220
                                                text: displayEditor.output
                                                    ? displayEditor.output.scale.toFixed(2) + "×" : "—"
                                                color: Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                            SettingsLabel {
                                                text: "+"
                                                color: Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.headingFontSize
                                                TapHandler { onTapped: root.adjustSelectedScale(0.25) }
                                            }
                                        }

                                        Row {
                                            spacing: 8
                                            SettingsLabel {
                                                width: 95
                                                text: root.keyboardDisplaySection === "editor"
                                                    && root.keyboardDisplayField === 4
                                                    ? "› Transform" : "  Transform"
                                                color: root.keyboardDisplaySection === "editor"
                                                    && root.keyboardDisplayField === 4 ? Theme.fg : Theme.grey1
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize
                                            }
                                            SettingsLabel {
                                                text: "‹"
                                                color: Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.headingFontSize
                                                TapHandler { onTapped: root.cycleSelectedTransform(-1) }
                                            }
                                            SettingsLabel {
                                                width: 220
                                                text: displayEditor.output
                                                    ? displayEditor.output.transform : "—"
                                                color: Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                            SettingsLabel {
                                                text: "›"
                                                color: Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.headingFontSize
                                                TapHandler { onTapped: root.cycleSelectedTransform(1) }
                                            }
                                        }

                                        SettingsLabel {
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
                                    text: "Apply writes display state, position, mode, scale, and transform, then asks you to keep or revert. Other output settings and comments are preserved."
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    color: Theme.grey1
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Math.max(10, Theme.fontSize - 1)
                                }
                            }
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

                    SettingsLabel {
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
                            SettingsLabel {
                                id: keepLabel
                                anchors.centerIn: parent
                                text: "Keep"
                                color: root.keyboardConfirmationIndex === 0
                                    ? Theme.fg : Theme.grey1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.underline: root.keyboardConfirmationIndex === 0
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
                            SettingsLabel {
                                id: revertLabel
                                anchors.centerIn: parent
                                text: "Revert"
                                color: root.keyboardConfirmationIndex === 1
                                    ? Theme.fg : Theme.grey1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.underline: root.keyboardConfirmationIndex === 1
                            }
                            HoverHandler { id: revertHover }
                            TapHandler {
                                onTapped: root.revertDisplayConfiguration(
                                    "Reverting display settings…")
                            }
                        }
                    }
                }

                Loader {
                    id: aboutPage
                    anchors.fill: parent
                    active: settingsWindow.visible && root.page === "about"

                    sourceComponent: Component {
                        Column {
                            visible: root.page === "about"
                            width: parent.width
                            spacing: 12
                            SettingsLabel {
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
                            SettingsLabel {
                                text: "Settings are saved to ~/.config/quickshell/mori-settings.json"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                        }
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
                SettingsLabel {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.moduleLabel(root.draggingModule)
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                SettingsLabel {
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
