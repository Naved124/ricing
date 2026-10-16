pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// A row of soft bars dancing to whatever is playing, from cava's raw
// output. Runs only while visible and something plays; quietly absent when
// cava isn't installed.
Item {
    id: root

    property bool active: false
    property int bars: 28
    property var levels: []

    implicitHeight: 34
    visible: levels.length > 0

    Process {
        id: cava
        running: root.active
        command: ["sh", "-c", `
            command -v cava >/dev/null || exit 0
            dir="\${XDG_CACHE_HOME:-$HOME/.cache}/rice"; mkdir -p "$dir"
            cat > "$dir/cava.conf" <<CONF
[general]
bars = ${root.bars}
framerate = 30
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
            exec cava -p "$dir/cava.conf"`]
        stdout: SplitParser {
            onRead: line => root.levels = line.split(";").filter(v => v !== "").map(v => parseInt(v) / 100)
        }
        onRunningChanged: if (!running) root.levels = []
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4

        Repeater {
            model: root.levels.length
            delegate: Rectangle {
                id: bar
                required property int index
                readonly property real level: root.levels[index] ?? 0
                width: (root.width - (root.bars - 1) * 4) / root.bars
                height: Math.max(width, root.height * level)
                anchors.bottom: parent.bottom
                radius: width / 2
                // the bars walk along the gradient, left to right
                color: Theme.gradient[Math.floor(index / root.bars * (Theme.gradient.length - 1))]
                border.color: Qt.rgba(1, 1, 1, 0.4)
                Behavior on height { NumberAnimation { duration: 60 } }
            }
        }
    }
}
