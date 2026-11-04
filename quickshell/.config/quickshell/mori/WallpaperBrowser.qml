import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "./theme"

// Wallpaper chooser shared by the bar's wallpaper popup and Settings →
// Wallpaper: folder browser, monitor and dark/light choice, thumbnail grid.
// The current mode's choice is applied with awww right away; both modes are
// saved in ~/.local/state/mori/wallpapers-<mode>, which mori-theme restores.
Item {
    id: root

    required property var settings
    property color accent: Theme.green
    // False while a host gives the keyboard to something else (hides the › markers).
    property bool keyboardActive: true
    // Hosts hide while zenity's folder dialog is open, then reopen.
    signal folderPickerRequested()
    signal folderPicked()

    readonly property string currentMode: Theme.dark ? "dark" : "light"
    property string mode: currentMode
    property var saved: ({ "dark": {}, "light": {} })
    property var live: ({})
    property var selectedScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property url rootFolder: "file://" + settings.wallpaperFolder
    property int keyboardIndex: -1
    property string keyboardMode: "screens"
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/mori"
    readonly property int columns: Math.max(1, Math.round(grid.width / grid.cellWidth))

    function reset() {
        keyboardMode = "screens"
        keyboardIndex = -1
        mode = currentMode
        files.folder = rootFolder
        refresh()
    }
    function refresh() {
        darkFile.reload()
        lightFile.reload()
        if (!wallpaperQuery.running)
            wallpaperQuery.exec(["awww", "query"])
    }

    function goToParent() {
        if (files.folder.toString() !== rootFolder.toString())
            files.folder = files.parentFolder
    }
    function goIntoFolder() {
        // Keep the last file-grid selection when switching back to monitors;
        // otherwise descend into the first folder in the current directory.
        if (keyboardIndex >= 0 && keyboardIndex < files.count && files.isFolder(keyboardIndex)) {
            files.folder = files.get(keyboardIndex, "fileUrl")
            return
        }
        for (let i = 0; i < files.count; ++i) {
            if (files.isFolder(i)) {
                files.folder = files.get(i, "fileUrl")
                return
            }
        }
    }
    function moveKeyboardSelection(offset) {
        if (files.count === 0)
            return
        const start = keyboardIndex < 0 ? 0 : keyboardIndex
        keyboardIndex = Math.max(0, Math.min(files.count - 1, start + offset))
        grid.positionViewAtIndex(keyboardIndex, GridView.Contain)
    }
    function activateKeyboardSelection() {
        if (keyboardIndex < 0 || keyboardIndex >= files.count)
            return
        const fileUrl = files.get(keyboardIndex, "fileUrl")
        if (files.isFolder(keyboardIndex))
            files.folder = fileUrl
        else
            selectWallpaper(fileUrl)
    }
    function moveScreen(step) {
        const screens = Quickshell.screens
        if (screens.length === 0) return
        const index = Math.max(0, screens.indexOf(selectedScreen))
        selectedScreen = screens[Math.max(0, Math.min(screens.length - 1, index + step))]
    }

    // Returns true when the key was used; hosts handle Escape themselves.
    function handleKey(event) {
        const key = event.key
        if (key === Qt.Key_Tab) {
            keyboardMode = keyboardMode === "screens" ? "files" : "screens"
            if (keyboardMode === "files" && keyboardIndex < 0 && files.count > 0)
                keyboardIndex = 0
        } else if (key === Qt.Key_F) {
            chooseFolder()
        } else if (key === Qt.Key_M) {
            mode = mode === "dark" ? "light" : "dark"
        } else if (keyboardMode === "screens" && key === Qt.Key_Up) {
            goToParent()
        } else if (keyboardMode === "screens" && key === Qt.Key_Down) {
            goIntoFolder()
        } else if (keyboardMode === "screens" && (key === Qt.Key_Left || key === Qt.Key_Right)) {
            moveScreen(key === Qt.Key_Left ? -1 : 1)
        } else if (keyboardMode === "files" && key === Qt.Key_Left)
            moveKeyboardSelection(-1)
        else if (keyboardMode === "files" && key === Qt.Key_Right)
            moveKeyboardSelection(1)
        else if (keyboardMode === "files" && key === Qt.Key_Up)
            moveKeyboardSelection(-columns)
        else if (keyboardMode === "files" && key === Qt.Key_Down)
            moveKeyboardSelection(columns)
        else if (keyboardMode === "files" && (key === Qt.Key_Return || key === Qt.Key_Enter))
            activateKeyboardSelection()
        else if (keyboardMode === "files" && key === Qt.Key_Backspace
                && files.folder.toString() !== rootFolder.toString())
            goToParent()
        else
            return false
        return true
    }

    function localPath(fileUrl) {
        return decodeURIComponent(fileUrl.toString()).replace(/^file:\/\//, "")
    }
    // The wallpaper chosen for a monitor in a mode: live for the current
    // mode, saved for the other one.
    function wallpaperFor(screen, forMode) {
        if (!screen) return ""
        if (forMode === currentMode && live[screen.name]) return live[screen.name]
        return saved[forMode][screen.name] || ""
    }
    function selectWallpaper(fileUrl) {
        if (!selectedScreen)
            return
        const path = localPath(fileUrl)
        const forMode = mode
        const updated = Object.assign({}, saved[forMode])
        // Fill in the other monitors so the saved file stays complete.
        for (const screen of Quickshell.screens) {
            if (!updated[screen.name] && wallpaperFor(screen, forMode))
                updated[screen.name] = wallpaperFor(screen, forMode)
        }
        updated[selectedScreen.name] = path
        const all = Object.assign({}, saved)
        all[forMode] = updated
        saved = all
        const text = Object.keys(updated).map(name => name + "\t" + updated[name]).join("\n") + "\n"
        ;(forMode === "dark" ? darkFile : lightFile).setText(text)
        if (forMode === currentMode) {
            const current = Object.assign({}, live)
            current[selectedScreen.name] = path
            live = current
            wallpaperSetter.exec([
                "awww", "img",
                "--outputs", selectedScreen.name,
                "--transition-type", "fade",
                "--transition-duration", "0.8",
                path
            ])
        }
    }
    function parseSaved(forMode, text) {
        const parsed = {}
        for (const line of text.split("\n")) {
            const tab = line.indexOf("\t")
            if (tab > 0) parsed[line.slice(0, tab)] = line.slice(tab + 1)
        }
        const all = Object.assign({}, saved)
        all[forMode] = parsed
        saved = all
    }
    function parseAwwwQuery(output) {
        const current = {}
        for (const line of output.split(/\r?\n/)) {
            const match = line.match(/^: ([^:]+): .*currently displaying: image: (.+)$/)
            if (match)
                current[match[1]] = match[2]
        }
        live = current
    }
    function chooseFolder() {
        folderPickerRequested()
        settings.pickWallpaperFolder(() => root.folderPicked())
    }

    onRootFolderChanged: files.folder = rootFolder
    onCurrentModeChanged: {
        mode = currentMode
        refresh()
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            for (const screen of Quickshell.screens) {
                if (root.selectedScreen && screen.name === root.selectedScreen.name) {
                    root.selectedScreen = screen
                    return
                }
            }
            root.selectedScreen = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        }
    }

    FileView {
        id: darkFile
        path: root.stateDir + "/wallpapers-dark"
        printErrors: false
        atomicWrites: true
        onLoaded: root.parseSaved("dark", text())
    }
    FileView {
        id: lightFile
        path: root.stateDir + "/wallpapers-light"
        printErrors: false
        atomicWrites: true
        onLoaded: root.parseSaved("light", text())
    }

    FolderListModel {
        id: files
        folder: root.rootFolder
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.avif", "*.bmp", "*.gif"]
        showDirs: true
        showDotAndDotDot: false
        showHidden: false
        showOnlyReadable: true
        sortField: FolderListModel.Name
        sortCaseSensitive: false
        showDirsFirst: true
        onFolderChanged: root.keyboardIndex = -1
        onCountChanged: {
            if (root.keyboardIndex >= count)
                root.keyboardIndex = count - 1
            else if (root.keyboardIndex < 0 && count > 0 && root.keyboardMode === "files")
                root.keyboardIndex = 0
        }
    }

    Process { id: wallpaperSetter }

    Process {
        id: wallpaperQuery
        stdout: StdioCollector {
            onStreamFinished: root.parseAwwwQuery(this.text)
        }
    }

    Column {
        anchors.fill: parent
        spacing: 8

        Row {
            width: parent.width
            height: folderActions.implicitHeight
            spacing: 12

            Text {
                width: parent.width - folderActions.implicitWidth - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: root.localPath(files.folder)
                elide: Text.ElideLeft
                color: Theme.grey1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Row {
                id: folderActions
                spacing: 12

                Rectangle {
                    width: upText.implicitWidth + 20
                    height: Theme.controlHeight
                    readonly property bool available: files.folder.toString() !== root.rootFolder.toString()
                    color: Theme.controlBackground(false, false, available && upHover.hovered)
                    border.width: 1
                    border.color: Theme.controlBorder(false, false, available && upHover.hovered, root.accent)
                    Text {
                        id: upText
                        anchors.centerIn: parent
                        text: "↑ Up"
                        color: parent.available ? root.accent : Theme.disabledText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    HoverHandler { id: upHover }
                    TapHandler {
                        enabled: parent.available
                        onTapped: root.goToParent()
                    }
                }
                Rectangle {
                    width: folderText.implicitWidth + 20
                    height: Theme.controlHeight
                    color: Theme.controlBackground(false, false, folderHover.hovered)
                    border.width: 1
                    border.color: Theme.controlBorder(false, false, folderHover.hovered, root.accent)
                    Text {
                        id: folderText
                        anchors.centerIn: parent
                        text: "Choose folder · F"
                        color: root.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    HoverHandler { id: folderHover }
                    TapHandler { onTapped: root.chooseFolder() }
                }
            }
        }

        Flow {
            width: parent.width
            spacing: 6

            Repeater {
                model: Quickshell.screens

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool selected: root.selectedScreen === modelData
                    readonly property bool focused: root.keyboardActive && root.keyboardMode === "screens" && selected
                    height: Theme.controlHeight
                    width: screenName.implicitWidth + 16
                    color: Theme.controlBackground(selected, focused, screenHover.hovered)
                    border.width: 1
                    border.color: Theme.controlBorder(selected, focused, screenHover.hovered, root.accent)

                    Text {
                        id: screenName
                        anchors.centerIn: parent
                        text: (parent.focused ? "› " : "  ") + modelData.name
                        color: parent.selected ? root.accent : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    HoverHandler { id: screenHover }
                    TapHandler { onTapped: root.selectedScreen = modelData }
                }
            }

            Item { width: 12; height: Theme.controlHeight }

            Repeater {
                model: ["dark", "light"]

                delegate: Rectangle {
                    required property string modelData
                    readonly property bool selected: root.mode === modelData
                    height: Theme.controlHeight
                    width: modeName.implicitWidth + 16
                    color: Theme.controlBackground(selected, false, modeHover.hovered)
                    border.width: 1
                    border.color: Theme.controlBorder(selected, false, modeHover.hovered, root.accent)

                    Text {
                        id: modeName
                        anchors.centerIn: parent
                        text: (modelData === "dark" ? "Dark" : "Light")
                            + (modelData === root.currentMode ? " (now)" : "")
                        color: parent.selected ? root.accent : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    HoverHandler { id: modeHover }
                    TapHandler { onTapped: root.mode = modelData }
                }
            }
        }

        GridView {
            id: grid
            width: parent.width
            height: Math.max(0, parent.height - y - wallpaperHint.implicitHeight - parent.spacing)
            clip: true
            cellWidth: width / 3
            cellHeight: 100
            model: files

            delegate: Rectangle {
                id: tile
                required property int index
                required property url fileUrl
                required property string fileName
                required property bool fileIsDir
                readonly property bool focused: root.keyboardActive && root.keyboardMode === "files"
                    && root.keyboardIndex === tile.index
                width: grid.cellWidth - 6
                height: grid.cellHeight - 6
                color: Theme.controlBackground(false, focused, hover.hovered)
                border.width: 1
                border.color: Theme.controlBorder(
                    root.wallpaperFor(root.selectedScreen, root.mode) === root.localPath(fileUrl),
                    focused, hover.hovered, root.accent)

                Image {
                    id: preview
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 4 }
                    height: 62
                    visible: !tile.fileIsDir
                    source: tile.fileIsDir ? "" : tile.fileUrl
                    sourceSize.width: 240
                    sourceSize.height: 140
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 20
                    visible: tile.fileIsDir || preview.status === Image.Error
                    text: tile.fileIsDir ? "▸" : "?"
                    color: root.accent
                    font.pixelSize: 28
                }
                Text {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 5 }
                    text: (tile.focused ? "› " : "  ") + tile.fileName
                    elide: Text.ElideRight
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                HoverHandler { id: hover }
                TapHandler {
                    onTapped: {
                        root.keyboardMode = "files"
                        root.keyboardIndex = tile.index
                        if (tile.fileIsDir)
                            files.folder = tile.fileUrl
                        else if (preview.status === Image.Ready)
                            root.selectWallpaper(tile.fileUrl)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: files.count === 0
                text: "No wallpapers in this folder"
                color: Theme.grey1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }

        KeyboardHint {
            id: wallpaperHint
            visible: root.keyboardActive
            text: root.keyboardMode === "screens"
                ? "←/→: monitor · M: dark/light · ↑: parent · ↓: folder · Tab: wallpapers"
                : "Arrows: navigate · Enter: select · M: dark/light · Tab: monitors"
        }
    }
}
