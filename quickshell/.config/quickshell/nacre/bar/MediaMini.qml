import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.common
import qs.services

// Shown only while something plays: a spinning disc and a marquee title.
// Click opens the media card beneath the bar.
Item {
    id: root

    required property var bar
    readonly property bool shown: Media.playing

    implicitHeight: 26
    implicitWidth: shown ? row.implicitWidth : 0
    clip: true
    opacity: shown ? 1 : 0

    Behavior on implicitWidth { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
    Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        ClippingRectangle {
            id: disc
            width: 22; height: 22
            radius: 11
            color: Theme.shell
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                source: Media.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(44, 44)
                asynchronous: true
            }
            Rectangle {               // 92% brightness at night
                anchors.fill: parent
                color: Theme.imageShade
            }
            Rectangle {
                anchors.centerIn: parent
                width: 5; height: 5; radius: 2.5
                color: Theme.pearl
            }
            RotationAnimator on rotation {
                running: root.shown
                from: disc.rotation
                to: disc.rotation + 360
                duration: 6000
                loops: Animation.Infinite
            }
        }

        // marquee: scrolls only when the title doesn't fit
        EdgeFade {
            id: box
            width: 130
            height: 26
            fadeWidth: 18
            leftFade: line.x < 0 ? 12 : 0
            active: line.implicitWidth > width

            Label {
                id: line
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const p = Media.player;
                    if (!p) return "";
                    return p.trackArtist ? `${p.trackTitle} · ${p.trackArtist}` : p.trackTitle;
                }
                size: Theme.uiSize + 1
                onTextChanged: x = 0

                SequentialAnimation on x {
                    id: marquee
                    running: root.shown && line.implicitWidth > box.width
                    loops: Animation.Infinite
                    PauseAnimation { duration: 1800 }
                    NumberAnimation {
                        to: box.width - line.implicitWidth - 6
                        duration: Math.max(1500, (line.implicitWidth - box.width) * 28)
                        easing.type: Easing.InOutSine
                    }
                    PauseAnimation { duration: 1400 }
                    NumberAnimation { to: 0; duration: 700; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.visible = !popup.visible
    }

    PopupWindow {
        id: popup
        anchor.window: root.bar
        anchor.item: root
        anchor.rect.y: root.height + 18
        anchor.rect.x: root.width / 2 - implicitWidth / 2
        implicitWidth: 360
        implicitHeight: card.implicitHeight + 36
        color: "transparent"
        grabFocus: true

        Glass {
            anchors.fill: parent
            anchors.margins: 4
            radius: Theme.radiusPopup

            MediaCard {
                id: card
                anchors.fill: parent
                anchors.margins: 14
                artSize: 72
            }
        }
    }
}
