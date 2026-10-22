pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.common
import qs.services

// The control centre (Super+N): a 380 px pane of glass down the right side.
// Quick toggles as glowing pills (Wi-Fi, Bluetooth, Do Not Disturb, night
// light, whether the reef feels the pointer, the microphone, caffeine,
// recording, the system card, a screenshot), the power profile, the levels
// and the month. No light/dark: Abyss is always dark. What's playing and the
// notifications live in the island. It drifts in from the right and sinks
// away; Esc or a click outside closes it.
PanelWindow {
    id: win

    readonly property bool open: Shell.centerOpen
    readonly property var adapter: Bluetooth.defaultAdapter

    screen: Hypr.focusedScreen
    visible: open || panel.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "abyss-center"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onOpenChanged: {
        if (!open) return;
        cal.reset();
        flick.contentY = 0;
        focusTimer.restart();
        keys.forceActiveFocus();
    }
    Timer {
        id: focusTimer
        interval: 60
        onTriggered: {
            const target = Shell.centerFocus === "calendar" ? cal : null;
            if (target) flick.contentY = Math.min(target.mapToItem(content, 0, 0).y - 10, Math.max(0, flick.contentHeight - flick.height));
        }
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

    Item {
        id: panel
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.topMargin: 12 + 40 + 12        // under the bar
        anchors.bottomMargin: Theme.gapsOut
        anchors.rightMargin: Theme.gapsOut
        width: 380

        opacity: win.open ? 1 : 0
        transform: Translate {
            x: win.open ? 0 : 40
            y: win.open ? 0 : 12
            Behavior on x { NumberAnimation { duration: win.open ? Theme.durPanelIn : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Theme.drift : Theme.sink } }
            Behavior on y { NumberAnimation { duration: win.open ? Theme.durPanelIn : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Theme.drift : Theme.sink } }
        }
        Behavior on opacity { NumberAnimation { duration: win.open ? Theme.durPanelIn : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Theme.drift : Theme.sink } }

        MouseArea { anchors.fill: parent }   // clicks inside stay inside

        Glass {
            anchors.fill: parent
            radius: Theme.radiusPanel
            fill: Theme.glassStrong

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: 18
                contentHeight: content.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Behavior on contentY { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drift } }

                Column {
                    id: content
                    width: flick.width
                    spacing: 18

                    // the hour, the date, and the way out
                    Item {
                        width: parent.width
                        height: 50
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Label {
                                text: Qt.formatTime(clock.date, "HH:mm")
                                font.family: Theme.fontDisplay
                                size: 28
                                weight: Theme.weightDisplay
                                spacing: 0.12
                            }
                            Label {
                                text: Qt.formatDate(clock.date, "dddd d MMMM").toUpperCase()
                                      + (Battery.present ? `  ·  ${Math.round(Battery.level * 100)}%` : "")
                                size: 10.5
                                spacing: 0.16
                                color: Theme.inkDim
                            }
                        }
                        SystemClock { id: clock; precision: SystemClock.Minutes }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Repeater {
                                model: [
                                    { icon: "lock", run: () => Quickshell.execDetached(["rice", "lock"]) },
                                    { icon: "power", run: () => Shell.togglePower() },
                                ]
                                delegate: Item {
                                    id: btn
                                    required property var modelData
                                    width: 32
                                    height: 32
                                    Glow {
                                        anchors.centerIn: parent
                                        width: 56; height: 56
                                        color: Theme.glow
                                        opacity: btnMouse.containsMouse ? 0.4 : 0
                                        Behavior on opacity { NumberAnimation { duration: 180 } }
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: btnMouse.containsMouse ? Theme.washOn : Theme.wash
                                        border.color: btnMouse.containsMouse ? Theme.lineOn : Theme.line
                                    }
                                    Icon { anchors.centerIn: parent; name: btn.modelData.icon; size: 14; color: Theme.ink }
                                    MouseArea {
                                        id: btnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { Shell.centerOpen = false; btn.modelData.run(); }
                                    }
                                }
                            }
                        }
                    }

                    // quick toggles
                    Grid {
                        columns: 2
                        spacing: 8
                        width: parent.width
                        readonly property real tile: (width - spacing) / 2

                        Toggle {
                            width: parent.tile
                            icon: Net.wifiIcon
                            name: "Wi-Fi"
                            detail: Net.wifi ? Net.wifi.name : Net.wifiEnabled ? "Not connected" : "Off"
                            on: Net.wifiEnabled
                            available: !!Net.wifiDevice
                            onToggled: Net.setWifi(!Net.wifiEnabled)
                            // right-click or double-click: the network widget (the shared shell's)
                            doubleOpens: true
                            onSecondary: { Shell.centerOpen = false; Quickshell.execDetached(["qs", "-c", "rice", "ipc", "call", "network", "open"]); }
                        }
                        Toggle {
                            readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)
                            width: parent.tile
                            icon: on ? "bluetooth" : "bluetooth-off"
                            name: "Bluetooth"
                            detail: !win.adapter ? "No adapter" : !on ? "Off" : connected.length === 1 ? connected[0].name : connected.length ? `${connected.length} devices` : "On"
                            on: !!win.adapter && win.adapter.enabled
                            available: !!win.adapter
                            onToggled: win.adapter.enabled = !win.adapter.enabled
                            onSecondary: { Shell.centerOpen = false; Quickshell.execDetached(["blueman-manager"]); }
                        }
                        Toggle {
                            width: parent.tile
                            icon: on ? "bell-off" : "bell"
                            name: "Do not disturb"
                            detail: on ? "Only what's critical" : "Off"
                            on: Shell.dnd
                            onToggled: Shell.setDnd(!Shell.dnd)
                        }
                        // hyprsunset stays its own thing; this just asks it
                        Toggle {
                            width: parent.tile
                            icon: "sunset"
                            name: "Night light"
                            detail: on ? `${Shell.nightTemp} K` : "Off"
                            on: Shell.nightLight
                            onToggled: Shell.setNightLight(!Shell.nightLight)
                        }
                        Toggle {
                            width: parent.tile
                            icon: on ? "touch" : "touch-off"
                            name: "Reef interactive"
                            detail: !Config.interactive ? "Off in abyss.toml" : on ? "Feels the pointer" : "Off"
                            on: Config.interactive && Shell.reefInteractive
                            available: Config.interactive
                            onToggled: Shell.setReefInteractive(!Shell.reefInteractive)
                        }
                        Toggle {
                            width: parent.tile
                            icon: Audio.micMuted ? "mic-off" : "mic"
                            name: "Microphone"
                            detail: !Audio.source ? "None" : Audio.micMuted ? "Muted" : "On"
                            on: !!Audio.source && !Audio.micMuted
                            available: !!Audio.source
                            onToggled: Audio.toggleMic()
                        }
                        Toggle {
                            width: parent.tile
                            icon: "coffee"
                            name: "Caffeine"
                            detail: on ? "Staying awake" : "Off"
                            on: Shell.caffeine
                            onToggled: Shell.caffeine = !Shell.caffeine
                        }
                        // screen recording to ~/Videos (Super+Shift+R does the same)
                        Toggle {
                            width: parent.tile
                            icon: "record"
                            name: on ? "Recording" : "Record"
                            detail: on ? `${Shell.recordingTime} · tap to stop` : "Screen · right: area"
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
                            // start once the panel has drifted away, so it isn't in the video
                            Timer { id: recScreen; interval: 350; onTriggered: Shell.toggleRecording("screen") }
                            Timer { id: recRegion; interval: 350; onTriggered: Shell.toggleRecording("region") }
                        }
                        // the jellyfish on the desktop: cpu, memory and disk
                        Toggle {
                            width: parent.tile
                            icon: "jelly"
                            name: "System card"
                            detail: on ? "On the desktop" : "Hidden"
                            on: Shell.statsShown
                            onToggled: Shell.setStatsShown(!Shell.statsShown)
                        }
                        Toggle {
                            width: parent.tile
                            icon: "camera"
                            name: "Screenshot"
                            detail: "A region · right: screen"
                            onToggled: { Shell.centerOpen = false; shot.restart(); }
                            onSecondary: { Shell.centerOpen = false; shotScreen.restart(); }
                            Timer { id: shot; interval: 350; onTriggered: Quickshell.execDetached(["rice-shot", "region"]) }
                            Timer { id: shotScreen; interval: 350; onTriggered: Quickshell.execDetached(["rice-shot", "screen"]) }
                        }
                    }

                    // the power profile (power-profiles-daemon): three glass segments
                    Rectangle {
                        id: profiles
                        width: parent.width
                        height: 36
                        radius: height / 2
                        visible: PowerProfiles.hasPerformanceProfile || PowerProfiles.profile !== undefined
                        color: Theme.wash
                        border.color: Theme.line
                        Row {
                            anchors.fill: parent
                            anchors.margins: 3
                            Repeater {
                                model: [
                                    { p: PowerProfile.PowerSaver, name: "Saver", icon: "leaf" },
                                    { p: PowerProfile.Balanced, name: "Balanced", icon: "gauge" },
                                    { p: PowerProfile.Performance, name: "Performance", icon: "rocket" },
                                ]
                                delegate: Item {
                                    id: seg
                                    required property var modelData
                                    readonly property bool on: PowerProfiles.profile === modelData.p
                                    readonly property bool usable: modelData.p !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                                    width: (profiles.width - 6) / 3
                                    height: profiles.height - 6
                                    opacity: usable ? 1 : 0.4
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: height / 2
                                        color: seg.on ? Theme.washOn : "transparent"
                                        border.color: seg.on ? Theme.lineOn : "transparent"
                                        Behavior on color { ColorAnimation { duration: 180 } }
                                    }
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Icon { anchors.verticalCenter: parent.verticalCenter; name: seg.modelData.icon; size: 13; color: seg.on ? Theme.glow : Theme.inkDim }
                                        Label { anchors.verticalCenter: parent.verticalCenter; text: seg.modelData.name; size: 11.5; color: seg.on ? Theme.ink : Theme.inkDim }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: seg.usable
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: PowerProfiles.profile = seg.modelData.p
                                    }
                                }
                            }
                        }
                    }

                    // levels
                    Column {
                        width: parent.width
                        spacing: 10
                        SliderRow {
                            width: parent.width
                            icon: Audio.icon
                            value: Audio.volume
                            max: Audio.maxVolume
                            muted: Audio.muted
                            available: Audio.ready
                            onMoved: v => Audio.setVolume(v)
                            onIconClicked: Audio.toggleMute()
                        }
                        SliderRow {
                            width: parent.width
                            icon: Audio.micMuted ? "mic-off" : "mic"
                            value: Audio.micVolume
                            muted: Audio.micMuted
                            available: !!Audio.source
                            onMoved: v => Audio.setMicVolume(v)
                            onIconClicked: Audio.toggleMic()
                        }
                        SliderRow {
                            width: parent.width
                            visible: Brightness.available
                            icon: "brightness"
                            value: Brightness.level
                            onMoved: v => Brightness.set(Math.max(0.02, v))
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.line }

                    Calendar {
                        id: cal
                        width: parent.width
                    }
                }
            }
        }
    }
}
