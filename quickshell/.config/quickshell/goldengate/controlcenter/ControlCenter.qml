pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.common
import qs.services

// Control Center, under the menu bar at the right: the modules on a grid
// (every shell's shared controls plus the glass and the appearance), the
// display and sound sliders (sound to 150%), and what's playing.
Panel {
    id: win

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var profiles: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]

    name: "controlcenter"
    paneWidth: 360
    paneHeight: grid.implicitHeight + 32
    paneX: (screen ? screen.width : 1920) - paneWidth - 8
    paneY: 38

    ColumnLayout {
        id: grid
        anchors { fill: parent; margins: 16 }
        spacing: 10

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 10
            columnSpacing: 10

            Tile {
                Layout.fillWidth: true
                glyph: "◉"; title: "Wi-Fi"; detail: Net.label; on: Net.wifiEnabled
                onClicked: Net.setWifi(!Net.wifiEnabled)
                onMore: { Shell.closeAll(); Shell.run(["qs", "-c", "rice", "ipc", "call", "network", "open"]); }
            }
            Tile {
                Layout.fillWidth: true
                glyph: "ᛒ"; title: "Bluetooth"
                on: !!win.adapter && win.adapter.enabled
                detail: !win.adapter ? qsTr("Unavailable") : win.adapter.enabled ? qsTr("On") : qsTr("Off")
                onClicked: if (win.adapter) win.adapter.enabled = !win.adapter.enabled
            }
            Tile {
                Layout.fillWidth: true
                glyph: "☾"; title: qsTr("Focus"); detail: Shell.dnd ? qsTr("Do Not Disturb") : ""; on: Shell.dnd
                onClicked: Shell.setDnd(!Shell.dnd)
            }
            Tile {
                Layout.fillWidth: true
                glyph: "☀"; title: qsTr("Night Shift"); on: Shell.nightLight
                onClicked: Shell.setNightLight(!Shell.nightLight)
            }
            Tile {
                Layout.fillWidth: true
                glyph: "◐"; title: qsTr("Appearance")
                detail: Theme.dark ? qsTr("Dark") : qsTr("Light"); on: Theme.dark
                onClicked: Shell.gg(["appearance", "toggle"])
                onMore: Shell.gg(["appearance", "auto"])
            }
            Tile {
                Layout.fillWidth: true
                glyph: "◇"; title: qsTr("Glass")
                detail: Theme.glassMode === "liquid" ? qsTr("Liquid") : Theme.glassMode === "frosted" ? qsTr("Frosted") : qsTr("Solid")
                on: Theme.glassMode !== "solid"
                onClicked: Shell.gg(["glass", "next"])
            }
            Tile {
                Layout.fillWidth: true
                glyph: "🎙"; title: qsTr("Microphone"); detail: Audio.micMuted ? qsTr("Muted") : ""; on: !Audio.micMuted
                onClicked: Audio.toggleMic()
            }
            Tile {
                Layout.fillWidth: true
                glyph: "⚡"; title: qsTr("Energy")
                detail: PowerProfiles.profile === PowerProfile.PowerSaver ? qsTr("Low Power")
                      : PowerProfiles.profile === PowerProfile.Performance ? qsTr("High Power") : qsTr("Automatic")
                on: PowerProfiles.profile !== PowerProfile.Balanced
                onClicked: {
                    const i = win.profiles.indexOf(PowerProfiles.profile);
                    let next = win.profiles[(i + 1) % win.profiles.length];
                    if (next === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile) next = PowerProfile.PowerSaver;
                    PowerProfiles.profile = next;
                }
            }
            Tile {
                Layout.fillWidth: true
                glyph: "☕"; title: qsTr("Keep Awake"); on: Shell.caffeine
                onClicked: Shell.caffeine = !Shell.caffeine
            }
            Tile {
                Layout.fillWidth: true
                glyph: "▦"; title: qsTr("System"); detail: qsTr("On the desktop"); on: Shell.statsShown
                onClicked: Shell.setStatsShown(!Shell.statsShown)
            }
            Tile {
                Layout.fillWidth: true
                glyph: "☁"; title: qsTr("Weather"); detail: qsTr("On the desktop"); on: Shell.weatherShown
                onClicked: Shell.setWeatherShown(!Shell.weatherShown)
            }
            Tile {
                Layout.fillWidth: true
                glyph: "⌗"; title: qsTr("Screenshot"); detail: qsTr("Selection")
                onClicked: { Shell.closeAll(); Shell.run(["sh", "-c", "sleep 0.35; exec rice-shot region"]); }
                onMore: { Shell.closeAll(); Shell.run(["rice-shot", "region"]); }
            }
            Tile {
                Layout.fillWidth: true
                glyph: "⏺"; title: qsTr("Record"); detail: Shell.recording ? qsTr("Stop") : qsTr("Screen · right-click: area")
                on: Shell.recording
                onClicked: Shell.toggleRecording("screen")
                onMore: Shell.toggleRecording("region")
            }
        }

        Label { text: qsTr("Display"); strong: true; font.pixelSize: Theme.smallSize; visible: Brightness.available }
        Slider {
            Layout.fillWidth: true
            visible: Brightness.available
            glyph: "☀"; value: Brightness.level
            onMoved: v => Brightness.set(v)
        }
        Label { text: qsTr("Sound"); strong: true; font.pixelSize: Theme.smallSize }
        Slider {
            Layout.fillWidth: true
            glyph: Audio.muted ? "🔇" : "🔊"
            value: Audio.volume; max: Audio.maxVolume       // to 1.5: 150%
            onMoved: v => Audio.setVolume(v)
        }

        // what's playing
        Rectangle {
            Layout.fillWidth: true
            visible: Media.player !== null
            implicitHeight: 56
            radius: 18
            color: Theme.fill
            Label {
                anchors { left: parent.left; leftMargin: 14; right: ctl.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: Media.player ? (Media.player.trackTitle || Media.player.identity) : ""
                strong: true
            }
            Row {
                id: ctl
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 14
                Label { text: "⏮"; MouseArea { anchors.fill: parent; onClicked: Media.player.previous() } }
                Label { text: Media.playing ? "⏸" : "▶"; MouseArea { anchors.fill: parent; onClicked: Media.player.togglePlaying() } }
                Label { text: "⏭"; MouseArea { anchors.fill: parent; onClicked: Media.player.next() } }
            }
        }
    }
}
