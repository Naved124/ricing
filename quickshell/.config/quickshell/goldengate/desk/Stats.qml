pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.services

// The desktop widgets, as macOS puts them on the desktop: the system card
// (CPU, memory and disk as rings) and the weather (now, today's high and
// low, the next hours). Each is turned on in Control Center or System
// Settings and dragged where it's wanted; its place is kept as fractions of
// the screen. They're on the bottom layer, under every window.
PanelWindow {
    id: root

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "goldengate:widgets"
    color: "transparent"
    // the screen's name, given once (reading `screen` here loops as the window maps)
    property string at: ""
    // a full-screen window covers the bottom layer anyway
    visible: Shell.statsShown || Shell.weatherShown
    mask: Region {
        Region { x: sys.x; y: sys.y; width: sys.visible ? sys.width : 0; height: sys.visible ? sys.height : 0 }
        Region { x: weather.x; y: weather.y; width: weather.visible ? weather.width : 0; height: weather.visible ? weather.height : 0 }
    }
    Binding { target: Weather; property: "wanted"; value: Shell.weatherShown }

    Widget {
        id: sys
        visible: Shell.statsShown
        width: 330; height: 150
        at: Shell.statsAt
        area: root
        screen: root.screen
        onMoved: (fx, fy) => Shell.moveStats(fx, fy)
        Row {
            anchors.centerIn: parent
            spacing: 26
            Repeater {
                model: [
                    { name: qsTr("CPU"), v: Sys.cpu, color: Theme.blue },
                    { name: qsTr("Memory"), v: Sys.mem, color: Theme.green },
                    { name: qsTr("Disk"), v: Sys.disk, color: Theme.orange },
                ]
                delegate: Column {
                    required property var modelData
                    spacing: 6
                    Canvas {
                        id: ring
                        width: 72; height: 72
                        property real v: parent.modelData.v
                        property color tint: parent.modelData.color
                        property color track: Theme.fill
                        onVChanged: requestPaint()
                        onTintChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            ctx.lineWidth = 8;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = track;
                            ctx.beginPath(); ctx.arc(36, 36, 30, 0, 2 * Math.PI); ctx.stroke();
                            ctx.strokeStyle = tint;
                            ctx.beginPath(); ctx.arc(36, 36, 30, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.max(0.01, Math.min(1, v))); ctx.stroke();
                        }
                        Label { anchors.centerIn: parent; text: Math.round(ring.v * 100) + "%"; strong: true; font.pixelSize: Theme.smallSize + 1 }
                    }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.name; secondary: true; font.pixelSize: Theme.smallSize }
                }
            }
        }
    }

    Widget {
        id: weather
        visible: Shell.weatherShown
        width: 330; height: 160
        at: Shell.weatherAt
        area: root
        screen: root.screen
        onMoved: (fx, fy) => Shell.moveWeather(fx, fy)

        Label {
            visible: !Weather.ready
            anchors.centerIn: parent
            text: qsTr("Looking up the weather…")
            secondary: true
        }
        Item {
            anchors { fill: parent; margins: 16 }
            visible: Weather.ready
            Column {
                anchors { left: parent.left; top: parent.top }
                Label { text: Weather.city || qsTr("Here"); strong: true }
                Label { text: Math.round(Weather.temp) + "°"; font.family: Theme.fontDisplay; font.pixelSize: 40; font.weight: Font.Normal }
            }
            Column {
                anchors { right: parent.right; top: parent.top }
                spacing: 2
                Sym { anchors.right: parent.right; name: Weather.symbol(Weather.code, Weather.day); size: 20; color: Weather.code <= 2 && Weather.day ? Theme.yellow : Theme.label }
                Label { anchors.right: parent.right; text: Weather.text(Weather.code); font.pixelSize: Theme.smallSize; strong: true }
                Label { anchors.right: parent.right; text: qsTr("H:%1° L:%2°").arg(Math.round(Weather.high)).arg(Math.round(Weather.low)); font.pixelSize: Theme.smallSize; secondary: true }
            }
            Row {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                Repeater {
                    model: Weather.hours
                    delegate: Column {
                        required property var modelData
                        width: (weather.width - 32) / Math.max(1, Weather.hours.length)
                        spacing: 3
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.label; font.pixelSize: Theme.smallSize - 1; secondary: true }
                        Sym { anchors.horizontalCenter: parent.horizontalCenter; name: Weather.symbol(parent.modelData.code, parent.modelData.day); size: 16; color: parent.modelData.code <= 2 && parent.modelData.day ? Theme.yellow : Theme.label }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(parent.modelData.temp) + "°"; font.pixelSize: Theme.smallSize; strong: true }
                    }
                }
            }
        }
    }
}
