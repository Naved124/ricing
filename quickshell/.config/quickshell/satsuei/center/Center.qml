pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs.chars
import qs.common
import qs.services

// The control centre (Super+N, or the bar's sliders button): a 372 px drawer
// of glass down the right side that slides in with a slight overshoot (the
// mock's .2,.9,.25,1.05 over 0.55 s). Top to bottom:
//   · you: the avatar seal, user@host, uptime, power
//   · what's playing (MediaCard), the dancer standing on its top right edge
//   · the character strip (Strip): who dances, who peeks from the edge
//   · twelve toggles: the shared set every rice's centre has (Wi-Fi,
//     Bluetooth, Quiet, Night light, Microphone, Performance, Caffeine,
//     Screenshot, Record) and Satsuei's own (Compositing, Mascot, the
//     Timesheet, which is the desk's system card)
//   · volume (to 150%) and brightness (past the backlight it's the pass's
//     exposure; with no backlight it's only that)
//   · the last four notifications
// Esc or a click outside closes it.
PanelWindow {
    id: win

    readonly property bool open: Shell.centerOpen
    readonly property var adapter: Bluetooth.defaultAdapter
    property alias media: media
    property alias strip: stripSlot

    screen: Hypr.focusedScreen
    visible: open || drawer.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "satsuei-center"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onOpenChanged: if (open) { flick.contentY = 0; keys.forceActiveFocus(); }

    MouseArea {
        anchors.fill: parent
        onClicked: Shell.centerOpen = false
    }
    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: Shell.centerOpen = false
    }

    // ── uptime and who ─────────────────────────────────────────────────────
    property string host: ""
    property real uptime: 0
    FileView {
        id: hostFile
        path: "/etc/hostname"
        blockLoading: true
        printErrors: false
        onLoaded: win.host = text().trim()
    }
    FileView {
        id: upFile
        path: "/proc/uptime"
        printErrors: false
        onLoaded: win.uptime = parseFloat(text())
    }
    Timer {
        interval: 60000
        repeat: true
        running: win.open
        triggeredOnStart: true
        onTriggered: upFile.reload()
    }
    function upText(s) {
        if (!s) return "";
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return "up " + (d ? `${d} d ` : "") + (d || h ? `${h} h ` : "") + `${m} min`;
    }

    Item {
        id: drawer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.topMargin: 66                     // 10 + the bar's 46 + 10
        anchors.bottomMargin: 12
        anchors.rightMargin: 10
        width: 372

        opacity: win.open ? 1 : 0
        transform: Translate {
            x: win.open ? 0 : drawer.width + 30
            Behavior on x {
                NumberAnimation {
                    duration: win.open ? 550 : Style.durPanelOut
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: win.open ? Style.bloom : Style.sink
                }
            }
        }
        Behavior on opacity { NumberAnimation { duration: 350 } }

        MouseArea { anchors.fill: parent }   // clicks inside stay inside

        Glass {
            anchors.fill: parent
            radius: 22

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: 18
                contentHeight: content.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: content
                    width: flick.width
                    spacing: 16

                    // ── you ────────────────────────────────────────────────
                    Row {
                        width: parent.width
                        spacing: 12
                        Rectangle {
                            width: 40; height: 40; radius: 14
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.accent }
                                GradientStop { position: 1; color: Theme.accent2 }
                            }
                            Label { anchors.centerIn: parent; text: "撮"; display: true; size: 16; color: Theme.onAccent }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40 - 12 - power.width - 12
                            Label {
                                width: parent.width
                                text: (Quickshell.env("USER") || "you") + (win.host ? "@" + win.host : "")
                                size: 14
                                weight: Style.weightStrong
                                elide: Text.ElideRight
                            }
                            Label { text: win.upText(win.uptime); size: 11.5; color: Theme.fgDim }
                        }
                        Btn {
                            id: power
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32; height: 32
                            onClicked: Shell.togglePower()
                            Icon { anchors.centerIn: parent; name: "power" }
                        }
                    }

                    // ── what's playing; the dancer stands on it ─────────────
                    Item { width: 1; height: 62 }         // the mock's 78 px less the spacing
                    MediaCard {
                        id: media
                        width: parent.width
                        Dancer {
                            parent: media.stage
                            anchors.fill: parent
                            running: win.open
                        }
                    }

                    // ── the character strip ────────────────────────────────
                    Strip {
                        id: stripSlot
                        width: parent.width
                        open: win.open
                    }

                    // ── toggles ────────────────────────────────────────────
                    Grid {
                        id: tiles
                        width: parent.width
                        columns: 3
                        spacing: 8
                        readonly property real tileW: (width - spacing * 2) / 3
                        Tile {
                            width: tiles.tileW
                            icon: Net.wifiIcon
                            title: "Wi-Fi"
                            sub: Net.wifiEnabled ? (Net.wifi?.name ?? "On") : "Off"
                            on: Net.wifiEnabled
                            onToggled: Net.setWifi(!Net.wifiEnabled)
                            // right-click or double-click: the network widget (the shared shell's)
                            doubleOpens: true
                            onSecondary: { Shell.centerOpen = false; Quickshell.execDetached(["qs", "-c", "rice", "ipc", "call", "network", "open"]); }
                        }
                        Tile {
                            width: tiles.tileW
                            icon: win.adapter?.enabled ? "bluetooth" : "bluetooth-off"
                            title: "Bluetooth"
                            sub: !win.adapter ? "No adapter" : !win.adapter.enabled ? "Off"
                                 : (Bluetooth.devices.values.find(d => d.connected)?.name ?? "On")
                            on: !!win.adapter?.enabled
                            // an rfkill block makes `enabled` a no-op, so unblock first
                            onToggled: {
                                if (win.adapter?.enabled) { win.adapter.enabled = false; return; }
                                Quickshell.execDetached(["sh", "-c", "rfkill unblock bluetooth; sleep 0.4; bluetoothctl power on"]);
                                if (win.adapter) btLater.restart();
                            }
                            Timer {
                                id: btLater
                                interval: 600
                                onTriggered: if (win.adapter && !win.adapter.enabled) win.adapter.enabled = true
                            }
                        }
                        Tile {
                            width: tiles.tileW
                            icon: Shell.dnd ? "bell-off" : "bell"
                            title: "Quiet"
                            sub: Shell.dnd ? "Subtitles off" : "Subtitles on"
                            on: Shell.dnd
                            onToggled: Shell.setDnd(!Shell.dnd)
                        }
                        Tile {
                            width: tiles.tileW
                            icon: "sunset"
                            title: "Night light"
                            sub: Shell.nightLight ? "Warmer" : "Off"
                            on: Shell.nightLight
                            onToggled: Shell.setNightLight(!Shell.nightLight)
                        }
                        Tile {
                            width: tiles.tileW
                            icon: Audio.micMuted || !Audio.source ? "mic-off" : "mic"
                            title: "Microphone"
                            sub: !Audio.source ? "None" : Audio.micMuted ? "Muted" : "On"
                            on: !!Audio.source && !Audio.micMuted
                            onToggled: if (Audio.source) Audio.toggleMic()
                        }
                        // power-profiles-daemon: performance ⇄ balanced; right-click for the saver
                        // (Screenshot and Record: right-click for the screen / an area)
                        Tile {
                            readonly property int profile: PowerProfiles.profile
                            width: tiles.tileW
                            icon: profile === PowerProfile.PowerSaver ? "leaf" : profile === PowerProfile.Performance ? "rocket" : "gauge"
                            title: "Performance"
                            sub: profile === PowerProfile.PowerSaver ? "Power saver" : on ? "Full speed" : "Balanced"
                            on: profile === PowerProfile.Performance
                            onToggled: if (PowerProfiles.hasPerformanceProfile)
                                           PowerProfiles.profile = on ? PowerProfile.Balanced : PowerProfile.Performance
                            onSecondary: PowerProfiles.profile = profile === PowerProfile.PowerSaver
                                         ? PowerProfile.Balanced : PowerProfile.PowerSaver
                        }
                        Tile {
                            width: tiles.tileW
                            icon: "coffee"
                            title: "Caffeine"
                            sub: Shell.caffeine ? "Staying awake" : "Off"
                            on: Shell.caffeine
                            onToggled: Shell.caffeine = !Shell.caffeine
                        }
                        Tile {
                            width: tiles.tileW
                            icon: "camera"
                            title: "Screenshot"
                            sub: "An area"
                            onToggled: { Shell.centerOpen = false; shot.restart(); }
                            onSecondary: { Shell.centerOpen = false; shotScreen.restart(); }
                            // wait for the drawer to slide away so it isn't in the picture
                            Timer { id: shot; interval: 350; onTriggered: Quickshell.execDetached(["rice-shot", "region"]) }
                            Timer { id: shotScreen; interval: 350; onTriggered: Quickshell.execDetached(["rice-shot", "screen"]) }
                        }
                        // screen recording to ~/Videos (Super+Shift+R does the same)
                        Tile {
                            width: tiles.tileW
                            icon: "record"
                            title: Shell.recording ? "Recording" : "Record"
                            sub: Shell.recording ? `${Shell.recordingTime} · stop` : "The screen"
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
                            // start once the drawer has gone, so it isn't in the video
                            Timer { id: recScreen; interval: 350; onTriggered: Shell.toggleRecording("screen") }
                            Timer { id: recRegion; interval: 350; onTriggered: Shell.toggleRecording("region") }
                        }
                        Tile {
                            width: tiles.tileW
                            icon: "sparkle"
                            title: "Compositing"
                            sub: Settings.s.pass ? "Shader on" : "Raw plate"
                            on: Settings.s.pass
                            onToggled: Settings.s.pass = !Settings.s.pass
                        }
                        Tile {
                            width: tiles.tileW
                            icon: "person"
                            title: "Mascot"
                            sub: Settings.s.mascot ? "Peeks on alerts" : "Hidden"
                            on: Settings.s.mascot
                            onToggled: Settings.s.mascot = !Settings.s.mascot
                        }
                        Tile {
                            width: tiles.tileW
                            icon: "film"
                            title: "Timesheet"
                            sub: Shell.statsShown ? "On the desk" : "Put away"
                            on: Shell.statsShown
                            onToggled: Shell.setStatsShown(!Shell.statsShown)
                        }
                    }

                    // ── levels ─────────────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 10
                        Slider {
                            width: parent.width
                            icon: Audio.icon
                            from: 0; to: 150
                            value: Audio.volume * 100
                            onMoved: v => Audio.setVolume(v / 100)
                        }
                        // the backlight up to 100; past it, or with no backlight,
                        // the pass's exposure (0.4–1.15)
                        Slider {
                            width: parent.width
                            icon: "brightness"
                            from: Brightness.available ? 5 : 40
                            to: 115
                            value: Settings.s.expo > 1 || !Brightness.available ? Settings.s.expo * 100
                                                                                : Brightness.level * 100
                            onMoved: v => {
                                if (!Brightness.available) { Settings.s.expo = v / 100; return; }
                                Brightness.set(Math.min(1, v / 100));
                                Settings.s.expo = Math.max(1, v / 100);
                            }
                        }
                    }

                    // ── notifications ──────────────────────────────────────
                    Item {
                        width: parent.width
                        height: 26
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "NOTIFICATIONS"
                            size: 11
                            weight: Style.weightStrong
                            spacing: 0.14
                            color: Theme.fgDim
                        }
                        Btn {
                            visible: Notifs.all.length > 0
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: clear.implicitWidth + 20
                            height: 24
                            radius: 12
                            color: hovered ? Theme.at(Theme.fg, 0.16) : Theme.at(Theme.fg, 0.08)
                            onClicked: Notifs.clearAll()
                            Label { id: clear; anchors.centerIn: parent; text: "Clear"; size: 11.5; weight: Style.weightStrong }
                        }
                    }
                    NoteList { width: parent.width }
                }
            }
        }
    }
}
