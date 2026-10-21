pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.common
import qs.services
import "binds.js" as Binds

// The key sheet (Super+/): every bind on a big ruled sheet, read live from
// `hyprctl binds -j` (so it never drifts from base.lua or local.lua) and
// grouped by the "Group · what" descriptions. Keys are typewriter keys.
// Type to filter; Esc, Super+/ or a click outside puts it away.
PanelWindow {
    id: win

    readonly property bool open: Shell.keysOpen
    property var all: []
    readonly property var shown: Binds.filter(all, field.text)
    readonly property int columnWidth: 330
    readonly property int columnCount: Math.max(1, Math.min(3, Math.floor((width - 200) / (columnWidth + 40))))

    screen: Hypr.focusedScreen
    visible: open
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "paper-keys"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        if (!open) return;
        field.text = "";
        load.running = true;
        focusTimer.restart();
    }

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

    Process {
        id: load
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { win.all = Binds.groups(JSON.parse(text)); }
                catch (e) { win.all = []; }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        MouseArea {
            anchors.fill: parent
            onClicked: Shell.keysOpen = false
        }
    }

    Sheet {
        id: sheet
        anchors.horizontalCenter: parent.horizontalCenter
        y: 70
        width: win.columnCount * (win.columnWidth + 40) - 40 + 120
        height: parent.height - 120
        seed: 1123
        tilt: -0.4
        ruled: true
        ruleTop: 92
        ruleGap: 28
        margin: true
        marginX: 64

        MouseArea { anchors.fill: parent }

        Serif {
            id: title
            x: 84
            y: 22
            text: "Keys"
            size: 44
            weight: 600
            color: Theme.ink
        }
        Hand {
            anchors.left: title.right
            anchors.leftMargin: 14
            anchors.baseline: title.baseline
            text: "everything your fingers can do"
            size: 17
            color: Theme.graphite
        }

        TextField {
            id: field
            anchors.right: parent.right
            anchors.rightMargin: 40
            y: 30
            width: 300
            height: 40
            leftPadding: 0
            placeholderText: "find: workspace, shift, print…"
            placeholderTextColor: Theme.graphite
            color: Theme.ink
            selectionColor: Theme.highlight
            font.family: Theme.fontHand
            font.pixelSize: 19
            Keys.onEscapePressed: Shell.keysOpen = false
            background: Item {
                Shape {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 2
                    ShapePath {
                        strokeColor: Theme.graphite
                        strokeWidth: 1.5
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [3, 2.5]
                        startX: 0
                        startY: 1
                        PathLine { x: field.width; y: 1 }
                    }
                }
            }
        }

        Flickable {
            id: scroller
            x: 84
            y: 104
            width: parent.width - 84 - 36
            height: parent.height - y - 24
            contentHeight: cols.height + 20
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: cols
                spacing: 40

                Repeater {
                    model: Binds.columns(win.shown, win.columnCount)

                    delegate: Column {
                        id: column
                        required property var modelData
                        width: win.columnWidth
                        spacing: 18

                        Repeater {
                            model: column.modelData

                            delegate: Column {
                                id: group
                                required property var modelData
                                width: win.columnWidth
                                spacing: 6

                                Type {
                                    text: group.modelData.name.toUpperCase()
                                    size: 13
                                    weight: 700
                                    color: Theme.red
                                    font.letterSpacing: 13 * 0.3
                                }

                                Repeater {
                                    model: group.modelData.rows

                                    delegate: Item {
                                        id: row
                                        required property var modelData
                                        width: group.width
                                        height: Math.max(desc.implicitHeight, combos.height)

                                        Hand {
                                            id: desc
                                            anchors.left: parent.left
                                            anchors.right: combos.left
                                            anchors.rightMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: row.modelData.text
                                            size: 16
                                            color: Theme.pencil
                                            elide: Text.ElideRight
                                        }

                                        Row {
                                            id: combos
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 5

                                            Repeater {
                                                model: row.modelData.alts

                                                delegate: Row {
                                                    id: alt
                                                    required property var modelData
                                                    required property int index
                                                    spacing: 3

                                                    Hand {
                                                        visible: alt.index > 0
                                                        text: "or"
                                                        size: 14
                                                        color: Theme.graphite
                                                        rightPadding: 2
                                                    }

                                                    Repeater {
                                                        model: alt.modelData

                                                        // a typewriter key: a dark ring round a pale top
                                                        delegate: Rectangle {
                                                            id: cap
                                                            required property string modelData
                                                            width: Math.max(24, capText.implicitWidth + 14)
                                                            height: 24
                                                            radius: 12
                                                            color: Theme.carbon
                                                            Rectangle {
                                                                anchors.fill: parent
                                                                anchors.margins: 2
                                                                radius: height / 2
                                                                color: Theme.card
                                                            }
                                                            Type {
                                                                id: capText
                                                                anchors.centerIn: parent
                                                                text: cap.modelData
                                                                size: 13
                                                                weight: 700
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Hand {
            anchors.centerIn: scroller
            visible: win.shown.length === 0
            text: win.all.length ? `nothing about “${field.text}”` : "couldn't read the binds from hyprctl"
            size: 18
            color: Theme.graphite
        }
    }
}
