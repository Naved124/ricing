pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.common
import qs.services

// The island grown into a card: what's playing with its cover, the time,
// the controls, the music's shape from the shell's one cava (Beat), and
// Spotify's synced lyrics (Lyrics), the line being sung bright between the
// one before and the one after. A click outside or Esc folds it back.
PanelWindow {
    id: root

    // the screen's name, given once (reading `screen` here loops as the window maps)
    property string at: ""
    readonly property bool shown: Shell.open === "island" && (Shell.openScreen === "" || at === "" || Shell.openScreen === at)
    readonly property var player: Media.player
    readonly property color ink: Theme.onWallpaper
    property real position: 0

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "goldengate:island"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: shown || card.opacity > 0.01

    Binding { target: Lyrics; property: "wanted"; value: root.shown }
    Timer {
        running: root.shown && !!root.player
        interval: 500; repeat: true; triggeredOnStart: true
        onTriggered: { root.player.positionChanged(); root.position = root.player.position; }
    }

    MouseArea { anchors.fill: parent; onClicked: Shell.closeAll() }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: 3
        width: root.shown ? 440 : 340
        height: root.shown ? body.implicitHeight + 36 : 26
        radius: root.shown ? 34 : 13
        color: Theme.island
        clip: true
        opacity: root.shown ? 1 : 0
        focus: root.shown
        Keys.onEscapePressed: Shell.closeAll()
        Behavior on width { SpringAnimation { spring: Theme.spring; damping: Theme.damping } }
        Behavior on height { SpringAnimation { spring: Theme.spring; damping: Theme.damping } }
        Behavior on radius { NumberAnimation { duration: Theme.panelIn } }
        Behavior on opacity { NumberAnimation { duration: root.shown ? 80 : Theme.panelOut } }
        MouseArea { anchors.fill: parent }

        Column {
            id: body
            x: 18; y: 18
            width: 440 - 36
            spacing: 14
            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.panelIn } }

            Row {
                width: parent.width
                spacing: 14
                ClippingRectangle {
                    width: 72; height: 72; radius: 14
                    color: Theme.graphite
                    Image { anchors.fill: parent; source: root.player ? root.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                }
                Column {
                    width: parent.width - 72 - 14 - bars.width - 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Label { width: parent.width; text: root.player ? root.player.trackTitle || qsTr("Not Playing") : qsTr("Not Playing"); color: root.ink; strong: true; font.pixelSize: Theme.textSize + 1 }
                    Label { width: parent.width; text: root.player ? root.player.trackArtist || root.player.identity || "" : ""; color: root.ink; opacity: 0.6 }
                }
                // the music's shape: twelve of cava's bands
                Row {
                    id: bars
                    anchors.verticalCenter: parent.verticalCenter
                    height: 28
                    spacing: 2
                    Repeater {
                        model: 12
                        delegate: Rectangle {
                            required property int index
                            readonly property real v: Beat.live ? Beat.levels[index * 2] : 0.06
                            anchors.bottom: parent.bottom
                            width: 3; radius: 1.5
                            height: Math.max(3, v * 28)
                            color: Theme.accent
                            Behavior on height { NumberAnimation { duration: 60 } }
                        }
                    }
                }
            }

            // where the track is
            Column {
                width: parent.width
                spacing: 4
                visible: !!root.player && root.player.length > 0
                Item {
                    width: parent.width; height: 5
                    Rectangle { anchors.fill: parent; radius: 2.5; color: root.ink; opacity: 0.22 }
                    Rectangle {
                        height: parent.height; radius: 2.5
                        width: root.player && root.player.length > 0 ? parent.width * Math.min(1, root.position / root.player.length) : 0
                        color: root.ink
                    }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -6
                        onClicked: e => { if (root.player && root.player.canSeek) root.player.position = root.player.length * Math.max(0, Math.min(1, e.x / width)); }
                    }
                }
                Item {
                    width: parent.width; height: 14
                    Label { text: Media.fmt(root.position); color: root.ink; opacity: 0.55; font.pixelSize: Theme.smallSize - 1 }
                    Label { anchors.right: parent.right; text: "-" + Media.fmt(Math.max(0, (root.player ? root.player.length : 0) - root.position)); color: root.ink; opacity: 0.55; font.pixelSize: Theme.smallSize - 1 }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 34
                Repeater {
                    model: [
                        { s: "media-skip-backward-symbolic", go: () => root.player.previous() },
                        { s: Media.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic", go: () => root.player.togglePlaying(), big: true },
                        { s: "media-skip-forward-symbolic", go: () => root.player.next() },
                    ]
                    delegate: MouseArea {
                        required property var modelData
                        width: 30; height: 30
                        onClicked: if (root.player) modelData.go()
                        Sym { anchors.centerIn: parent; name: parent.modelData.s; size: parent.modelData.big ? 26 : 20; color: root.ink }
                    }
                }
            }

            // Spotify's lyrics, when LRCLIB has them
            Column {
                width: parent.width
                spacing: 4
                visible: Lyrics.lines.length > 0
                Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: Lyrics.line(Lyrics.index - 1); color: root.ink; opacity: 0.35; font.pixelSize: Theme.smallSize }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    text: Lyrics.index < 0 ? "♪" : Lyrics.line(Lyrics.index)
                    color: root.ink
                    strong: true
                    font.pixelSize: Theme.textSize + 3
                }
                Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: Lyrics.line(Lyrics.index + 1); color: root.ink; opacity: 0.35; font.pixelSize: Theme.smallSize }
            }
        }
    }
}
