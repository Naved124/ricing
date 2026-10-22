pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.chars
import qs.common
import qs.services

// The Cast picker (Super+Alt+C): a glass sheet over the dimmed plate,
// "キャスト · Cast", the role it casts (Dancer | Edge mascot, Tab switches),
// and a card for every character there is: built-in or custom, which clips
// it has, and whether it plays the dancer or the mascot now. Each card idles
// live and dances under the pointer. Arrows to move, Enter or a click to cast
// it, Esc to close. "Add from file…" copies a GIF, WebP, PNG or APNG into a
// new folder as its dance (the folder watcher does the rest); "Open folder"
// opens ~/.config/satsuei/characters.
PanelWindow {
    id: win

    readonly property bool open: Shell.castOpen
    readonly property string role: Shell.castRole
    readonly property var cast: Characters.all
    property int current: 0

    function choose(i) {
        const c = cast[i];
        if (!c) return;
        current = i;
        Characters.set(role, c.id);
        Shell.toast("person", `${role === "mascot" ? "Mascot" : "Dancer"}: ${c.name}`);
    }

    screen: Hypr.focusedScreen
    visible: open || veil.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "satsuei-cast"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: if (open) {
        current = Math.max(0, cast.findIndex(c => c.id === Settings.s[Characters.key(role)]));
        keys.forceActiveFocus();
    }

    // a new character from a file: the picker steps aside for the file
    // dialog, then comes back with it in the grid
    Process {
        id: adder
        command: ["sh", "-c", `
            f=$(zenity --file-selection --title="Add a character" \\
                --file-filter="Animations | *.gif *.webp *.png *.apng *.GIF *.WEBP *.PNG *.APNG") || exit 0
            name=$(basename "$f"); ext=$(printf %s "\${name##*.}" | tr '[:upper:]' '[:lower:]')
            id=$(printf %s "\${name%.*}" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9_-'); id=\${id:-character}
            dir="$1/$id"; n=2
            while [ -e "$dir" ]; do dir="$1/$id-$n"; n=$((n + 1)); done
            mkdir -p "$dir" && cp "$f" "$dir/dance.$ext" && basename "$dir"`, "sh", Characters.dir]
        stdout: SplitParser {
            onRead: id => {
                Shell.toast("person", `Added ${id}`);
                Shell.toggleCast(win.role);
            }
        }
    }
    function addFromFile() {
        Shell.castOpen = false;
        adder.running = true;
    }

    // the plate darkens; Hyprland blurs this layer
    Rectangle {
        id: veil
        anchors.fill: parent
        color: Theme.glassDeep
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.open ? Style.durPanelIn : Style.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Style.bloom : Style.sink } }
        MouseArea {
            anchors.fill: parent
            onClicked: Shell.castOpen = false
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const k = event.key, n = win.cast.length, cols = grid.columns;
            if (k === Qt.Key_Escape) Shell.castOpen = false;
            else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) Shell.castRole = win.role === "mascot" ? "dancer" : "mascot";
            else if (k === Qt.Key_Left || k === Qt.Key_H) win.current = (win.current + n - 1) % n;
            else if (k === Qt.Key_Right || k === Qt.Key_L) win.current = (win.current + 1) % n;
            else if (k === Qt.Key_Up || k === Qt.Key_K) win.current = Math.max(0, win.current - cols);
            else if (k === Qt.Key_Down || k === Qt.Key_J) win.current = Math.min(n - 1, win.current + cols);
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) win.choose(win.current);
            else return;
            event.accepted = true;
        }
    }

    Glass {
        id: sheet
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 812)
        height: Math.min(parent.height - 120, 560)
        opacity: veil.opacity
        scale: win.open ? 1 : 0.97
        Behavior on scale { NumberAnimation { duration: win.open ? Style.durOpen : Style.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Style.settle : Style.sink } }

        // clicks on the sheet stay on it
        MouseArea { anchors.fill: parent }

        // ── the header ──────────────────────────────────────────────────────
        Row {
            x: 24
            y: 20
            height: 32
            spacing: 14
            Label {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                size: 22
                spacing: 0.06
                text: "キャスト"
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                size: 15
                weight: Style.weightStrong
                color: Theme.fgDim
                text: "· Cast"
            }
            Item { width: 6; height: 1 }
            Segmented {
                anchors.verticalCenter: parent.verticalCenter
                options: Characters.roles
                value: win.role
                onPicked: v => Shell.castRole = v
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 20
            y: 20
            height: 32
            spacing: 6
            Repeater {
                model: [
                    { icon: "plus", text: "Add from file…", run: () => win.addFromFile() },
                    { icon: "folder", text: "Open folder", run: () => {
                        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && exec xdg-open "$1"', "sh", Characters.dir]);
                        Shell.castOpen = false;
                    } }
                ]
                delegate: Btn {
                    id: action
                    required property var modelData
                    y: 1
                    width: actionRow.implicitWidth + 20
                    height: 30
                    radius: 15
                    color: hovered ? Theme.at(Theme.fg, 0.16) : Theme.tile
                    onClicked: action.modelData.run()
                    Row {
                        id: actionRow
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: action.modelData.icon; size: 14 }
                        Label { anchors.verticalCenter: parent.verticalCenter; text: action.modelData.text; size: 11.5; weight: Style.weightStrong }
                    }
                }
            }
        }
        Rectangle { x: 20; y: 64; width: parent.width - 40; height: 1; color: Theme.rim }

        // ── the cast ────────────────────────────────────────────────────────
        GridView {
            id: grid
            readonly property int columns: Math.max(1, Math.floor(width / cellWidth))
            x: 20 + (parent.width - 40 - columns * cellWidth) / 2
            y: 78
            width: parent.width - 40
            height: parent.height - y - 40
            cellWidth: 148
            cellHeight: 190
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: win.current
            model: win.cast

            delegate: Item {
                id: card
                required property var modelData
                required property int index
                readonly property bool lit: win.current === index
                readonly property bool dancer: Settings.s.dancer === modelData.id
                readonly property bool mascot: Settings.s.mascotChar === modelData.id
                readonly property bool chosen: win.role === "mascot" ? mascot : dancer
                // the clips it has; a built-in moves every way
                readonly property var has: modelData.builtin ? ({ dance: true, idle: true, wave: true, sleep: true })
                                                             : modelData.clips

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: 16
                    color: card.lit ? Theme.at(Theme.fg, 0.11) : Theme.tile
                    border.width: card.chosen ? 2 : 1
                    border.color: card.chosen ? Theme.accent : card.lit ? Theme.rim : Theme.tile
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Actor {
                        x: 14
                        y: 10
                        width: parent.width - 28
                        height: 96
                        cast: card.modelData
                        mode: hover.containsMouse || card.lit ? "dance" : "idle"
                        energy: 0.7
                        running: win.open
                    }

                    // who it plays now
                    Column {
                        x: 8
                        y: 8
                        spacing: 3
                        Repeater {
                            model: [card.dancer ? "Dancer" : "", card.mascot ? "Mascot" : ""].filter(t => t)
                            delegate: Rectangle {
                                id: tag
                                required property string modelData
                                width: tagText.implicitWidth + 10
                                height: 16
                                radius: 8
                                color: Theme.at(Theme.accent, 0.85)
                                Label { id: tagText; anchors.centerIn: parent; text: tag.modelData; size: 9; weight: Style.weightStrong; color: Theme.onAccent }
                            }
                        }
                    }

                    Column {
                        x: 8
                        y: 112
                        width: parent.width - 16
                        spacing: 1
                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: card.modelData.name
                            size: 12.5
                            weight: Style.weightStrong
                        }
                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: card.modelData.ja || " "
                            size: 10
                            color: Theme.fgDim
                        }
                        Item { width: 1; height: 5 }
                        // built-in or custom, and its clips
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 4
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: kind.implicitWidth + 10
                                height: 15
                                radius: 7.5
                                color: "transparent"
                                border.width: 1
                                border.color: card.modelData.builtin ? Theme.rim : Theme.at(Theme.accent2, 0.7)
                                Label {
                                    id: kind
                                    anchors.centerIn: parent
                                    text: card.modelData.builtin ? "built-in" : "custom"
                                    size: 8.5
                                    color: card.modelData.builtin ? Theme.fgDim : Theme.accent2
                                }
                            }
                            Repeater {
                                model: Characters.states
                                delegate: Label {
                                    required property string modelData
                                    height: 15
                                    text: modelData[0].toUpperCase()
                                    mono: true
                                    size: 9
                                    weight: Style.weightStrong
                                    color: card.has[modelData] ? Theme.fg : Theme.at(Theme.fg, 0.25)
                                }
                            }
                        }
                    }
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: win.current = card.index
                    onClicked: win.choose(card.index)
                }
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            text: "←→↑↓ move · Enter cast · Tab role · Esc close"
            size: 10.5
            color: Theme.fgDim
        }
    }
}
