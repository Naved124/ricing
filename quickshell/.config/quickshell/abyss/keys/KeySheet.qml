pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.common
import qs.services
import "binds.js" as Binds

// The key sheet (Super+/): every bind, grouped as cards of glass, read live from
// `hyprctl binds -j` so it never drifts from base.lua or local.lua.
// Type to filter; Esc, Super+/ or a click outside closes it.
PanelWindow {
    id: win

    readonly property bool open: Shell.keysOpen
    property var all: []
    readonly property var shown: Binds.filter(all, field.text)
    readonly property int columnWidth: 340
    readonly property int columnCount: Math.max(1, Math.min(3, Math.floor((width - 120) / (columnWidth + 28))))

    screen: Hypr.focusedScreen
    visible: open || veil.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "abyss-keys"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        if (!open) return;
        field.text = "";
        load.running = true;
        focusTimer.restart();
    }

    // the surface maps a moment after `open`; keep asking until the field has focus
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
        id: veil
        anchors.fill: parent
        color: Theme.glass
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.open ? Theme.durPanelIn : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Theme.drift : Theme.sink } }

        MouseArea {
            anchors.fill: parent
            onClicked: Shell.keysOpen = false
        }
    }

    Item {
        id: sheet
        anchors.horizontalCenter: parent.horizontalCenter
        y: 80
        width: win.columnCount * (win.columnWidth + 28) - 28
        height: parent.height - 120
        opacity: veil.opacity
        property real rise: win.open ? 0 : 18
        transform: Translate { y: sheet.rise }
        Behavior on rise { NumberAnimation { duration: win.open ? Theme.durOpen : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Theme.settle : Theme.sink } }

        // clicks on the sheet itself shouldn't close it
        MouseArea { anchors.fill: parent }

        Label {
            id: title
            text: "KEYS"
            font.family: Theme.fontDisplay
            size: 30
            weight: Theme.weightDisplay
            spacing: 0.24
        }

        // the filter: a pill on the title's line
        Rectangle {
            id: pill
            anchors.right: parent.right
            anchors.verticalCenter: title.verticalCenter
            width: 300
            height: 38
            radius: height / 2
            color: Theme.glassStrong
            border.color: field.activeFocus ? Theme.lineOn : Theme.line
            border.width: field.activeFocus ? 1.5 : 1

            Icon {
                id: lens
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 15
                color: Theme.inkDim
            }

            TextField {
                id: field
                anchors.left: lens.right
                anchors.right: parent.right
                anchors.leftMargin: 6
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                placeholderText: "Filter: “workspace”, “shift”, “print”…"
                placeholderTextColor: Theme.inkDim
                color: Theme.ink
                selectionColor: Theme.selection
                font.family: Theme.fontUi
                font.weight: Theme.weight
                font.pixelSize: Theme.uiSize + 3
                background: null
                Keys.onEscapePressed: Shell.keysOpen = false
            }
        }

        Flickable {
            id: scroller
            anchors.top: title.bottom
            anchors.topMargin: 26
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            contentHeight: cols.height + 20
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: cols
                spacing: 28

                Repeater {
                    model: Binds.columns(win.shown, win.columnCount)

                    delegate: Column {
                        id: column
                        required property var modelData
                        width: win.columnWidth
                        spacing: 22

                        Repeater {
                            model: column.modelData

                            delegate: Glass {
                                id: card
                                required property var modelData
                                width: win.columnWidth
                                height: body.height + 28
                                radius: Theme.radiusPopup
                                fill: Theme.glassStrong

                                Column {
                                    id: body
                                    x: 16
                                    y: 14
                                    width: parent.width - 32
                                    spacing: 9

                                    Label {
                                        text: card.modelData.name.toUpperCase()
                                        size: 11
                                        weight: Theme.weightStrong
                                        color: Theme.glow2
                                        spacing: 0.18
                                        bottomPadding: 2
                                    }

                                    Repeater {
                                        model: card.modelData.rows

                                        delegate: Item {
                                            id: row
                                            required property var modelData
                                            width: body.width
                                            height: Math.max(desc.implicitHeight, combos.height)

                                            Label {
                                                id: desc
                                                anchors.left: parent.left
                                                anchors.right: combos.left
                                                anchors.rightMargin: 12
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: row.modelData.text
                                                elide: Text.ElideRight
                                            }

                                            Row {
                                                id: combos
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 6

                                                Repeater {
                                                    model: row.modelData.alts

                                                    delegate: Row {
                                                        id: alt
                                                        required property var modelData
                                                        required property int index
                                                        spacing: 4

                                                        Label {
                                                            visible: alt.index > 0
                                                            text: "or"
                                                            size: Theme.uiSize
                                                            color: Theme.inkDim
                                                            height: 24
                                                            rightPadding: 2
                                                        }

                                                        Repeater {
                                                            model: alt.modelData

                                                            delegate: Rectangle {
                                                                id: cap
                                                                required property string modelData
                                                                width: Math.max(24, capText.implicitWidth + 14)
                                                                height: 24
                                                                radius: 7
                                                                color: Theme.shoal
                                                                border.color: Theme.line
                                                                border.width: 1

                                                                // a keycap's lower lip
                                                                Rectangle {
                                                                    anchors.left: parent.left
                                                                    anchors.right: parent.right
                                                                    anchors.bottom: parent.bottom
                                                                    anchors.margins: 1
                                                                    height: 3
                                                                    radius: 6
                                                                    color: Theme.deep
                                                                }

                                                                Text {
                                                                    id: capText
                                                                    anchors.centerIn: parent
                                                                    anchors.verticalCenterOffset: -1
                                                                    text: cap.modelData
                                                                    color: Theme.ink
                                                                    font.family: Theme.fontMono
                                                                    font.pixelSize: Theme.uiSize + 0.5
                                                                    font.weight: Theme.weight
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
        }

        Label {
            anchors.centerIn: scroller
            visible: win.shown.length === 0
            text: win.all.length ? `Nothing matches “${field.text}”` : "Couldn't read the binds from hyprctl"
            color: Theme.inkDim
        }
    }
}
