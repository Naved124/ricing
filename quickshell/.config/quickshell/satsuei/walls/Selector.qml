pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.chars
import qs.common
import qs.services

// The wallpaper selector (Super+Ctrl+W): over the dimmed plate, a filmstrip
// of the wallpaper folder across the lower third (the focused card enlarged,
// lifted and glowing in the accent; a shimmer while a picture is still being
// read), and above it a glass panel about the focused one: its name, size
// and whether it moves; its palette (accent, accent 2 and glass large with
// their hex, the six plate swatches; a click copies the hex); a small mock
// of the shell in those colours with the dancer; and its thumbnail with the
// light source found on it.
// Focusing a card fades the real plate (and the whole shell) to it after
// 250 ms; Enter keeps it (satsuei-wall set), Esc goes back to what was there.
// "/" searches by name; the folder chips, the sort (name, date added, colour)
// and auto-rotate sit along the top with Shuffle, Open folder and Change
// folder…. The list is walls/Library.qml.
PanelWindow {
    id: win

    readonly property bool open: Shell.wallsOpen
    readonly property var list: Library.shown
    property int current: 0
    readonly property var focused: list[current] ?? null
    readonly property bool ready: !!focused && !focused.pending && !focused.error
    readonly property int top: 72                 // under the bar, which stays in view

    screen: Hypr.focusedScreen
    visible: open || veil.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "satsuei-walls"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        if (open) {
            focusOn(Math.max(0, Library.indexOf(Library.current)));
            strip.positionViewAtIndex(current, ListView.Center);
            keys.forceActiveFocus();
        } else if (!Library.applying) {
            Theme.endPreview();
        }
    }
    // the picture you're on is kept by its path, so when the list changes
    // under us (the scan adding pictures, a filter) you stay on it; the strip
    // resets to its first card on a new model, so it's put back too
    property string focusedPath: ""
    function focusOn(i) {
        current = Math.max(0, Math.min(list.length - 1, i));
        focusedPath = list[current]?.path ?? "";
    }
    onListChanged: {
        const i = Library.indexOf(focusedPath);
        current = i >= 0 ? i : Math.max(0, Math.min(current, list.length - 1));
        Qt.callLater(() => {
            strip.currentIndex = win.current;
            strip.positionViewAtIndex(win.current, ListView.Center);
        });
    }

    // ── the live preview ───────────────────────────────────────────────────
    onCurrentChanged: if (open) preview.restart()
    Timer {
        id: preview
        interval: 250
        onTriggered: {
            if (!win.open || !win.ready) return;
            if (Theme.previewing?.plate === win.focused.path) return;     // already showing it
            if (win.focused.path === Library.current) Theme.endPreview();
            else Theme.preview(Library.previewTokens(win.focused));
        }
    }
    function choose() {
        if (!ready) return;
        if (focused.path !== Library.current) Library.apply(focused.path);
        Shell.wallsOpen = false;
    }
    function back() {
        Theme.endPreview();
        Shell.wallsOpen = false;
    }
    function move(by) {
        if (!list.length) return;
        focusOn(current + by);
    }
    function copy(hex) {
        Quickshell.execDetached(["wl-copy", hex]);
        Shell.toast("check", `Copied ${hex}`);
    }

    // Change folder…: the selector steps aside for the dialog
    Process {
        id: chooser
        command: ["zenity", "--file-selection", "--directory", "--title=Wallpaper folder", "--filename=" + Library.dir + "/"]
        stdout: SplitParser {
            onRead: line => {
                if (!line) return;
                Settings.s.wallDir = line.replace(Library.home, "~");
                Library.folder = "";
                Shell.toggleWalls();
            }
        }
    }

    // the plate darkens; Hyprland blurs this layer
    Rectangle {
        id: veil
        anchors.fill: parent
        color: Theme.at(Theme.tint, 0.62)
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.open ? Style.durPanelIn : Style.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Style.bloom : Style.sink } }
        MouseArea {
            anchors.fill: parent
            onClicked: win.back()
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Escape) win.back();
            else if (k === Qt.Key_Left || k === Qt.Key_H) win.move(-1);
            else if (k === Qt.Key_Right || k === Qt.Key_L) win.move(1);
            else if (k === Qt.Key_Home) win.focusOn(0);
            else if (k === Qt.Key_End) win.focusOn(win.list.length - 1);
            else if (k === Qt.Key_Return || k === Qt.Key_Enter) win.choose();
            else if (k === Qt.Key_Slash) search.forceActiveFocus();
            else return;
            event.accepted = true;
        }
    }

    Item {
        id: page
        anchors.fill: parent
        opacity: veil.opacity

        // ── along the top ─────────────────────────────────────────────────
        Row {
            x: 40
            y: win.top
            height: 36
            spacing: 14
            Label { y: 2; height: 32; display: true; size: 24; spacing: 0.06; text: "背景" }
            Label { height: 36; size: 15; weight: Style.weightStrong; color: Theme.fgDim; text: "· Wallpapers" }
            Label {
                height: 36
                size: 11.5
                color: Theme.fgDim
                text: Library.scanning ? `reading ${Library.items.filter(w => w.pending).length}…`
                                       : `${win.list.length} of ${Library.items.length}`
            }
            // the search
            Rectangle {
                width: 260
                height: 34
                radius: 17
                color: Theme.tile
                border.width: 1
                border.color: search.activeFocus ? Theme.at(Theme.accent, 0.6) : Theme.rim
                Icon { x: 12; y: 9; name: "search"; size: 16; color: Theme.fgDim }
                TextField {
                    id: search
                    x: 34
                    width: parent.width - 44
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    placeholderText: "/ to search"
                    placeholderTextColor: Theme.fgDim
                    color: Theme.fg
                    selectionColor: Theme.at(Theme.accent, 0.25)
                    selectedTextColor: Theme.fg
                    font.family: Style.fontUi
                    font.pixelSize: 13
                    background: null
                    text: Library.query
                    onTextEdited: Library.query = text
                    Keys.onEscapePressed: { if (text) Library.query = ""; keys.forceActiveFocus(); }
                    Keys.onReturnPressed: keys.forceActiveFocus()
                    Keys.onDownPressed: keys.forceActiveFocus()
                }
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 40
            y: win.top
            height: 36
            spacing: 8
            Repeater {
                model: [
                    { icon: "shuffle", text: "Shuffle", run: () => win.focusOn(Math.floor(Math.random() * win.list.length)) },
                    { icon: "folder", text: "Open folder", run: () => {
                        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && exec xdg-open "$1"', "sh", Library.dir]);
                        win.back();
                    } },
                    { icon: "folder", text: "Change folder…", run: () => { win.back(); chooser.running = true; } }
                ]
                delegate: Btn {
                    id: action
                    required property var modelData
                    y: 2
                    width: actionRow.implicitWidth + 22
                    height: 32
                    radius: 16
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

        // folders, sort, rotation
        Item {
            x: 40
            y: win.top + 48
            width: parent.width - 80
            height: 26
            Segmented {
                visible: Library.folders.length > 0
                options: [{ value: "", text: "All" }].concat(Library.folders.map(f => ({ value: f, text: f })))
                value: Library.folder
                onPicked: v => Library.folder = v
            }
            Row {
                anchors.right: parent.right
                spacing: 14
                Label { height: 26; text: "Sort"; size: 11; color: Theme.fgDim }
                Segmented {
                    options: [{ value: "name", text: "Name" }, { value: "date", text: "Date added" }, { value: "colour", text: "Colour" }]
                    value: Settings.s.sort
                    onPicked: v => Settings.s.sort = v
                }
                Label { height: 26; text: "Rotate"; size: 11; color: Theme.fgDim }
                Segmented {
                    options: [{ value: "off", text: "Off" }, { value: "15m", text: "15m" }, { value: "30m", text: "30m" },
                              { value: "1h", text: "1h" }, { value: "daily", text: "Daily" }]
                    value: Settings.s.rotate
                    onPicked: v => { Settings.s.rotate = v; Settings.s.lastRotate = new Date().toISOString(); }
                }
            }
        }

        // ── the focused one ───────────────────────────────────────────────
        Glass {
            id: info
            visible: !!win.focused
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.top + 98
            width: Math.min(parent.width - 80, 1180)
            height: Math.max(300, strip.y - y - 40)
            MouseArea { anchors.fill: parent }

            readonly property var w: win.focused ?? ({})
            readonly property real pad: 24

            // the thumbnail and the light source on it
            Item {
                id: shot
                x: info.pad
                y: info.pad
                height: info.height - 2 * info.pad
                width: Math.min(height * 16 / 10, info.width * 0.36)
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: Theme.well
                    clip: true
                    Image {
                        id: big
                        anchors.fill: parent
                        source: info.w.thumb ? "file://" + info.w.thumb : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                    }
                    Shimmer { anchors.fill: parent; visible: !!info.w.pending }
                }
                // where satsuei-wall found the light
                Item {
                    visible: win.ready && big.status === Image.Ready
                    readonly property real s: Math.max(shot.width / big.sourceSize.width, shot.height / big.sourceSize.height)
                    x: shot.width / 2 + ((info.w.lightX ?? 0.5) - 0.5) * big.sourceSize.width * s - 9
                    y: shot.height / 2 + ((info.w.lightY ?? 0.5) - 0.5) * big.sourceSize.height * s - 9
                    width: 18; height: 18
                    Glow { anchors.centerIn: parent; width: 64; height: 64; color: Theme.fg; opacity: 0.55 }
                    Rectangle { anchors.fill: parent; radius: 9; color: "transparent"; border.width: 2; border.color: Theme.fg }
                    Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: Theme.fg }
                }
            }

            // name, size, palette
            Column {
                id: about
                x: shot.x + shot.width + 28
                y: info.pad
                width: (info.width - x - info.pad) * 0.56
                spacing: 6
                Label {
                    width: parent.width
                    elide: Text.ElideMiddle
                    display: true
                    size: 20
                    text: (info.w.rel ?? "").split("/").pop()
                }
                Row {
                    spacing: 8
                    Label {
                        height: 18
                        mono: true
                        size: 11.5
                        color: Theme.fgDim
                        text: info.w.width ? `${info.w.width} × ${info.w.height}` : info.w.pending ? "reading…" : info.w.error ?? ""
                    }
                    Rectangle {
                        visible: !!info.w.animated
                        width: anim.implicitWidth + 12
                        height: 18
                        radius: 9
                        color: Theme.at(Theme.accent2, 0.85)
                        Label { id: anim; anchors.centerIn: parent; text: "animated"; size: 9.5; weight: Style.weightStrong; color: Theme.onAccent2 }
                    }
                    Label {
                        visible: win.focused?.path === Library.current
                        height: 18
                        size: 11
                        color: Theme.accent
                        text: "on now"
                    }
                }
                Item { width: 1; height: 10 }
                Label { text: "PALETTE"; size: 10.5; weight: Style.weightStrong; spacing: 0.14; color: Theme.fgDim }
                Row {
                    spacing: 10
                    Repeater {
                        model: [["accent", "accent"], ["accent 2", "accent2"], ["glass", "tint"]]
                        delegate: Column {
                            id: big3
                            required property var modelData
                            readonly property string hex: info.w[modelData[1]] ?? ""
                            spacing: 4
                            Rectangle {
                                width: Math.min(110, (about.width - 20) / 3)
                                height: 64
                                radius: 12
                                color: big3.hex || "transparent"
                                border.width: 1
                                border.color: Theme.rim
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !!big3.hex
                                    onClicked: win.copy(big3.hex)
                                }
                            }
                            Label { text: big3.modelData[0]; size: 11; weight: Style.weightStrong }
                            Label { text: big3.hex; mono: true; size: 10.5; color: Theme.fgDim }
                        }
                    }
                }
                Item { width: 1; height: 4 }
                Row {
                    spacing: 6
                    Repeater {
                        model: info.w.swatches ?? []
                        delegate: Rectangle {
                            id: sw
                            required property string modelData
                            width: 30; height: 30
                            radius: 8
                            color: modelData
                            border.width: 1
                            border.color: Theme.rim
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.copy(sw.modelData)
                            }
                        }
                    }
                }
            }

            // the shell in its colours
            Rectangle {
                id: mock
                anchors.right: parent.right
                anchors.rightMargin: info.pad
                y: info.pad
                width: info.width - about.x - about.width - info.pad - 24
                height: info.height - 2 * info.pad
                radius: 14
                clip: true
                color: info.w.ink ?? "transparent"
                Image {
                    anchors.fill: parent
                    source: big.source
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.85
                }
                // a bar pill with the clock
                Rectangle {
                    x: 10; y: 10
                    width: parent.width - 20
                    height: 24
                    radius: 9
                    color: Theme.at(info.w.tint ?? Theme.tint, 0.62)
                    border.width: 1
                    border.color: Theme.at(info.w.fg ?? Theme.fg, 0.16)
                    Rectangle {
                        x: 6; y: 5
                        width: 22; height: 14; radius: 5
                        color: info.w.accent ?? Theme.accent
                    }
                    Label {
                        anchors.centerIn: parent
                        display: true
                        size: 11
                        color: info.w.fg ?? Theme.fg
                        text: Qt.formatTime(new Date(), "hh:mm")
                    }
                }
                // a control-centre tile, on
                Rectangle {
                    x: 10
                    y: 44
                    width: Math.min(110, parent.width * 0.45)
                    height: 52
                    radius: 11
                    color: Theme.at(info.w.accent ?? Theme.accent, 0.85)
                    Column {
                        x: 9; y: 8
                        Label { text: "Night light"; size: 10.5; weight: Style.weightStrong; color: info.w.onAccent ?? Theme.onAccent }
                        Label { text: "On"; size: 9.5; color: Theme.at(info.w.onAccent ?? Theme.onAccent, 0.7) }
                    }
                }
                // a subtitle
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "CALENDAR"
                        size: 8.5
                        weight: Style.weightStrong
                        spacing: 0.2
                        color: info.w.accent ?? Theme.accent
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Study block starts in 10 minutes."
                        size: 11.5
                        weight: Style.weightStrong
                        color: info.w.fg ?? Theme.fg
                        style: Text.Outline
                        styleColor: Theme.at(info.w.ink ?? Theme.ink, 0.8)
                    }
                }
                // the dancer
                Actor {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    y: 44
                    width: 64
                    height: 86
                    cast: Characters.dancer
                    interval: 66
                    running: win.open
                }
            }
        }

        // nothing to show
        Column {
            visible: win.list.length === 0
            anchors.centerIn: parent
            spacing: 10
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                display: true
                size: 20
                text: Library.scanning ? "Reading the folder…" : Library.items.length ? "Nothing matches" : "No pictures here yet"
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 12.5
                color: Theme.fgDim
                text: Library.error || `${Settings.s.wallDir}: JPG, PNG, WebP, GIF`
            }
        }

        // ── the filmstrip ─────────────────────────────────────────────────
        ListView {
            id: strip
            x: 0
            y: Math.round(parent.height * 0.68)
            width: parent.width
            height: 210
            orientation: ListView.Horizontal
            spacing: 18
            model: win.list
            currentIndex: win.current
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: width / 2 - 120
            preferredHighlightEnd: width / 2 + 120
            highlightMoveDuration: 320
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 1200

            delegate: Item {
                id: card
                required property var modelData
                required property int index
                readonly property bool lit: index === win.current

                width: 240
                height: strip.height
                z: lit ? 2 : 1

                Item {
                    id: face
                    width: 240
                    height: 150
                    y: 30
                    scale: card.lit ? 1.15 : 1
                    transform: Translate { y: card.lit ? -14 : 0; Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.settle } } }
                    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.settle } }

                    Glow {
                        anchors.centerIn: parent
                        width: parent.width * 1.6
                        height: parent.height * 1.9
                        color: Theme.accent
                        opacity: card.lit ? 0.45 : 0
                        Behavior on opacity { NumberAnimation { duration: 260 } }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: Theme.well
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: card.modelData.thumb ? "file://" + card.modelData.thumb : ""
                            sourceSize.width: 320
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Shimmer { anchors.fill: parent; visible: !!card.modelData.pending }
                        Label {
                            visible: !!card.modelData.error
                            anchors.centerIn: parent
                            text: "can't read it"
                            size: 11
                            color: Theme.fgDim
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: "transparent"
                        border.width: card.lit ? 2 : 1
                        border.color: card.lit ? Theme.accent : Theme.rim
                    }
                    // the one on screen now
                    Rectangle {
                        visible: card.modelData.path === Library.current
                        x: 8; y: 8
                        width: 8; height: 8; radius: 4
                        color: Theme.accent
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 192
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    text: card.modelData.rel.split("/").pop()
                    size: 11
                    color: card.lit ? Theme.fg : Theme.fgDim
                    opacity: card.lit ? 1 : 0.8
                }
                MouseArea {
                    anchors.fill: face
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.lit ? win.choose() : win.focusOn(card.index)
                }
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 26
            text: "←→ move · Enter set · / search · Esc back"
            size: 11
            color: Theme.fgDim
        }
    }
}
