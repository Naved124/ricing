pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.common
import qs.services

// The menu bar: the Apple menu and the app in front on the left, the
// Dynamic Island in the middle, the status items, Control Center and the
// clock on the right. Clear over the wallpaper unless Settings gives it a
// background. A full-screen window covers it (it's on the top layer) and
// takes its space.
PanelWindow {
    id: root

    // the screen's name, given once (reading `screen` here loops as the window maps)
    property string at: ""
    readonly property bool fullscreen: Hypr.fullscreenOn(Hyprland.monitors.values.find(m => m.name === at) ?? null)
    readonly property color ink: Theme.label
    // one-colour tray icons on disk (Colloid's symbolic, Papirus's panel), for apps whose own is a colour badge
    property var panelIcons: []
    Process {
        running: true
        command: ["sh", "-c", "{ ls /usr/share/icons/Colloid/apps/symbolic | sed 's/^/c:/'; ls /usr/share/icons/Papirus/22x22/panel | sed 's/^/p:/'; } 2>/dev/null | sed 's/\\.svg$//'"]
        stdout: StdioCollector { onStreamFinished: root.panelIcons = this.text.split("\n").filter(n => n) }
    }

    anchors { top: true; left: true; right: true }
    implicitHeight: 32
    exclusiveZone: fullscreen ? 0 : implicitHeight
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "goldengate:menubar"
    color: "transparent"

    component Item_: MouseArea {
        id: it
        property alias text: lbl.text
        property bool strong: false
        property string sym: ""
        implicitWidth: (sym ? 18 : lbl.implicitWidth) + 16
        implicitHeight: 24
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        Rectangle { anchors.fill: parent; radius: height / 2; color: it.containsMouse || it.pressed ? Theme.fillHover : "transparent" }
        Label {
            id: lbl
            anchors.centerIn: parent
            visible: !it.sym
            color: root.ink
            strong: it.strong
        }
        Sym { anchors.centerIn: parent; visible: it.sym !== ""; name: it.sym; color: root.ink; size: 16 }
    }

    Pill {
        anchors { left: parent.left; leftMargin: 6 }
        Item_ { text: ""; onClicked: Shell.toggle("apple") }
        Item_ {
            text: Windows.activeClass ? Windows.appName(Windows.activeClass) : "Finder"
            strong: true
            onClicked: Shell.toggle("apple")
        }
    }

    Island { anchors.centerIn: parent }

    Pill {
        anchors { right: parent.right; rightMargin: 6 }

        Repeater {
            model: SystemTray.items
            delegate: MouseArea {
                id: tray
                required property var modelData
                visible: !/nm-applet|network/i.test(modelData.id)
                implicitWidth: visible ? 26 : 0
                implicitHeight: 24
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: e => {
                    if (e.button === Qt.LeftButton && !modelData.onlyMenu) modelData.activate();
                    else if (modelData.hasMenu) modelData.display(root, tray.mapToItem(null, 0, 0).x, root.implicitHeight);
                    else modelData.secondaryActivate();
                }
                TrayIcon { anchors.centerIn: parent; source: tray.modelData.icon ?? ""; appId: tray.modelData.id ?? ""; panel: root.panelIcons; ink: root.ink }
            }
        }
        // recording: a stop button, as macOS shows one
        Item_ { visible: Shell.recording; sym: "media-record-symbolic"; onClicked: Shell.run(["rice-rec", "toggle", "screen"]) }
        Item_ { visible: Media.playing && Settings.menubar.nowPlaying; sym: "media-playback-start-symbolic"; onClicked: Shell.toggle("controlcenter") }
        Item_ { visible: Shell.dnd; sym: "weather-clear-night-symbolic"; onClicked: Shell.setDnd(false) }
        Item_ {
            sym: Net.wired ? "network-wired-symbolic" : !Net.wifiEnabled ? "network-wireless-offline-symbolic"
                 : Net.strength > 0.66 ? "network-wireless-signal-excellent-symbolic"
                 : Net.strength > 0.33 ? "network-wireless-signal-good-symbolic"
                 : Net.online ? "network-wireless-signal-weak-symbolic" : "network-wireless-signal-none-symbolic"
            onClicked: Shell.run(["qs", "-c", "rice", "ipc", "call", "network", "open"])
        }
        Item_ {
            visible: Battery.present
            text: (Settings.menubar.batteryPercent ? Math.round(Battery.level * 100) + "% " : "") + (Battery.charging ? "⚡︎" : "")
            sym: Settings.menubar.batteryPercent || Battery.charging ? ""
                 : "battery-level-" + Math.min(100, Math.round(Battery.level * 10) * 10) + "-symbolic"
            onClicked: Shell.toggle("controlcenter")
        }
        // Control Center's mark: two little switches, one on, one off
        Item_ {
            implicitWidth: 34
            onClicked: Shell.toggle("controlcenter")
            Column {
                anchors.centerIn: parent
                spacing: 3
                Repeater {
                    model: [true, false]
                    delegate: Rectangle {
                        required property bool modelData
                        width: 16; height: 6; radius: 3
                        color: "transparent"
                        border.width: 1.2
                        border.color: root.ink
                        Rectangle {
                            x: parent.modelData ? parent.width - width - 1 : 1
                            anchors.verticalCenter: parent.verticalCenter
                            width: 4; height: 4; radius: 2
                            color: root.ink
                        }
                    }
                }
            }
        }
        Item_ {
            id: clock
            property date now: new Date()
            text: Qt.formatDateTime(now, "ddd d MMM  h:mm")
            onClicked: Shell.toggle("notifications")
            Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
        }
    }
}
