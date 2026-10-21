pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.center
import qs.common
import qs.services

// The island in the middle of the bar. With nothing playing it is the bar's
// "now: <window title>" as always. While something plays a small tab of
// paper is laid on the strip instead: the cover pinned to it like a photo,
// the track typed, the artist pencilled, and a few ink strokes dancing to
// the sound. Under it the desk lamp's warmth (the highlighter's yellow by
// day, the lamp's straw at night, Theme.warmth) swells with the music's beat
// (Beat.level). Hover slides the tab wider for ⏸ and ⏭ in Kalam; a click
// drops the "now playing" index card below it.
Item {
    id: root

    required property var bar
    required property var monitor

    readonly property bool playing: Media.playing
    readonly property var player: Media.player
    readonly property bool hovered: hover.hovered && playing
    property bool open: false
    onPlayingChanged: if (!playing) open = false

    implicitHeight: 34

    // nothing playing: the window's title, as the bar has always shown it
    Title {
        anchors.fill: parent
        monitor: root.monitor
        opacity: root.playing ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }
    }

    Item {
        id: tab
        anchors.centerIn: parent
        width: content.implicitWidth + 28
        height: 32
        opacity: root.playing ? 1 : 0
        visible: opacity > 0
        scale: root.playing ? 1 : 0.92
        Behavior on width { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drop } }
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }
        Behavior on scale { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drop } }

        HoverHandler { id: hover }

        // the lamp's warmth under the tab, swelling with the beat
        Rectangle {
            id: warmth
            anchors.fill: parent
            anchors.margins: -4
            radius: 14
            color: Theme.warmth
            opacity: root.playing ? Theme.mode.blend(0.35, 0.25) + Theme.mode.blend(0.65, 0.5) * Beat.level : 0
            scale: 1 + 0.05 * Beat.level
            Behavior on opacity { NumberAnimation { duration: 120 } }
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: 24
                autoPaddingEnabled: true
            }
        }

        Sheet {
            anchors.fill: parent
            fill: Theme.paper
            seed: 31
            tilt: root.hovered ? 0 : 0.6
            lifted: root.hovered || root.open
            Behavior on tilt { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drop } }
        }

        // a click on the tab drops the card (the controls take their own)
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 9

            // the cover, as a small photo in a card border
            Rectangle {
                width: 24; height: 24
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.card
                border.color: Theme.rule
                rotation: -3
                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    color: Theme.kraft
                    Image {
                        anchors.fill: parent
                        source: root.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(40, 40)
                        asynchronous: true
                    }
                    Rectangle {           // 92% brightness under the lamp
                        anchors.fill: parent
                        color: Theme.imageShade
                    }
                }
            }

            Type {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.hovered ? 240 : 190)
                text: root.player?.trackTitle ?? ""
                size: 13
                weight: 700
                elide: Text.ElideRight
                Behavior on width { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drop } }
            }
            Hand {
                anchors.verticalCenter: parent.verticalCenter
                visible: text.length > 0
                width: Math.min(implicitWidth, 120)
                text: root.player?.trackArtist ?? ""
                size: 15
                elide: Text.ElideRight
            }

            // ink strokes dancing to the sound
            Row {
                anchors.verticalCenter: parent.verticalCenter
                height: 16
                spacing: 2
                Repeater {
                    model: 7
                    delegate: Rectangle {
                        required property int index
                        readonly property real level: Beat.levels[Math.floor(index * Beat.bars / 7)] ?? 0
                        anchors.bottom: parent.bottom
                        width: 2.5
                        height: Math.max(2.5, 16 * level)
                        radius: 1.25
                        color: index === 0 ? Theme.red : Theme.ink
                        Behavior on height { NumberAnimation { duration: 60 } }
                    }
                }
            }

            // hover: ⏸ and ⏭, written in Kalam
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                width: root.hovered ? implicitWidth : 0
                clip: true
                opacity: root.hovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }
                Repeater {
                    model: [
                        { t: Media.playing ? "⏸" : "▶", run: () => root.player?.togglePlaying() },
                        { t: "⏭", run: () => root.player?.next() }
                    ]
                    delegate: Hand {
                        id: ctl
                        required property var modelData
                        text: modelData.t
                        size: 18
                        weight: 700
                        color: ctlTap.containsMouse ? Theme.red : Theme.ink
                        MouseArea {
                            id: ctlTap
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ctl.modelData.run()
                        }
                    }
                }
            }
        }
    }

    PopupWindow {
        visible: root.open
        anchor.window: root.bar
        anchor.item: tab
        anchor.rect.y: tab.height + 14
        anchor.rect.x: tab.width / 2 - implicitWidth / 2
        implicitWidth: 380
        implicitHeight: card.implicitHeight + 30
        color: "transparent"
        grabFocus: true
        onVisibleChanged: if (!visible) root.open = false

        NowPlaying {
            id: card
            x: 12; y: 10
            width: parent.width - 24
            active: root.open
        }
    }
}
