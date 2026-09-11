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
    property var wallpapers: ({})
    property var selectedScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    property url wallpaperFolder: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers"
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    function close() { popup.visible = false }
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
        color: Theme.green
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
    }

    Process {
        id: folderPicker

        stdout: StdioCollector {
            onStreamFinished: {
                const selectedPath = this.text.replace(/\r?\n$/, "")
                if (selectedPath.length > 0)
                    root.wallpaperFolder = "file://" + selectedPath
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
        implicitHeight: 390
        color: "transparent"
        grabFocus: false
        anchor.window: root.panelWindow
        anchor.rect {
            x: root.x + root.width / 2 + popup.implicitWidth / 2
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
            color: Theme.bg
            border.width: 2
            border.color: Theme.green

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Row {
                    width: parent.width
                    spacing: 12
                    Text {
                        text: "Wallpapers"
                        color: Theme.green
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    Text {
                        text: "↑ Up"
                        color: up.enabled ? Theme.green : Theme.grey
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        TapHandler {
                            id: up
                            enabled: files.folder.toString() !== root.wallpaperFolder.toString()
                            onTapped: files.folder = files.parentFolder
                        }
                    }
                    Text {
                        text: "Choose folder"
                        color: Theme.green
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize

                        TapHandler { onTapped: root.openFolderPicker() }
                    }
                }

                Text {
                    width: parent.width
                    text: decodeURIComponent(files.folder.toString()).replace("file://", "")
                    elide: Text.ElideLeft
                    color: Theme.grey1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
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
                            color: root.selectedScreen === modelData ? Theme.bggreen : Theme.bg2
                            border.width: 2
                            border.color: root.selectedScreen === modelData ? Theme.green : Theme.bg4

                            Text {
                                id: screenName
                                anchors.centerIn: parent
                                text: modelData.name
                                color: root.selectedScreen === modelData ? Theme.green : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
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
                        required property url fileUrl
                        required property string fileName
                        required property bool fileIsDir
                        width: grid.cellWidth - 6
                        height: grid.cellHeight - 6
                        color: hover.hovered ? Theme.bggreen : Theme.bg2
                        border.width: 2
                        border.color: root.wallpaperFor(root.selectedScreen) === root.localPath(fileUrl) || hover.hovered ? Theme.green : Theme.bg4

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
                            color: Theme.green
                            font.pixelSize: 28
                        }
                        Text {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 5 }
                            text: tile.fileName
                            elide: Text.ElideRight
                            color: tile.fileIsDir ? Theme.green : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        HoverHandler { id: hover }
                        TapHandler {
                            onTapped: {
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
