import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./theme"

Item {
    id: root
    required property var panelWindow
    required property var popupCoordinator
    property color accent: Theme.green
    property var wallpapers: ({})
    property var selectedScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    property url wallpaperFolder: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property int keyboardIndex: -1
    property string keyboardMode: "screens"
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    function close() { popup.visible = false }
    function goToParent() {
        if (files.folder.toString() !== root.wallpaperFolder.toString())
            files.folder = files.parentFolder
    }
    function goIntoFolder() {
        // Keep the last file-grid selection when switching back to monitors;
        // otherwise descend into the first folder in the current directory.
        if (keyboardIndex >= 0 && keyboardIndex < files.count
                && files.isFolder(keyboardIndex)) {
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
    function handleKeyPressed(event) {
        const columns = Math.max(1, Math.round(grid.width / grid.cellWidth))
        if (event.key === Qt.Key_Tab) {
            keyboardMode = keyboardMode === "screens" ? "files" : "screens"
            if (keyboardMode === "files" && keyboardIndex < 0 && files.count > 0)
                keyboardIndex = 0
        } else if (event.key === Qt.Key_F) {
            openFolderPicker()
        } else if (keyboardMode === "screens" && event.key === Qt.Key_Up) {
            goToParent()
        } else if (keyboardMode === "screens" && event.key === Qt.Key_Down) {
            goIntoFolder()
        } else if (keyboardMode === "screens" && (event.key === Qt.Key_Left
                || event.key === Qt.Key_Right)) {
            const screens = Quickshell.screens
            if (screens.length > 0) {
                const index = Math.max(0, screens.indexOf(selectedScreen))
                const step = event.key === Qt.Key_Left ? -1 : 1
                selectedScreen = screens[Math.max(0, Math.min(screens.length - 1, index + step))]
            }
        } else if (keyboardMode === "files" && event.key === Qt.Key_Left)
            moveKeyboardSelection(-1)
        else if (keyboardMode === "files" && event.key === Qt.Key_Right)
            moveKeyboardSelection(1)
        else if (keyboardMode === "files" && event.key === Qt.Key_Up)
            moveKeyboardSelection(-columns)
        else if (keyboardMode === "files" && event.key === Qt.Key_Down)
            moveKeyboardSelection(columns)
        else if (keyboardMode === "files" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter))
            activateKeyboardSelection()
        else if (keyboardMode === "files" && event.key === Qt.Key_Backspace)
            goToParent()
        else if (event.key === Qt.Key_Escape)
            close()
        else
            return
        event.accepted = true
    }
    function localPath(fileUrl) {
        return decodeURIComponent(fileUrl.toString()).replace(/^file:\/\//, "")
    }
    function wallpaperFor(screen) {
        return screen && wallpapers[screen.name] ? wallpapers[screen.name] : ""
    }
    function selectWallpaper(fileUrl) {
        if (!selectedScreen)
            return

        const path = localPath(fileUrl)
        const updatedWallpapers = Object.assign({}, wallpapers)
        updatedWallpapers[selectedScreen.name] = path
        wallpapers = updatedWallpapers
        wallpaperSetter.exec([
            "awww", "img",
            "--outputs", selectedScreen.name,
            "--transition-type", "fade",
            "--transition-duration", "0.8",
            path
        ])
    }
    function refreshWallpapers() {
        if (!wallpaperQuery.running)
            wallpaperQuery.exec(["awww", "query"])
    }
    function parseAwwwQuery(output) {
        const current = {}
        for (const line of output.split(/\r?\n/)) {
            const match = line.match(/^: ([^:]+): .*currently displaying: image: (.+)$/)
            if (match)
                current[match[1]] = match[2]
        }
        wallpapers = current
    }
    function openFolderPicker() {
        const currentPath = decodeURIComponent(wallpaperFolder.toString()).replace("file://", "")
        close()
        folderPicker.exec([
            "zenity",
            "--file-selection",
            "--directory",
            "--title=Choose wallpaper folder",
            "--filename=" + currentPath + "/"
        ])
    }
    function toggle() {
        if (popup.visible) {
            close()
        } else {
            popupCoordinator.showPopup(root)
            popup.visible = true
            keyboardMode = "screens"
            keyboardIndex = -1
            refreshWallpapers()
        }
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            if (!root.selectedScreen) {
                root.selectedScreen = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
                return
            }

            for (let i = 0; i < Quickshell.screens.length; ++i) {
                if (Quickshell.screens[i].name === root.selectedScreen.name) {
                    root.selectedScreen = Quickshell.screens[i]
                    return
                }
            }

            root.selectedScreen = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        }
    }

    Text {
        id: icon
        anchors.centerIn: parent
        text: String.fromCodePoint(0xf03e)
        color: root.accent
        font.family: Theme.nerdFontFamily
        font.pixelSize: Theme.fontSize
        TapHandler { onTapped: root.toggle() }
    }

    FolderListModel {
        id: files
        folder: root.wallpaperFolder
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.avif", "*.bmp"]
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
            else if (root.keyboardIndex < 0 && count > 0 && popup.visible)
                root.keyboardIndex = 0
        }
    }

    Process {
        id: folderPicker

        stdout: StdioCollector {
            onStreamFinished: {
                const selectedPath = this.text.replace(/\r?\n$/, "")
                if (selectedPath.length > 0) {
                    root.wallpaperFolder = "file://" + selectedPath
                    Qt.callLater(() => {
                        if (!popup.visible)
                            root.toggle()
                        root.keyboardMode = "files"
                    })
                }
            }
        }
    }

    Process {
        id: wallpaperSetter
    }

    Process {
        id: wallpaperQuery

        stdout: StdioCollector {
            onStreamFinished: root.parseAwwwQuery(this.text)
        }
    }

    PopupWindow {
        id: popup
        visible: false
        implicitWidth: 420
        implicitHeight: 410
        color: "transparent"
        grabFocus: false
        anchor.window: root.panelWindow
        anchor.rect {
            x: root.panelWindow.popupAnchorX(root, popup.implicitWidth, popup.visible)
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
            border.color: root.accent

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "Wallpapers"
                    color: root.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.headingFontSize
                }

                Row {
                    width: parent.width
                    height: folderActions.implicitHeight
                    spacing: 12

                    Text {
                        width: parent.width - folderActions.implicitWidth - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: decodeURIComponent(files.folder.toString()).replace("file://", "")
                        elide: Text.ElideLeft
                        color: Theme.grey1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Row {
                        id: folderActions
                        spacing: 12

                        Text {
                            text: "↑ Up"
                            color: up.enabled ? root.accent : Theme.grey
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            TapHandler {
                                id: up
                                enabled: files.folder.toString() !== root.wallpaperFolder.toString()
                                onTapped: root.goToParent()
                            }
                        }
                        Text {
                            text: "Choose folder  F"
                            color: root.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize

                            TapHandler { onTapped: root.openFolderPicker() }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 24
                    spacing: 6

                    Repeater {
                        model: Quickshell.screens

                        delegate: Rectangle {
                            required property var modelData
                            height: 24
                            width: screenName.implicitWidth + 16
                            color: Theme.bg2
                            border.width: 1
                            border.color: Theme.bg4

                            Text {
                                id: screenName
                                anchors.centerIn: parent
                                text: modelData.name
                                color: root.selectedScreen === modelData ? root.accent : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.underline: root.keyboardMode === "screens"
                                    && root.selectedScreen === modelData
                            }

                            TapHandler { onTapped: root.selectedScreen = modelData }
                        }
                    }
                }

                GridView {
                    id: grid
                    width: parent.width
                    height: 264
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
                        width: grid.cellWidth - 6
                        height: grid.cellHeight - 6
                        color: Theme.bg2
                        border.width: 1
                        border.color: root.wallpaperFor(root.selectedScreen) === root.localPath(fileUrl)
                            ? root.accent : Theme.bg4

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
                            text: tile.fileName
                            elide: Text.ElideRight
                            color: root.keyboardMode === "files"
                                && root.keyboardIndex === tile.index || hover.hovered
                                ? root.accent : Theme.fg
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

                Text {
                    text: root.keyboardMode === "screens"
                        ? "←/→: monitor  ·  ↑: parent  ·  ↓: folder  ·  Tab: wallpapers"
                        : "Arrows: navigate  ·  Enter: select  ·  Tab: monitors  ·  F: folder"
                    color: Theme.grey1
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(10, Theme.fontSize - 2)
                }
            }
        }
    }

    PanelWindow {
        id: dismissLayer
        visible: popup.visible
        anchors { top: true; bottom: true; left: true; right: true }
        margins.top: root.panelWindow.height
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => keyCapture.forceActiveFocus())
        }

        Item {
            id: keyCapture
            anchors.fill: parent
            focus: dismissLayer.visible

            Keys.onPressed: event => root.handleKeyPressed(event)

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }
    }
}
