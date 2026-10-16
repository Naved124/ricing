pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.common
import qs.services

// The control centre (Super+N): a full-height frosted panel on the right.
// Quick toggles, level sliders, what's playing (with cava), the month, and
// the notification history. Slides in 40 px with a bloom; Esc or a click
// outside sinks it away.
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
    WlrLayershell.namespace: "nacre-center"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onOpenChanged: {
        if (!open) return;
        cal.reset();
        flick.contentY = 0;
        focusTimer.restart();
        keys.forceActiveFocus();
    }
    // after the panel has laid out, scroll to what was asked for
    Timer {
        id: focusTimer
        interval: 60
        onTriggered: {
            const target = Shell.centerFocus === "calendar" ? cal : Shell.centerFocus === "media" ? media : null;
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
        anchors.margins: Theme.gapsOut
        width: 380

        opacity: win.open ? 1 : 0
        transform: Translate { x: win.open ? 0 : 40; Behavior on x { NumberAnimation { duration: win.open ? Theme.durPanelIn : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Theme.bloom : Theme.sink } } }
        Behavior on opacity { NumberAnimation { duration: win.open ? Theme.durPanelIn : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Theme.bloom : Theme.sink } }

        MouseArea { anchors.fill: parent }   // clicks inside stay inside

        Glass {
            anchors.fill: parent
            radius: Theme.radiusPanel + 6
            fill: Theme.glassStrong

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: 20
                contentHeight: content.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Behavior on contentY { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bloom } }

                Column {
                    id: content
                    width: flick.width
                    spacing: 18

                    // the hour, the date, and the way out
                    Item {
                        width: parent.width
                        height: 52

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Label {
                                text: Qt.formatTime(clock.date, "HH:mm")
                                font.family: Theme.fontDisplay
                                size: 34
                                weight: Font.Normal
                            }
                            Label {
                                text: Qt.formatDate(clock.date, "dddd, d MMMM") + (Battery.present ? `  ·  ${Math.round(Battery.level * 100)}%${Battery.timeLeft ? " · " + Battery.timeLeft : ""}` : "")
                                font.capitalization: Font.SmallCaps
                                font.letterSpacing: 0.8
                                size: Theme.uiSize + 1
                                color: Theme.inkSoft
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
                                    width: 34
                                    height: 34
                                    Pearl {
                                        anchors.fill: parent
                                        gloss: btnMouse.containsMouse ? 0.85 : 0.45
                                        iri: btnMouse.containsMouse ? 0.6 : 0
                                    }
                                    Icon { anchors.centerIn: parent; name: btn.modelData.icon; size: 16; color: Theme.ink }
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
                        columns: 3
                        spacing: 8
                        width: parent.width
                        readonly property real tile: (width - 2 * spacing) / 3

                        Toggle {
                            width: parent.tile
                            icon: Net.wifiIcon
                            name: "Wi-Fi"
                            detail: Net.wifi ? Net.wifi.name : Net.wifiEnabled ? "Not connected" : "Off"
                            on: Net.wifiEnabled
                            available: !!Net.wifiDevice
                            onToggled: Net.setWifi(!Net.wifiEnabled)
                            onSecondary: { Shell.centerOpen = false; Quickshell.execDetached(["kitty", "-e", "nmtui"]); }
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
                            name: "Quiet"
                            detail: on ? "Silenced" : "Off"
                            on: Shell.dnd
                            onToggled: Shell.setDnd(!Shell.dnd)
                        }
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
                            icon: Audio.micMuted ? "mic-off" : "mic"
                            name: "Microphone"
                            detail: !Audio.source ? "None" : Audio.micMuted ? "Muted" : "On"
                            on: !!Audio.source && !Audio.micMuted
                            available: !!Audio.source
                            onToggled: Audio.toggleMic()
                        }
                        Toggle {
                            readonly property int profile: PowerProfiles.profile
                            readonly property var profiles: PowerProfiles.hasPerformanceProfile
                                ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
                                : [PowerProfile.PowerSaver, PowerProfile.Balanced]
                            width: parent.tile
                            icon: profile === PowerProfile.PowerSaver ? "leaf" : profile === PowerProfile.Performance ? "rocket" : "gauge"
                            name: "Power"
                            detail: profile === PowerProfile.PowerSaver ? "Saver" : profile === PowerProfile.Performance ? "Performance" : "Balanced"
                            on: profile !== PowerProfile.Balanced
                            onToggled: PowerProfiles.profile = profiles[(profiles.indexOf(profile) + 1) % profiles.length]
                        }
                        Toggle {
                            width: parent.tile
                            icon: "coffee"
                            name: "Caffeine"
                            detail: on ? "Staying awake" : "Off"
                            on: Shell.caffeine
                            onToggled: Shell.caffeine = !Shell.caffeine
                        }
                        Toggle {
                            width: parent.tile
                            icon: "camera"
                            name: "Screenshot"
                            detail: "A region"
                            onToggled: { Shell.centerOpen = false; shot.restart(); }
                            onSecondary: { Shell.centerOpen = false; shotScreen.restart(); }
                            // wait for the panel to slide away so it isn't in the picture
                            Timer { id: shot; interval: 350; onTriggered: Quickshell.execDetached(["rice-shot", "region"]) }
                            Timer { id: shotScreen; interval: 350; onTriggered: Quickshell.execDetached(["rice-shot", "screen"]) }
                        }
                        Toggle {
                            width: parent.tile
                            icon: "keyboard"
                            name: "Keys"
                            detail: "Super + /"
                            onToggled: Shell.toggleKeys()
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

                    // what's playing
                    Rectangle {
                        id: media
                        width: parent.width
                        visible: !!Media.player
                        height: visible ? mediaColumn.implicitHeight + 28 : 0
                        radius: Theme.radiusPopup + 4
                        color: Theme.glassSoft
                        border.color: Theme.hairline

                        Column {
                            id: mediaColumn
                            x: 14
                            y: 14
                            width: parent.width - 28
                            spacing: 10
                            MediaCard {
                                width: parent.width
                                artSize: 72
                            }
                            Cava {
                                width: parent.width
                                active: win.open && Media.playing
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.hairline }

                    Calendar {
                        id: cal
                        width: parent.width
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.hairline }

                    History {
                        width: parent.width
                    }
                }
            }
        }
    }
}
