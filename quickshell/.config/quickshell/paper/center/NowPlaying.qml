pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.common
import qs.services

// What's playing, on an index card: the track in italic Newsreader, the
// artist and album in Kalam, a strip of pencil-hatched bars that dance to
// the sound (cava, only while something plays and the card is showing),
// and ⏮ ⏸ ⏭ written in Kalam.
Sheet {
    id: root

    property bool active: false        // the control centre is open
    readonly property var player: Media.player

    implicitHeight: 196
    seed: 196
    tilt: -1.3
    ruled: true
    ruleTop: 44
    ruleGap: 26

    Column {
        x: 22
        y: 12
        width: root.width - 44
        spacing: 2

        Hand {
            text: "NOW PLAYING" + (root.player?.identity ? " · " + root.player.identity.toUpperCase() : "")
            size: 13
            color: Theme.red
            font.letterSpacing: 13 * 0.06
        }
        Serif {
            width: parent.width
            topPadding: 6
            text: root.player?.trackTitle || "nothing on"
            size: 28
            weight: 400
            font.italic: true
            color: Theme.ink
            elide: Text.ElideRight
        }
        Hand {
            width: parent.width
            text: [root.player?.trackArtist, root.player?.trackAlbum].filter(s => s).join(" · ")
            size: 16
            color: Theme.pencil
            elide: Text.ElideRight
        }

        // cava, hatched
        Item {
            id: bars
            width: parent.width
            height: 46
            visible: levels.length > 0

            property var levels: []
            readonly property int count: 26

            Process {
                running: root.active && Media.playing
                command: ["sh", "-c", `
                    command -v cava >/dev/null || exit 0
                    dir="\${XDG_CACHE_HOME:-$HOME/.cache}/rice"; mkdir -p "$dir"
                    cat > "$dir/cava-paper.conf" <<CONF
[general]
bars = ${bars.count}
framerate = 24
[input]
method = pipewire
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
[smoothing]
noise_reduction = 70
CONF
                    exec cava -p "$dir/cava-paper.conf"`]
                stdout: SplitParser {
                    onRead: line => bars.levels = line.split(";").filter(v => v !== "").map(v => parseInt(v) / 100)
                }
                onRunningChanged: if (!running) bars.levels = []
            }

            Row {
                anchors.bottom: parent.bottom
                spacing: 4
                Repeater {
                    model: bars.levels.length
                    delegate: Item {
                        id: bar
                        required property int index
                        readonly property real level: bars.levels[index] ?? 0
                        width: (bars.width - (bars.count - 1) * 4) / bars.count
                        height: Math.max(2, bars.height * level)
                        anchors.bottom: parent.bottom
                        clip: true
                        Behavior on height { NumberAnimation { duration: 60 } }
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: Theme.hatch
                            border.width: 1.2
                        }
                        Hatch {
                            width: bar.width
                            height: bars.height
                            anchors.bottom: parent.bottom
                            gap: 6
                            color: Qt.alpha(Theme.ink, 0.35)
                        }
                    }
                }
            }
        }

        Row {
            topPadding: 4
            width: parent.width
            Hand {
                width: parent.width / 3
                text: Media.fmt(root.player?.position ?? 0)
                size: 14
                color: Theme.graphite
            }
            Row {
                width: parent.width / 3
                spacing: 14
                Repeater {
                    model: [
                        { t: "⏮", run: () => root.player?.previous() },
                        { t: Media.playing ? "⏸" : "▶", run: () => root.player?.togglePlaying() },
                        { t: "⏭", run: () => root.player?.next() },
                    ]
                    delegate: Hand {
                        required property var modelData
                        text: modelData.t
                        size: 18
                        color: Theme.ink
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.modelData.run()
                        }
                    }
                }
            }
            Hand {
                width: parent.width / 3
                horizontalAlignment: Text.AlignRight
                text: Media.fmt(root.player?.length ?? 0)
                size: 14
                color: Theme.graphite
            }
        }
    }
}
