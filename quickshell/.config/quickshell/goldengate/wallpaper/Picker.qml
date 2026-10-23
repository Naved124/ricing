pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.common
import qs.services

// The wallpaper picker, System Settings' Wallpaper pane as a sheet of its
// own: the picture on screen now at the top (its name, "Dynamic" when it has
// a night twin, how it fills the screen), then every picture in the
// wallpaper folder as a thumbnail, filtered as you type. A click (or Return)
// sets it through `gg wall set`; a pair's night half isn't listed apart.
// Opened from the desktop's menu (right-click), System Settings and
// `gg wall pick`.
Panel {
    id: root

    name: "wallpaper"
    part: "spotlight"
    paneWidth: Math.min((screen ? screen.width : 1920) - 120, 980)
    paneHeight: Math.min((screen ? screen.height : 1080) - 140, 680)
    paneX: ((screen ? screen.width : 1920) - paneWidth) / 2
    paneY: ((screen ? screen.height : 1080) - paneHeight) / 2 + 12
    pane.radius: 26

    readonly property string dir: Walls.url(Settings.wallpaper.dir || "~/Pictures/Wallpapers")
    readonly property string current: Settings.wallpaper.current || ""
    property string query: ""
    // [{ path, name, pair }]
    property var pictures: []

    function stem(p) { return p.replace(/^.*\//, "").replace(/\.[^.]*$/, ""); }
    function pretty(p) { return stem(p).replace(/-(light|dark)$/, "").replace(/[-_]+/g, " ").trim(); }
    function rebuild() {
        const all = [];
        for (let i = 0; i < files.count; i++) all.push(String(files.get(i, "filePath")));
        const stems = new Set(all.map(stem));
        const out = [];
        for (const p of all) {
            const s = stem(p);
            if (s.endsWith("-dark") && stems.has(s.slice(0, -5) + "-light")) continue;
            out.push({ path: p, name: pretty(p), pair: s.endsWith("-light") && stems.has(s.slice(0, -6) + "-dark") });
        }
        pictures = out;
    }
    readonly property var listed: {
        const q = query.trim().toLowerCase();
        return q ? pictures.filter(p => p.name.toLowerCase().includes(q)) : pictures;
    }
    function choose(p) {
        if (!p) return;
        Shell.gg(["wall", "set", p.path]);
    }

    FolderListModel {
        id: files
        folder: root.dir
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"]
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: Qt.callLater(root.rebuild)
        onStatusChanged: if (status === FolderListModel.Ready) Qt.callLater(root.rebuild)
    }

    onShownChanged: if (shown) {
        query = "";
        field.text = "";
        Qt.callLater(() => field.forceActiveFocus());
        grid.currentIndex = Math.max(0, listed.findIndex(p => p.path === current));
        grid.positionViewAtIndex(grid.currentIndex, GridView.Center);
    }

    // the picture on screen now
    Item {
        id: head
        x: 22; y: 22
        width: parent.width - 44
        height: 150
        Rectangle {
            id: now
            width: 240; height: 135; radius: 12
            color: Theme.fill
            clip: true
            Image {
                anchors.fill: parent
                source: Walls.at(Theme.dark)
                sourceSize: Qt.size(480, 270)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            border.width: 1
            border.color: Theme.glassEdge
        }
        Column {
            anchors { left: now.right; leftMargin: 20; verticalCenter: now.verticalCenter }
            spacing: 6
            Label {
                text: root.current ? root.pretty(root.current) : qsTr("No wallpaper")
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.titleSize + 4
                strong: true
            }
            Label {
                text: Settings.wallpaper.currentDark ? qsTr("Dynamic: a light and a dark picture that follow the appearance") : qsTr("Still picture")
                secondary: true
            }
            Row {
                spacing: 6
                topPadding: 6
                Repeater {
                    model: [["fill", qsTr("Fill Screen")], ["fit", qsTr("Fit to Screen")], ["center", qsTr("Center")], ["stretch", qsTr("Stretch")]]
                    delegate: Rectangle {
                        id: fillChip
                        required property var modelData
                        readonly property bool on: (Settings.wallpaper.fill || "fill") === modelData[0]
                        width: chipText.implicitWidth + 22; height: 26; radius: 13
                        color: on ? Theme.accent : (chipMouse.containsMouse ? Theme.fillHover : Theme.fill)
                        Label { id: chipText; anchors.centerIn: parent; text: fillChip.modelData[1]; font.pixelSize: Theme.smallSize; color: fillChip.on ? Theme.onAccent : Theme.label }
                        MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; onClicked: Shell.gg(["set", "wallpaper.fill", "\"" + fillChip.modelData[0] + "\""]) }
                    }
                }
            }
        }
        // the search field
        Rectangle {
            anchors { right: parent.right; top: parent.top }
            width: 220; height: 30; radius: 15
            color: Theme.fill
            border.width: field.activeFocus ? 2 : 0
            border.color: Theme.accentSoft
            Label { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } text: "⌕"; secondary: true }
            TextInput {
                id: field
                anchors { fill: parent; leftMargin: 30; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.label
                font.family: Theme.fontUi
                font.pixelSize: Theme.textSize
                clip: true
                onTextChanged: { root.query = text; grid.currentIndex = 0; }
                Keys.onEscapePressed: Shell.closeAll()
                Keys.onReturnPressed: root.choose(root.listed[grid.currentIndex])
                Keys.onUpPressed: grid.moveCurrentIndexUp()
                Keys.onDownPressed: grid.moveCurrentIndexDown()
                Keys.onLeftPressed: e => { if (text === "") grid.moveCurrentIndexLeft(); else e.accepted = false; }
                Keys.onRightPressed: e => { if (text === "") grid.moveCurrentIndexRight(); else e.accepted = false; }
                Label { anchors.verticalCenter: parent.verticalCenter; visible: !field.text; text: qsTr("Search"); secondary: true }
            }
        }
        Label {
            anchors { right: parent.right; bottom: parent.bottom; bottomMargin: 8 }
            text: qsTr("%1 pictures").arg(root.listed.length)
            secondary: true
            font.pixelSize: Theme.smallSize
        }
    }

    Rectangle { x: 22; y: head.y + head.height + 4; width: parent.width - 44; height: 1; color: Theme.separator }

    GridView {
        id: grid
        x: 16
        y: head.y + head.height + 14
        width: parent.width - 32
        height: parent.height - y - 14
        clip: true
        model: root.listed
        readonly property int columns: Math.max(2, Math.floor(width / 190))
        cellWidth: Math.floor(width / columns)
        cellHeight: cellWidth * 9 / 16 + 34
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false
        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool on: modelData.path === root.current
            readonly property bool lit: GridView.isCurrentItem || hover.containsMouse
            width: grid.cellWidth
            height: grid.cellHeight
            Rectangle {
                id: frame
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                height: width * 9 / 16
                radius: 10
                color: Theme.fill
                border.width: cell.on ? 3 : (cell.lit ? 2 : 1)
                border.color: cell.on ? Theme.accent : (cell.lit ? Theme.accentSoft : Theme.glassEdge)
                scale: hover.containsMouse && !Theme.reduceMotion ? 1.03 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
                Image {
                    anchors { fill: parent; margins: frame.border.width }
                    source: "file://" + cell.modelData.path
                    sourceSize: Qt.size(320, 180)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                }
                // a pair follows the appearance: the sun and moon badge
                Rectangle {
                    visible: cell.modelData.pair
                    anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
                    width: 22; height: 22; radius: 11
                    color: Theme.glassThick
                    Label { anchors.centerIn: parent; text: "◐"; font.pixelSize: 13 }
                }
            }
            Label {
                anchors { left: frame.left; right: frame.right; top: frame.bottom; topMargin: 5 }
                horizontalAlignment: Text.AlignHCenter
                text: cell.modelData.name
                font.pixelSize: Theme.smallSize
                strong: cell.on
                secondary: !cell.on
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                onEntered: grid.currentIndex = cell.index
                onClicked: root.choose(cell.modelData)
            }
        }
    }
}
