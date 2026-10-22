pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs.common
import qs.services

// The control centre (Super+N, or the bar's battery and speaker): a page
// from a spiral notebook dropped in at the top right, five binding holes
// down its left edge.
//   · hand-drawn checkboxes with red ticks: Wi-Fi, Bluetooth, Do Not
//     Disturb, night light, paper grain, the lamp (light, dark, auto),
//     performance (power-profiles-daemon) and the microphone (right-click
//     Wi-Fi or Bluetooth for their settings)
//   · volume (to 150%) and brightness as pencil lines with a red dot
// (What's playing and the notes live in the bar's island.)
// Esc or a click outside puts it away.
PanelWindow {
    id: win

    readonly property bool open: Shell.centerOpen
    readonly property var adapter: Bluetooth.defaultAdapter
    property bool leaving: false

    screen: Hypr.focusedScreen
    visible: open || leaving
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "paper-center"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onOpenChanged: {
        if (open) {
            toss.stop();
            leaving = false;
            page.y = page.restY;
            page.opacity = 1;
            flick.contentY = 0;
            keys.forceActiveFocus();
        } else {
            leaving = true;
            toss.start();
        }
    }

    // a helper window the shell opens itself never goes in the bin
    function run(cls, cmd) {
        Bin.expect(cls);
        Shell.centerOpen = false;
        Quickshell.execDetached(cmd);
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Shell.centerOpen = false
    }
    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: Shell.centerOpen = false
    }

    Sheet {
        id: page

        readonly property real restY: 10 + 44 + 18
        x: win.width - width - Theme.gapsOut - 4
        y: restY
        width: 400
        height: Math.min(win.height - restY - Theme.gapsOut, items.implicitHeight + 48)
        seed: 400
        tilt: 0.6
        ruled: true
        ruleTop: 58
        ruleGap: 26
        margin: true
        marginX: 50

        MouseArea { anchors.fill: parent }   // clicks on the page stay on it

        // the spiral's holes
        Column {
            x: 16
            y: 70
            spacing: (page.height - 140 - 5 * 16) / 4
            Repeater {
                model: 5
                delegate: Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: Theme.desk
                    border.color: Qt.alpha(Theme.soot, 0.19)
                    border.width: 1
                    // a shadow inside the hole's top edge
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: width / 2
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.alpha(Theme.soot, 0.25) }
                            GradientStop { position: 0.5; color: Qt.alpha(Theme.soot, 0) }
                        }
                    }
                }
            }
        }

        Flickable {
            id: flick
            x: 66
            y: 18
            width: page.width - 66 - 22
            height: page.height - 36
            contentHeight: items.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: items
                width: flick.width
                spacing: 12

                // the day, and the way out
                Item {
                    width: parent.width
                    height: 44
                    Column {
                        Serif {
                            text: Qt.formatDate(clock.date, "dddd d MMMM")
                            size: 22
                            weight: 600
                            color: Theme.ink
                        }
                        Hand {
                            text: (Battery.present ? `${Math.round(Battery.level * 100)}%${Battery.charging ? " charging" : ""}${Battery.timeLeft ? " · " + Battery.timeLeft : ""} · ` : "")
                                + `net ↓ ${Net.rate(Net.down)} ↑ ${Net.rate(Net.up)}`
                            size: 14
                            color: Theme.graphite
                        }
                    }
                    SystemClock { id: clock; precision: SystemClock.Minutes }
                    Row {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 12
                        Repeater {
                            model: [
                                { glyph: "lock", run: () => { Shell.centerOpen = false; Quickshell.execDetached(["rice", "lock"]); } },
                                { glyph: "power", run: () => Shell.togglePower() },
                            ]
                            delegate: Glyph {
                                required property var modelData
                                name: modelData.glyph
                                size: 22
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
                }

                // the checklist
                Column {
                    width: parent.width
                    spacing: 0
                    Check {
                        width: parent.width
                        label: "wifi"
                        detail: Net.wired ? "on a cable" : Net.wifi ? Net.wifi.name : Net.wifiEnabled ? "not connected" : "off"
                        on: Net.wifiEnabled
                        available: !!Net.wifiDevice
                        onToggled: Net.setWifi(!Net.wifiEnabled)
                        // right-click or double-click: the network widget (the shared shell's)
                        doubleOpens: true
                        onSecondary: { Shell.centerOpen = false; Quickshell.execDetached(["qs", "-c", "rice", "ipc", "call", "network", "open"]); }
                    }
                    Check {
                        readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)
                        width: parent.width
                        label: "bluetooth"
                        detail: !win.adapter ? "no adapter" : !on ? "off" : connected.length === 1 ? connected[0].name : connected.length ? `${connected.length} devices` : "on"
                        on: !!win.adapter && win.adapter.enabled
                        available: !!win.adapter
                        onToggled: win.adapter.enabled = !win.adapter.enabled
                        onSecondary: win.run("blueman-manager", ["blueman-manager"])
                    }
                    Check {
                        width: parent.width
                        label: "do not disturb"
                        detail: on ? "notes wait in the pile" : ""
                        on: Shell.dnd
                        onToggled: Shell.setDnd(!Shell.dnd)
                    }
                    Check {
                        width: parent.width
                        label: "night light"
                        detail: on ? `${Shell.nightTemp} K` : ""
                        on: Shell.nightLight
                        onToggled: Shell.setNightLight(!Shell.nightLight)
                    }
                    Check {
                        width: parent.width
                        label: "paper grain"
                        detail: on ? "" : "off for games and video"
                        on: Shell.grain
                        onToggled: Shell.setGrain(!Shell.grain)
                    }
                    // the lamp: light → dark (lamplight) → auto (by the sun) → light
                    Check {
                        width: parent.width
                        label: "lamp"
                        glyph: Theme.dark ? "moon" : "sun"
                        detail: Theme.mode.auto ? Theme.mode.next
                              : Theme.dark ? "on · tick again for auto" : "daylight"
                        on: Theme.dark
                        onToggled: Theme.mode.cycle()
                        onSecondary: Quickshell.execDetached(["rice", "mode", "auto", Theme.mode.auto ? "off" : "on"])
                    }
                    // the index card with cpu, memory and disk, on the desk
                    Check {
                        width: parent.width
                        label: "system card"
                        detail: on ? "on the desk" : "put away"
                        on: Shell.statsShown
                        onToggled: Shell.setStatsShown(!Shell.statsShown)
                    }
                    // power-profiles-daemon: performance or balanced; right-click for the saver
                    Check {
                        readonly property int profile: PowerProfiles.profile
                        width: parent.width
                        label: "performance"
                        detail: profile === PowerProfile.PowerSaver ? "power saver · right-click: balanced"
                              : on ? "full speed" : "balanced · right-click: power saver"
                        on: profile === PowerProfile.Performance
                        available: PowerProfiles.hasPerformanceProfile
                        onToggled: PowerProfiles.profile = on ? PowerProfile.Balanced : PowerProfile.Performance
                        onSecondary: PowerProfiles.profile = profile === PowerProfile.PowerSaver
                                     ? PowerProfile.Balanced : PowerProfile.PowerSaver
                    }
                    Check {
                        width: parent.width
                        label: "microphone"
                        detail: !Audio.source ? "none" : Audio.micMuted ? "muted" : (Audio.source.description || "on")
                        on: !!Audio.source && !Audio.micMuted
                        available: !!Audio.source
                        onToggled: Audio.toggleMic()
                    }
                    // screen recording to ~/Videos (Super+Shift+R does the same)
                    Check {
                        width: parent.width
                        label: "screen recording"
                        detail: on ? `${Shell.recordingTime} · tick to stop` : "right-click: an area"
                        on: Shell.recording
                        onToggled: {
                            if (Shell.recording) { Shell.toggleRecording(); return; }
                            Shell.centerOpen = false;
                            recScreen.restart();
                        }
                        onSecondary: {
                            if (Shell.recording) return;
                            Shell.centerOpen = false;
                            recRegion.restart();
                        }
                        // start once the sheet is put away, so it isn't in the video
                        Timer { id: recScreen; interval: 350; onTriggered: Shell.toggleRecording("screen") }
                        Timer { id: recRegion; interval: 350; onTriggered: Shell.toggleRecording("region") }
                    }
                }

                // levels
                Column {
                    width: parent.width
                    spacing: 4
                    PencilSlider {
                        width: parent.width
                        glyph: Audio.muted ? "speaker-off" : "speaker"
                        value: Audio.volume
                        max: Audio.maxVolume
                        muted: Audio.muted
                        available: Audio.ready
                        onMoved: v => Audio.setVolume(v)
                        onGlyphClicked: Audio.toggleMute()
                    }
                    PencilSlider {
                        width: parent.width
                        visible: Brightness.available
                        glyph: "sun"
                        value: Brightness.level
                        onMoved: v => Brightness.set(Math.max(0.02, v))
                    }
                }
            }
        }
    }

    // put away: the page is tossed back up and off
    ParallelAnimation {
        id: toss
        NumberAnimation { target: page; property: "y"; to: page.restY + 80; duration: Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.toss }
        NumberAnimation { target: page; property: "opacity"; to: 0; duration: Theme.durPanelOut; easing.type: Easing.InQuad }
        onFinished: win.leaving = false
    }
}
