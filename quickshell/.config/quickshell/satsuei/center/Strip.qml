pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.chars
import qs.common
import qs.services

// The character strip under the media card: which role it casts (Dancer |
// Edge mascot; each keeps its own choice), Shuffle daily, and a row of tiles,
// every character there is (the five built-ins, then the user's own, each
// idling live while the centre is open) and "+ Add", which opens the
// characters folder. A click casts that character in the role.
Column {
    id: root

    property bool open: false
    property string role: "dancer"
    readonly property string current: root.role === "mascot" ? Settings.s.mascotChar : Settings.s.dancer

    spacing: 8

    Item {
        width: parent.width
        height: 26

        // the role
        Segmented {
            anchors.verticalCenter: parent.verticalCenter
            options: Characters.roles
            value: root.role
            onPicked: v => root.role = v
        }

        // shuffle daily
        Btn {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: shuffle.implicitWidth + 16
            height: 26
            radius: 13
            onClicked: Settings.s.shuffleDaily = !Settings.s.shuffleDaily
            Row {
                id: shuffle
                anchors.centerIn: parent
                spacing: 6
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14
                    radius: 4
                    color: Settings.s.shuffleDaily ? Theme.at(Theme.accent, 0.85) : "transparent"
                    border.width: Settings.s.shuffleDaily ? 0 : 1.2
                    border.color: Theme.fgDim
                    Icon {
                        anchors.centerIn: parent
                        visible: Settings.s.shuffleDaily
                        name: "check"
                        size: 11
                        stroke: 2.6
                        color: Theme.onAccent
                    }
                }
                Label { anchors.verticalCenter: parent.verticalCenter; text: "Shuffle daily"; size: 11; color: Theme.fgDim }
            }
        }
    }

    EdgeFade {
        width: parent.width
        height: 104
        fadeWidth: 24
        active: list.contentWidth > list.width && !list.atXEnd

        ListView {
            id: list
            anchors.fill: parent
            orientation: ListView.Horizontal
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: Characters.all.concat([{ id: "+add" }])

            delegate: Rectangle {
                id: tile
                required property var modelData
                readonly property bool add: modelData.id === "+add"
                readonly property bool chosen: modelData.id === root.current

                width: 76
                height: 104
                radius: 14
                color: mouse.containsMouse ? Theme.at(Theme.fg, 0.1) : Theme.tile
                border.width: chosen ? 2 : 1
                border.color: chosen ? Theme.accent : Theme.tile
                Behavior on color { ColorAnimation { duration: 200 } }

                Actor {
                    visible: !tile.add
                    x: 8
                    y: 6
                    width: parent.width - 16
                    height: 62
                    cast: tile.add ? Characters.builtins[0] : tile.modelData
                    interval: 66
                    running: root.open && !tile.add
                }
                Icon {
                    visible: tile.add
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 24
                    name: "plus"
                    size: 22
                    color: Theme.fgDim
                }
                Column {
                    x: 6
                    y: 72
                    width: parent.width - 12
                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: tile.add ? "Add" : tile.modelData.name
                        size: 11
                        weight: Style.weightStrong
                    }
                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: tile.add ? "your own" : tile.modelData.ja || "custom"
                        size: 9.5
                        color: Theme.fgDim
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (tile.add) {
                            Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && exec xdg-open "$1"', "sh", Characters.dir]);
                            Shell.centerOpen = false;
                            return;
                        }
                        Characters.set(root.role, tile.modelData.id);
                        Shell.toast("person", `${root.role === "mascot" ? "Mascot" : "Dancer"}: ${tile.modelData.name}`);
                    }
                }
            }
        }
    }
}
