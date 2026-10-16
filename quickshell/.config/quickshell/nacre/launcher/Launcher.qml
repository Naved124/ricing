pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.common
import qs.services

// The launcher (Super+Space): a 640-wide frosted card that blooms out of
// the orb and sinks back into it. An Italiana greeting, a pill search field
// with an orchid cursor, and results in pearls; the selected row wears a
// rose→sky wash. A leading character picks a mode:
//   =  calculator     /  files (fd)     :  emoji
//   >  shell command  ?  web search     !  clipboard history (Super+V)
PanelWindow {
    id: win

    readonly property bool open: Shell.launcherOpen
    readonly property int maxRows: 7
    readonly property int rowHeight: 52

    // where the card grows from: the orb, in this screen's coordinates
    readonly property point orb: Shell.orbCenter.x > 0 ? Shell.orbCenter
        : Qt.point(Theme.gapsOut + 6 + 13, 12 + 19)

    screen: Shell.orbScreen ?? Hypr.focusedScreen
    visible: open || !bloom.settled
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nacre-launcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        if (open) {
            field.text = "";
            search.start(Shell.launcherMode);
            field.text = Shell.launcherText;
            field.forceActiveFocus();
            focusTimer.restart();
            list.fresh = true;
            freshTimer.restart();
        }
    }
    // the layer surface maps a moment after `open`, and focus asked for before
    // that can be lost; keep asking until typing lands in the field
    Timer {
        id: focusTimer
        interval: 30
        repeat: true
        property int tries: 0
        onTriggered: {
            field.forceActiveFocus();
            if (field.activeFocus || ++tries > 20) { stop(); tries = 0; }
        }
    }
    Timer { id: freshTimer; interval: 400; onTriggered: list.fresh = false }

    function close() { Shell.launcherOpen = false; }

    function activate(item) {
        if (!item) return;
        const keep = item.run();
        if (!keep) close();
    }

    // click outside: sink back into the orb
    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
    }

    Search {
        id: search
        query: field.text
        limit: win.maxRows
        onResultsChanged: list.currentIndex = 0
        onDone: (icon, msg) => { if (msg) Shell.toast(icon, msg); }
    }

    Bloom {
        id: bloom
        x: (win.width - width) / 2
        y: Math.round(win.height * 0.2)
        width: 640
        height: card.implicitHeight
        shown: win.open
        fromScale: 0.6
        origin: Qt.point(win.orb.x - x, win.orb.y - y)

        Behavior on height { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bloom } }

        // swallow clicks so they don't reach the close area
        MouseArea { anchors.fill: parent }

        Glass {
            id: card
            anchors.fill: parent
            radius: Theme.radiusPanel + 6
            fill: Theme.glassStrong
            implicitHeight: column.implicitHeight + 40

            Column {
                id: column
                x: 24
                y: 22
                width: parent.width - 48
                spacing: 16

                // greeting and date
                Row {
                    width: parent.width
                    spacing: 12

                    Label {
                        id: greeting
                        text: {
                            const h = clock.date.getHours();
                            return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
                        }
                        font.family: Theme.fontDisplay
                        size: 35
                        weight: Theme.weightDisplay
                    }
                    Label {
                        anchors.baseline: greeting.baseline
                        text: Qt.formatDate(clock.date, "dddd, d MMMM")
                        font.capitalization: Font.SmallCaps
                        font.letterSpacing: 1.2
                        color: Theme.inkSoft
                        size: Theme.uiSize + 2
                    }
                    SystemClock { id: clock; precision: SystemClock.Minutes }
                }

                // the search pill
                Rectangle {
                    width: parent.width
                    height: 46
                    radius: height / 2
                    color: Theme.glassSoft
                    border.color: field.activeFocus ? Theme.orchid : Theme.hairline
                    border.width: field.activeFocus ? 1.5 : 1
                    Behavior on border.color { ColorAnimation { duration: Theme.durFocus } }

                    Row {
                        id: lead
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        // the mode, as a small pearl chip; plain search shows a glass
                        Rectangle {
                            height: 30
                            width: search.mode ? modeRow.implicitWidth + 22 : 30
                            radius: 15
                            color: search.mode ? Theme.shell : "transparent"
                            border.color: search.mode ? Theme.hairline : "transparent"
                            Behavior on width { NumberAnimation { duration: Theme.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

                            Row {
                                id: modeRow
                                anchors.centerIn: parent
                                spacing: 6
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: search.modeInfo.icon
                                    size: 16
                                    color: search.mode ? Theme.ink : Theme.inkSoft
                                }
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: search.mode !== ""
                                    text: search.modeInfo.name
                                    size: Theme.uiSize
                                    weight: Theme.weightStrong
                                }
                            }
                        }
                    }

                    TextField {
                        id: field
                        anchors.left: lead.right
                        anchors.right: parent.right
                        anchors.leftMargin: 4
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        placeholderText: search.modeInfo.placeholder
                        placeholderTextColor: Theme.inkSoft
                        color: Theme.ink
                        selectionColor: Theme.sky
                        selectedTextColor: Theme.ink
                        font.family: Theme.fontUi
                        font.weight: Theme.weight
                        font.pixelSize: Theme.uiSize + 4
                        background: null

                        // a mode character typed first becomes the chip
                        onTextChanged: {
                            if (search.mode === "" && text.length > 0 && search.modeKeys.includes(text[0])) {
                                search.mode = text[0];
                                text = text.slice(1);
                            }
                        }

                        // an orchid beam that breathes rather than blinks
                        cursorDelegate: Rectangle {
                            id: caret
                            width: 2
                            radius: 1
                            color: Theme.orchid
                            visible: field.activeFocus
                            SequentialAnimation on opacity {
                                running: caret.visible
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 650; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
                            }
                        }

                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            if (event.key === Qt.Key_Escape) {
                                win.close();
                            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_J) || (ctrl && event.key === Qt.Key_N)) {
                                list.step(1);
                            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && event.key === Qt.Key_K) || (ctrl && event.key === Qt.Key_P)) {
                                list.step(-1);
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                win.activate(search.results[list.currentIndex]);
                            } else if (event.key === Qt.Key_Backspace && text === "" && search.mode !== "") {
                                search.mode = "";   // leave the mode
                            } else {
                                return;
                            }
                            event.accepted = true;
                        }
                    }
                }

                // results
                ListView {
                    id: list

                    property bool fresh: false

                    function step(by) {
                        if (count === 0) return;
                        currentIndex = (currentIndex + by + count) % count;
                    }

                    width: parent.width
                    height: Math.min(count, win.maxRows) * win.rowHeight
                    visible: count > 0
                    interactive: false
                    clip: true
                    model: search.results
                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 180
                    highlightMoveVelocity: -1
                    highlightResizeDuration: 0

                    // the selection: a soft rose→sky wash
                    highlight: Rectangle {
                        radius: 14
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.washFrom }
                            GradientStop { position: 1; color: Theme.washTo }
                        }
                        border.color: Theme.hairline
                    }

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool current: ListView.isCurrentItem

                        width: ListView.view.width
                        height: win.rowHeight

                        // a 30 ms stagger when the launcher first opens
                        opacity: list.fresh ? 0 : 1
                        Component.onCompleted: if (list.fresh) enter.start()
                        SequentialAnimation {
                            id: enter
                            PauseAnimation { duration: row.index * Theme.stagger }
                            ParallelAnimation {
                                NumberAnimation { target: row; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bloom }
                                NumberAnimation { target: shift; property: "y"; from: 8; to: 0; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bloom }
                            }
                        }
                        transform: Translate { id: shift }

                        Item {
                            id: pearlBox
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 38
                            height: 38

                            Pearl {
                                anchors.fill: parent
                                gloss: row.current ? 0.75 : 0.45
                                iri: row.current ? 0.45 : 0
                            }
                            IconImage {
                                id: appIcon
                                anchors.centerIn: parent
                                implicitSize: 22
                                visible: (row.modelData.iconName ?? "") !== "" && status === Image.Ready
                                source: row.modelData.iconName ? Quickshell.iconPath(row.modelData.iconName, true) : ""
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: (row.modelData.emoji ?? "") !== ""
                                text: row.modelData.emoji ?? ""
                                font.pixelSize: 21
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: !appIcon.visible && !row.modelData.emoji
                                name: row.modelData.glyph ?? "app"
                                size: 18
                                color: Theme.ink
                            }
                        }

                        Column {
                            anchors.left: pearlBox.right
                            anchors.leftMargin: 14
                            anchors.right: hint.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Label {
                                width: parent.width
                                text: row.modelData.title
                                size: row.modelData.mono ? Theme.monoSize + 1 : Theme.uiSize + 3
                                weight: row.modelData.mono ? Theme.weight : Theme.weightStrong
                                elide: Text.ElideRight
                                font.family: row.modelData.mono ? Theme.fontMono : Theme.fontUi
                            }
                            Label {
                                width: parent.width
                                visible: text !== ""
                                text: row.modelData.desc ?? ""
                                size: Theme.uiSize
                                color: Theme.inkSoft
                                elide: Text.ElideMiddle
                            }
                        }

                        Label {
                            id: hint
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.action ?? ""
                            size: Theme.uiSize - 1
                            color: Theme.inkSoft
                            opacity: row.current ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: list.currentIndex = row.index
                            onClicked: win.activate(row.modelData)
                        }
                    }
                }

                // nothing found / an error from the calculator
                Label {
                    width: parent.width
                    visible: list.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    text: search.empty
                    color: Theme.inkSoft
                    size: Theme.uiSize + 1
                    topPadding: 4
                    bottomPadding: 4
                }

                // the modes, as pills you can click
                Flow {
                    width: parent.width
                    spacing: 6
                    visible: search.mode === ""

                    Repeater {
                        model: search.modes
                        delegate: Rectangle {
                            id: pill
                            required property var modelData
                            width: pillRow.implicitWidth + 20
                            height: 26
                            radius: 13
                            color: pillMouse.containsMouse ? Theme.pearl : "transparent"
                            border.color: Theme.hairline
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                id: pillRow
                                anchors.centerIn: parent
                                spacing: 5
                                Label { text: pill.modelData.key; font.family: Theme.fontMono; size: Theme.uiSize; weight: Theme.weightStrong; color: Theme.ink }
                                Label { text: pill.modelData.name; size: Theme.uiSize; color: Theme.inkSoft }
                            }
                            MouseArea {
                                id: pillMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { search.mode = pill.modelData.key; field.forceActiveFocus(); }
                            }
                        }
                    }
                }
            }
        }
    }
}
