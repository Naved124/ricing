pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Wayland
import qs.common
import qs.services

// The control centre (Super+N, or the bar's sliders button): a 372 px drawer
// of glass down the right side that slides in with a slight overshoot (the
// mock's .2,.9,.25,1.05 over 0.55 s). Top to bottom:
//   · you: the avatar seal, user@host, uptime, recording, power
//   · what's playing (MediaCard), the dancer standing on its top right edge
//   · the character strip (chars/, from step 9)
//   · six toggles: Wi-Fi, Bluetooth, Quiet, Night light, Compositing, Mascot
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
                            width: parent.width - 40 - 12 - rec.width - power.width - 24
                            Label {
                                width: parent.width
                                text: (Quickshell.env("USER") || "you") + (win.host ? "@" + win.host : "")
                                size: 14
                                weight: Style.weightStrong
                                elide: Text.ElideRight
                            }
                            Label { text: win.upText(win.uptime); size: 11.5; color: Theme.fgDim }
                        }
                        // recording: click for the screen, right-click for a region
                        Btn {
                            id: rec
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32; height: 32
                            on: Shell.recording
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                const how = mouse.button === Qt.RightButton ? "region" : "screen";
                                if (Shell.recording) { Shell.toggleRecording(how); return; }
                                Shell.centerOpen = false;
                                recLater.how = how;
                                recLater.restart();
                            }
                            Icon { anchors.centerIn: parent; name: "record"; color: Shell.recording ? Theme.urgent : Theme.fg }
                            Timer {
                                id: recLater
                                property string how: "screen"
                                interval: 350                  // the drawer gone first
                                onTriggered: Shell.toggleRecording(how)
                            }
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
                    }

                    // ── the character strip (step 9) ────────────────────────
                    Item {
                        id: stripSlot
                        width: parent.width
                        height: childrenRect.height
                        visible: children.length > 0
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
