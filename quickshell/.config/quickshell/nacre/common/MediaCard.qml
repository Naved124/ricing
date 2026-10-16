pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs
import qs.services

// Now playing: disc art, title and artist, controls and a scrubbable
// iridescent progress line. Used by the bar's media popup and the control
// centre.
Item {
    id: root

    property var player: Media.player
    property real artSize: 84
    property bool spinArt: true

    implicitWidth: 320
    implicitHeight: layout.implicitHeight

    // MPRIS only reports position on change; ask while playing
    Timer {
        running: !!root.player && root.player.isPlaying && root.visible
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        RowLayout {
            spacing: 14
            Layout.fillWidth: true

            // the disc: art clipped to a circle with a pearl spindle
            Item {
                Layout.preferredWidth: root.artSize
                Layout.preferredHeight: root.artSize

                ClippingRectangle {
                    id: disc
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.shell
                    border.color: Theme.hairline
                    border.width: 1

                    Image {
                        anchors.fill: parent
                        source: root.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(root.artSize * 2, root.artSize * 2)
                    }

                    RotationAnimator on rotation {
                        running: root.spinArt && !!root.player && root.player.isPlaying && root.visible
                        from: disc.rotation
                        to: disc.rotation + 360
                        duration: 12000
                        loops: Animation.Infinite
                    }
                }

                Pearl {
                    anchors.centerIn: parent
                    width: root.artSize * 0.18
                    height: width
                    gloss: 1
                    iri: 0.6
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    Layout.fillWidth: true
                    text: root.player?.trackTitle || "Nothing playing"
                    size: Theme.uiSize + 4
                    weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    text: root.player?.trackArtist ?? ""
                    color: Theme.inkSoft
                    elide: Text.ElideRight
                }

                Row {
                    Layout.topMargin: 6
                    spacing: 6

                    component Control: Item {
                        id: ctl
                        property string icon
                        property bool big: false
                        property bool active: true
                        signal activated()
                        width: big ? 38 : 30
                        height: width
                        opacity: active ? 1 : 0.4

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: ctlMouse.containsMouse ? Theme.glassSoft : (ctl.big ? Theme.pearl : "transparent")
                            border.color: ctl.big ? Theme.hairline : "transparent"
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                        Icon {
                            anchors.centerIn: parent
                            name: ctl.icon
                            size: ctl.big ? 18 : 16
                            color: Theme.ink
                        }
                        MouseArea {
                            id: ctlMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: ctl.active
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ctl.activated()
                        }
                    }

                    Control {
                        icon: "prev"
                        active: !!root.player?.canGoPrevious
                        onActivated: root.player.previous()
                    }
                    Control {
                        big: true
                        icon: root.player?.isPlaying ? "pause" : "play"
                        active: !!root.player?.canTogglePlaying
                        onActivated: root.player.togglePlaying()
                    }
                    Control {
                        icon: "next"
                        active: !!root.player?.canGoNext
                        onActivated: root.player.next()
                    }
                }
            }
        }

        // progress: an iridescent fill on a shell track; drag or click to seek
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            visible: !!root.player && root.player.lengthSupported && root.player.length > 0

            readonly property real fraction: root.player && root.player.length > 0
                ? Math.min(1, root.player.position / root.player.length) : 0

            Rectangle {
                id: track
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 5
                radius: 2.5
                color: Theme.shell
            }
            Iridescent {
                anchors.left: track.left
                anchors.verticalCenter: track.verticalCenter
                height: track.height
                width: Math.max(height, track.width * (seek.pressed ? seek.preview : parent.fraction))
                radius: height / 2
                period: 12000
            }
            Label {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                text: Media.fmt(root.player?.position ?? 0)
                size: Theme.uiSize - 1
                color: Theme.inkSoft
            }
            Label {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: Media.fmt(root.player?.length ?? 0)
                size: Theme.uiSize - 1
                color: Theme.inkSoft
            }
            MouseArea {
                id: seek
                property real preview: 0
                anchors.fill: track
                anchors.margins: -6
                enabled: !!root.player?.canSeek
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: mouse => preview = Math.max(0, Math.min(1, mouse.x / width))
                onPressed: mouse => preview = Math.max(0, Math.min(1, mouse.x / width))
                onReleased: root.player.position = preview * root.player.length
            }
        }
    }
}
