pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.services

// The Dynamic Island, in the middle of the menu bar: a black capsule that
// springs wider for what's going on (a recording, what's playing, a
// notification for a moment, a test from `gg island test`), and holds the
// track's controls on hover.
Rectangle {
    id: root

    property string flash: ""          // a notification's summary, for a moment
    readonly property string test: Shell.islandTest   // gg island test ACTIVITY
    readonly property string activity: test !== "" ? test
        : Shell.recording ? "recording" : flash !== "" ? "notification"
        : Media.playing ? "media" : ""
    readonly property bool wide: activity !== "" || hover.hovered && Media.player !== null

    visible: Settings.island.show !== "off" && (Settings.island.show === "always" || activity !== "")
    width: wide ? 340 : 128
    height: 26
    radius: height / 2
    color: Theme.island
    Behavior on width { SpringAnimation { spring: Theme.spring; damping: Theme.damping } }

    function show(text) { flash = text; flashTimer.restart(); }
    Timer { id: flashTimer; interval: 4000; onTriggered: root.flash = "" }
    Timer { id: testTimer; interval: 6000; onTriggered: Shell.islandTest = "" }
    onTestChanged: if (test !== "") testTimer.restart()
    Connections {
        target: Notifs
        function onArrived(n) { root.show((n.appName ? n.appName + ": " : "") + n.summary); }
    }

    HoverHandler { id: hover }

    Row {
        anchors.centerIn: parent
        spacing: 8
        visible: root.wide
        opacity: root.wide ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fadeMs } }

        Rectangle {
            visible: root.activity === "recording"
            anchors.verticalCenter: parent.verticalCenter
            width: 8; height: 8; radius: 4
            color: Theme.red
            SequentialAnimation on opacity { running: Shell.recording; loops: Animation.Infinite; NumberAnimation { to: 0.3; duration: 700 } NumberAnimation { to: 1; duration: 700 } }
        }
        ClippingRectangle {
            visible: root.activity === "media" || root.activity === "" && Media.player
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18; radius: 5
            color: Theme.graphite
            Image { anchors.fill: parent; source: Media.player ? Media.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 250)
            color: Theme.onWallpaper
            font.pixelSize: Theme.smallSize
            text: root.activity === "recording" ? qsTr("Recording")
                : root.activity === "notification" ? root.flash
                : (root.activity === "media" || root.activity === "") && Media.player ? (Media.player.trackTitle || "") + (Media.player.trackArtist ? " — " + Media.player.trackArtist : "")
                : root.activity
        }
        Label {
            visible: hover.hovered && Media.player !== null
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.onWallpaper
            text: Media.playing ? "⏸" : "▶"
            MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: Media.player.togglePlaying() }
        }
        Label {
            visible: hover.hovered && Media.player !== null
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.onWallpaper
            text: "⏭"
            MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: Media.player.next() }
        }
    }
    TapHandler { onTapped: Shell.toggle("notifications") }
}
