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
        Check {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Shuffle daily"
            checked: Settings.s.shuffleDaily
            onToggled: Settings.s.shuffleDaily = !Settings.s.shuffleDaily
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
