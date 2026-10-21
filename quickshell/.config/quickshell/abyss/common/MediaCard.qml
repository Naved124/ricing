pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs
import qs.services

// Now playing: the album art at 92% brightness (it would glare in the dark
// otherwise), title and artist, controls as small glass buttons, a teal
// line for the progress (drag or click it), and the music as plankton.
Item {
    id: root

    property var player: Media.player
    property real artSize: 72

    implicitWidth: 340
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
            Layout.fillWidth: true
            spacing: 14

            ClippingRectangle {
                Layout.preferredWidth: root.artSize
                Layout.preferredHeight: root.artSize
                radius: Theme.radiusPopup
                color: Theme.shoal
                border.color: Theme.line
                border.width: 1
                Image {
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(root.artSize * 2, root.artSize * 2)
                }
                Rectangle {               // 92% brightness
                    anchors.fill: parent
                    color: Qt.alpha(Theme.abyss, 0.08)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    Layout.fillWidth: true
                    text: root.player?.trackTitle || "Nothing playing"
                    size: Theme.uiSize + 1
                    weight: Theme.weightStrong
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    text: root.player?.trackArtist ?? ""
                    color: Theme.inkDim
                    size: Theme.uiSize - 1
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
                        width: big ? 34 : 28
                        height: width
                        opacity: active ? 1 : 0.4
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: ctlMouse.containsMouse ? Theme.washOn : Theme.wash
                            border.color: ctl.big || ctlMouse.containsMouse ? Theme.lineOn : Theme.line
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                        Icon {
                            anchors.centerIn: parent
                            name: ctl.icon
                            size: ctl.big ? 16 : 14
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
                    Control { icon: "prev"; active: !!root.player?.canGoPrevious; onActivated: root.player.previous() }
                    Control { big: true; icon: root.player?.isPlaying ? "pause" : "play"; active: !!root.player?.canTogglePlaying || !!root.player?.canPlay; onActivated: root.player.togglePlaying() }
                    Control { icon: "next"; active: !!root.player?.canGoNext; onActivated: root.player.next() }
                }
            }
        }

        // progress: a teal line of light on a faint track
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            visible: !!root.player && root.player.lengthSupported && root.player.length > 0
            readonly property real fraction: root.player && root.player.length > 0
                ? Math.min(1, root.player.position / root.player.length) : 0

            Rectangle {
                id: track
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 3
                height: 2
                radius: 1
                color: Theme.line
            }
            Rectangle {
                anchors.left: track.left
                anchors.verticalCenter: track.verticalCenter
                height: 2
                width: track.width * (seek.pressed ? seek.preview : parent.fraction)
                radius: 1
                color: Theme.glow
            }
            Glow {
                x: track.width * (seek.pressed ? seek.preview : parent.fraction) - width / 2
                anchors.verticalCenter: track.verticalCenter
                width: 16; height: 16
                color: Theme.glow
            }
            Label {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                text: Media.fmt(root.player?.position ?? 0)
                size: Theme.uiSize - 3
                color: Theme.inkDim
                font.family: Theme.fontMono
            }
            Label {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: Media.fmt(root.player?.length ?? 0)
                size: Theme.uiSize - 3
                color: Theme.inkDim
                font.family: Theme.fontMono
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

        CavaDots {
            Layout.alignment: Qt.AlignHCenter
            count: 28
            tall: 30
            dot: 3
        }
    }
}
