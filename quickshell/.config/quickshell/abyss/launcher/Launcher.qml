pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.common
import qs.services

// The launcher (Super+Space): a sheet of glass that drops from the middle of
// the bar, rippling the water as it opens; every key typed lets a small drop
// fall under it. Search in Jura; results are rows with the apps' icons, the
// chosen one marked by a soft teal line of light under its name, never a
// filled block. A leading character picks a mode:
//   =  calculator     /  files (fd)     :  emoji
//   >  shell command  ?  web search     !  clipboard history (Super+V)
PanelWindow {
    id: win

    readonly property bool open: Shell.launcherOpen
    readonly property int maxRows: 7
    readonly property int rowHeight: 48
    readonly property int barBottom: 10 + 34

    screen: Hypr.focusedScreen
    visible: open || sheet.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "abyss-launcher"
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
            // the sheet leaves the bar: a ripple from there
            Reefs.disturb(win.screen, win.width / 2, win.barBottom + 6, 1);
        }
    }
    // the layer surface maps a moment after `open`; keep asking for focus
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
        if (!item.run()) close();
    }

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

    Item {
        id: sheet
        x: Math.round((win.width - width) / 2)
        y: win.barBottom + 10
        width: 620
        height: card.implicitHeight
        clip: true

        // it drops out of the bar on the drift curve and sinks back
        opacity: win.open ? 1 : 0
        property real drop: win.open ? 0 : -28
        transform: Translate { y: sheet.drop }
        Behavior on opacity { NumberAnimation { duration: win.open ? Theme.durOpen : Theme.durClose; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Theme.drift : Theme.sink } }
        Behavior on drop { NumberAnimation { duration: win.open ? Theme.durOpen : Theme.durClose; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Theme.drift : Theme.sink } }
        Behavior on height { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drift } }

        MouseArea { anchors.fill: parent }

        Glass {
            id: card
            anchors.fill: parent
            radius: Theme.radiusPanel
            fill: Theme.glassStrong
            implicitHeight: column.implicitHeight + 32

            Column {
                id: column
                x: 18
                y: 16
                width: parent.width - 36
                spacing: 12

                // the search line
                Item {
                    width: parent.width
                    height: 40

                    Row {
                        id: lead
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Rectangle {
                            height: 26
                            width: search.mode ? modeRow.implicitWidth + 20 : 26
                            radius: 13
                            color: search.mode ? Theme.washOn : "transparent"
                            border.color: search.mode ? Theme.lineOn : "transparent"
                            Behavior on width { NumberAnimation { duration: Theme.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
                            Row {
                                id: modeRow
                                anchors.centerIn: parent
                                spacing: 6
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: search.modeInfo.icon
                                    size: 15
                                    color: search.mode ? Theme.glow : Theme.inkDim
                                }
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: search.mode !== ""
                                    text: search.modeInfo.name
                                    size: 12
                                    weight: Theme.weightStrong
                                }
                            }
                        }
                    }

                    TextField {
                        id: field
                        anchors.left: lead.right
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        placeholderText: search.modeInfo.placeholder
                        placeholderTextColor: Theme.inkDim
                        color: Theme.ink
                        selectionColor: Theme.selection
                        selectedTextColor: Theme.ink
                        font.family: Theme.fontUi
                        font.weight: Theme.weight
                        font.pixelSize: Theme.uiSize + 3
                        font.letterSpacing: 0.6
                        background: null

                        onTextChanged: {
                            if (search.mode === "" && text.length > 0 && search.modeKeys.includes(text[0])) {
                                search.mode = text[0];
                                text = text.slice(1);
                            }
                        }
                        // a key typed: a small drop falls under the sheet
                        onTextEdited: {
                            const along = ((text.length * 0.37) % 1) * 0.8 + 0.1;
                            Reefs.disturb(win.screen, sheet.x + sheet.width * along, sheet.y + sheet.height + 8, 0.15);
                        }

                        // a teal caret, breathing
                        cursorDelegate: Rectangle {
                            id: caret
                            width: 2
                            radius: 1
                            color: Theme.glow
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
                            if (event.key === Qt.Key_Escape) win.close();
                            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) list.step(1);
                            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) list.step(-1);
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.activate(search.results[list.currentIndex]);
                            else if (event.key === Qt.Key_Backspace && text === "" && search.mode !== "") search.mode = "";
                            else return;
                            event.accepted = true;
                        }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Theme.line }

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
                    highlightFollowsCurrentItem: false

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool current: ListView.isCurrentItem

                        width: ListView.view.width
                        height: win.rowHeight

                        opacity: list.fresh ? 0 : 1
                        Component.onCompleted: if (list.fresh) enter.start()
                        SequentialAnimation {
                            id: enter
                            PauseAnimation { duration: row.index * Theme.stagger }
                            ParallelAnimation {
                                NumberAnimation { target: row; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drift }
                                NumberAnimation { target: shift; property: "y"; from: -6; to: 0; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drift }
                            }
                        }
                        transform: Translate { id: shift }

                        Item {
                            id: iconBox
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            IconImage {
                                id: appIcon
                                anchors.centerIn: parent
                                implicitSize: 24
                                visible: (row.modelData.iconName ?? "") !== "" && status === Image.Ready
                                source: row.modelData.iconName ? Quickshell.iconPath(row.modelData.iconName, true) : ""
                                opacity: row.current ? 1 : 0.85
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: (row.modelData.emoji ?? "") !== ""
                                text: row.modelData.emoji ?? ""
                                font.pixelSize: 20
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: !appIcon.visible && !row.modelData.emoji
                                name: row.modelData.glyph ?? "app"
                                size: 17
                                color: row.current ? Theme.glow : Theme.inkDim
                            }
                        }

                        Column {
                            id: words
                            anchors.left: iconBox.right
                            anchors.leftMargin: 12
                            anchors.right: hint.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Label {
                                id: rowTitle
                                width: parent.width
                                text: row.modelData.title
                                size: row.modelData.mono ? Theme.monoSize - 1 : Theme.uiSize + 1
                                weight: row.current ? Theme.weightStrong : Theme.weight
                                elide: Text.ElideRight
                                font.family: row.modelData.mono ? Theme.fontMono : Theme.fontUi
                                color: row.current ? Theme.ink : Theme.ink
                            }
                            Label {
                                width: parent.width
                                visible: text !== ""
                                text: row.modelData.desc ?? ""
                                size: 11.5
                                color: Theme.inkDim
                                elide: Text.ElideMiddle
                            }
                        }

                        // the chosen one: a line of teal light under its name
                        Item {
                            x: words.x
                            y: rowTitle.mapToItem(row, 0, rowTitle.height).y + 1
                            width: Math.min(words.width, rowTitle.implicitWidth + 6)
                            height: 2
                            opacity: row.current ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drift } }
                            Glow {
                                anchors.centerIn: parent
                                width: parent.width + 30
                                height: 16
                                color: Theme.glow
                                opacity: 0.35
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: 1
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Theme.glowAt(0) }
                                    GradientStop { position: 0.15; color: Theme.glow }
                                    GradientStop { position: 0.85; color: Theme.glow }
                                    GradientStop { position: 1; color: Theme.glowAt(0) }
                                }
                            }
                        }

                        Label {
                            id: hint
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.action ?? ""
                            size: 11
                            spacing: 0.1
                            color: Theme.inkDim
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

                Label {
                    width: parent.width
                    visible: list.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    text: search.empty
                    color: Theme.inkDim
                    size: 12.5
                    topPadding: 4
                    bottomPadding: 4
                }

                // the modes, as glass pills
                Flow {
                    width: parent.width
                    spacing: 6
                    visible: search.mode === ""
                    Repeater {
                        model: search.modes
                        delegate: Rectangle {
                            id: pill
                            required property var modelData
                            width: pillRow.implicitWidth + 18
                            height: 24
                            radius: Theme.radiusChip
                            color: pillMouse.containsMouse ? Theme.washHover : Theme.wash
                            border.color: Theme.line
                            Row {
                                id: pillRow
                                anchors.centerIn: parent
                                spacing: 5
                                Label { text: pill.modelData.key; font.family: Theme.fontMono; size: 11.5; color: Theme.glow2 }
                                Label { text: pill.modelData.name; size: 11.5; color: Theme.inkDim }
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
