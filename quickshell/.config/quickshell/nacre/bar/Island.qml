pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.common
import qs.services

// The island in the middle of the bar. With nothing playing it is just the
// active window's title. While something plays it becomes a pill of pearl
// glass holding the cover, the track and a small visualizer, ringed with
// the orient and glowing with it like a focused window's border, the glow
// breathing with the music's beat (Beat.level). Hover widens it to bring
// out play/pause and next; a click drops the full media card below it.
Item {
    id: root

    required property var bar
    required property var monitor
    property real maxWidth: 520

    readonly property bool playing: Media.playing
    readonly property var player: Media.player
    readonly property bool hovered: hover.hovered && playing
    property bool open: false
    onPlayingChanged: if (!playing) open = false

    readonly property var toplevel: Hyprland.activeToplevel
    readonly property string title: toplevel && toplevel.monitor === monitor ? toplevel.title : ""
    readonly property string track: {
        const p = player;
        if (!p) return "";
        return p.trackArtist ? `${p.trackTitle} · ${p.trackArtist}` : (p.trackTitle ?? "");
    }

    // a curve that overshoots a little, like the island settling
    readonly property var spring: Theme.settle

    implicitHeight: 30
    implicitWidth: Math.min(maxWidth, playing ? media.implicitWidth + 12 : idle.implicitWidth + 8)
    Behavior on implicitWidth { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spring } }

    HoverHandler { id: hover }

    // the glow: the orient, blurred, behind the pill; stronger on the beat
    Item {
        id: glow
        anchors.fill: body
        anchors.margins: -3
        opacity: root.playing ? 0.22 + 0.55 * Beat.level : 0
        scale: 1 + 0.035 * Beat.level
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 120 } }
        layer.enabled: visible
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 28
            autoPaddingEnabled: true
        }
        Iridescent {
            anchors.fill: parent
            radius: height / 2
            period: 9000
            sheen: 0
            spinning: root.playing
        }
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: height / 2
        color: root.playing ? Theme.glassStrong : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durFocus } }
    }
    // the rim: the orient running round the pill, as on a focused window
    Iridescent {
        anchors.fill: body
        radius: height / 2
        ring: 1.5
        period: 9000
        sheen: 0.25
        opacity: root.playing ? 0.6 + 0.4 * Beat.level : 0
        visible: opacity > 0.01
        spinning: root.playing
        Behavior on opacity { NumberAnimation { duration: 160 } }
    }

    // nothing playing: the window's title, as the bar has always shown it
    Label {
        id: idle
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.maxWidth - 8)
        text: root.title
        color: Theme.ink
        size: Theme.uiSize + 2
        elide: Text.ElideRight
        opacity: root.playing ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }
    }

    // a few bars of the music, walking along the gradient
    component Bars: Row {
        id: bars
        property int count: 7
        property real tall: 14
        property real thick: 3
        spacing: 2
        height: tall
        Repeater {
            model: bars.count
            delegate: Rectangle {
                required property int index
                readonly property int band: Math.floor(index * Beat.bars / bars.count)
                readonly property real level: Beat.levels[band] ?? 0
                anchors.bottom: parent.bottom
                width: bars.thick
                height: Math.max(bars.thick, bars.tall * level)
                radius: width / 2
                color: Theme.gradient[Math.floor(index / Math.max(1, bars.count - 1) * (Theme.gradient.length - 1))]
                Behavior on height { NumberAnimation { duration: 60 } }
            }
        }
    }

    // a click on the pill drops the card (the buttons, above, take their own)
    MouseArea {
        anchors.fill: parent
        enabled: root.playing
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open = !root.open
    }

    // something playing: cover, track, the bars; hover adds the controls
    Row {
        id: media
        anchors.verticalCenter: parent.verticalCenter
        x: 4
        spacing: 9
        opacity: root.playing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }

        ClippingRectangle {
            id: cover
            width: 22; height: 22
            radius: 11
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.shell
            Image {
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(44, 44)
                asynchronous: true
            }
            Rectangle {               // 92% brightness at night
                anchors.fill: parent
                color: Theme.imageShade
            }
        }

        EdgeFade {
            id: box
            width: Math.min(line.implicitWidth, root.hovered ? 260 : 200)
            height: 26
            anchors.verticalCenter: parent.verticalCenter
            fadeWidth: 18
            active: line.implicitWidth > width
            Behavior on width { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spring } }
            Label {
                id: line
                anchors.verticalCenter: parent.verticalCenter
                text: root.track
                size: Theme.uiSize + 1
                color: Theme.ink
            }
        }

        Bars {
            anchors.verticalCenter: parent.verticalCenter
        }

        // hover: play/pause and next
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            width: root.hovered ? implicitWidth : 0
            clip: true
            opacity: root.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }
            Repeater {
                model: [
                    { icon: Media.playing ? "pause" : "play", run: () => root.player?.togglePlaying() },
                    { icon: "next", run: () => root.player?.next() }
                ]
                delegate: Item {
                    id: ctl
                    required property var modelData
                    width: 24; height: 24
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: ctlTap.containsMouse ? Theme.glassSoft : "transparent"
                    }
                    Icon {
                        anchors.centerIn: parent
                        name: ctl.modelData.icon
                        size: 15
                        color: Theme.ink
                    }
                    MouseArea {
                        id: ctlTap
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ctl.modelData.run()
                    }
                }
            }
        }
    }


    PopupWindow {
        id: popup
        visible: root.open
        anchor.window: root.bar
        anchor.item: root
        anchor.rect.y: root.height + 16
        anchor.rect.x: root.width / 2 - implicitWidth / 2
        implicitWidth: 380
        implicitHeight: card.implicitHeight + big.height + 58
        color: "transparent"
        grabFocus: true
        onVisibleChanged: if (!visible) root.open = false

        Glass {
            anchors.fill: parent
            anchors.margins: 4
            radius: Theme.radiusPopup + 6

            MediaCard {
                id: card
                x: 16; y: 16
                width: parent.width - 32
                artSize: 72
            }
            Bars {
                id: big
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: card.bottom
                anchors.topMargin: 12
                count: 24
                tall: 30
                thick: (parent.width - 32 - 23 * 2) / 24
            }
        }
    }
}
