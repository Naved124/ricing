pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.common
import qs.services

// What's playing, the mock's card: the cover (or the accent's light with the
// title's first character when there's none), title and artist, 30 cava bars
// rising from accent 2 into the accent, the progress with its times, and
// previous / play-pause / next. Above its top right edge is the stage the
// dancer stands on (chars/, from step 7): `stage`, 112 × 128, its feet 16 px
// down onto the card.
Rectangle {
    id: root

    readonly property var player: Media.player
    readonly property bool playing: Media.playing
    property alias stage: stage

    implicitHeight: col.implicitHeight + 24
    radius: 18
    color: Theme.at(Theme.ink, 0.18)
    border.color: Theme.at(Theme.fg, 0.08)
    border.width: 1

    // MPRIS only reports the position on a change; ask while playing
    Timer {
        interval: 500
        repeat: true
        running: root.playing && root.visible
        onTriggered: root.player?.positionChanged()
    }

    Item {
        id: stage
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.bottom: parent.top
        anchors.bottomMargin: -16
        width: 112
        height: 128
        z: 2
    }

    Column {
        id: col
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 10

        Row {
            spacing: 12
            width: parent.width
            // the cover
            ClippingRectangle {
                id: cover
                width: 76; height: 76
                radius: 13
                color: Theme.tint
                // no art: the accent's light in two corners and the title's first character
                Rectangle {
                    anchors.fill: parent
                    visible: art.status !== Image.Ready
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0; color: Theme.at(Theme.accent, 0.85) }
                        GradientStop { position: 0.6; color: Theme.at(Theme.accent2, 0.35) }
                        GradientStop { position: 1; color: Theme.ink }
                    }
                    Label {
                        anchors.centerIn: parent
                        text: (root.player?.trackTitle ?? "♪").slice(0, 1)
                        display: true
                        size: 30
                        color: Theme.at(Theme.fg, 0.92)
                    }
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(152, 152)
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - cover.width - 12 - 96        // the dancer stands over the right
                spacing: 2
                Label {
                    width: parent.width
                    text: root.player?.trackTitle || "Nothing playing"
                    size: 15
                    weight: 800
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    lineHeight: 1.1
                }
                Label {
                    width: parent.width
                    text: root.player?.trackArtist ?? ""
                    color: Theme.fgDim
                    elide: Text.ElideRight
                }
            }
        }

        // the bars
        Row {
            width: parent.width
            height: 34
            spacing: 3
            Repeater {
                model: Beat.bars
                delegate: Rectangle {
                    required property int index
                    readonly property real v: root.playing ? Math.min(1, Beat.levels[index] ?? 0) : 0
                    anchors.bottom: parent.bottom
                    width: (parent.width - 3 * (Beat.bars - 1)) / Beat.bars
                    height: Math.max(2, 34 * (0.04 + 0.96 * v))
                    topLeftRadius: 3; topRightRadius: 3
                    bottomLeftRadius: 1; bottomRightRadius: 1
                    opacity: 0.85
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.accent }
                        GradientStop { position: 1; color: Theme.at(Theme.accent2, 0.7) }
                    }
                    Behavior on height { NumberAnimation { duration: 70 } }
                }
            }
        }

        // the progress
        Row {
            width: parent.width
            spacing: 8
            Label {
                id: cur
                anchors.verticalCenter: parent.verticalCenter
                text: Media.fmt(root.player?.position ?? 0)
                mono: true
                size: 10.5
                color: Theme.fgDim
            }
            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - cur.width - len.width - 16
                height: 4
                radius: 2
                color: Theme.track
                readonly property real frac: root.player && root.player.length > 0
                    ? Math.min(1, root.player.position / root.player.length) : 0
                Rectangle {
                    width: parent.width * parent.frac
                    height: parent.height
                    radius: 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.accent2 }
                        GradientStop { position: 1; color: Theme.accent }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: !!root.player?.canSeek
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => root.player.position = Math.max(0, Math.min(1, mouse.x / track.width)) * root.player.length
                }
            }
            Label {
                id: len
                anchors.verticalCenter: parent.verticalCenter
                text: Media.fmt(root.player?.length ?? 0)
                mono: true
                size: 10.5
                color: Theme.fgDim
            }
        }

        // the controls
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                width: 36; height: 36; radius: 18
                onClicked: root.player?.previous()
                Icon { anchors.centerIn: parent; name: "prev" }
            }
            Item {
                width: 46; height: 46
                RectangularShadow {
                    anchors.fill: play
                    radius: 23
                    blur: 22
                    spread: -4
                    color: Theme.accent
                }
                Rectangle {
                    id: play
                    anchors.fill: parent
                    radius: 23
                    color: Theme.accent
                    Icon {
                        anchors.centerIn: parent
                        name: root.playing ? "pause" : "play"
                        size: 18
                        stroke: 2.4
                        color: Theme.onAccent
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.player?.togglePlaying()
                    }
                }
            }
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                width: 36; height: 36; radius: 18
                onClicked: root.player?.next()
                Icon { anchors.centerIn: parent; name: "next" }
            }
        }
    }
}
