pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.common
import qs.services

// The menu bar: the Apple menu and the app in front on the left, the
// Dynamic Island in the middle, the status items, Control Center and the
// clock on the right. Clear over the wallpaper unless Settings gives it a
// background; it steps aside for a full-screen window.
PanelWindow {
    id: root

    readonly property bool fullscreen: Hypr.fullscreenOn(Hypr.monitorFor(screen))
    readonly property bool background: Settings.appearance.menuBarBackground
    readonly property color ink: background ? Theme.label : Theme.onWallpaper

    anchors { top: true; left: true; right: true }
    implicitHeight: 32
    exclusiveZone: fullscreen ? 0 : implicitHeight
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "goldengate:menubar"
    color: "transparent"
    visible: !fullscreen

    Rectangle {
        anchors.fill: parent
        visible: root.background
        color: Theme.glass
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.separator }
    }

    component Item_: MouseArea {
        id: it
        property alias text: lbl.text
        property bool strong: false
        property string sym: ""
        implicitWidth: (sym ? 18 : lbl.implicitWidth) + 16
        implicitHeight: 24
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        Rectangle { anchors.fill: parent; radius: 6; color: it.containsMouse || it.pressed ? Theme.fillHover : "transparent" }
        Label {
            id: lbl
            anchors.centerIn: parent
            visible: !it.sym
            color: root.ink
            strong: it.strong
            style: root.background ? Text.Normal : Text.Raised
            styleColor: Theme.onWallpaperShadow
        }
        Sym { anchors.centerIn: parent; visible: it.sym !== ""; name: it.sym; color: root.ink; size: 16 }
    }

    Row {
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 2
        Item_ { text: ""; onClicked: Shell.toggle("apple") }
        Item_ {
            text: Windows.activeClass ? Windows.appName(Windows.activeClass) : "Finder"
            strong: true
            onClicked: Shell.toggle("apple")
        }
    }

    Island { anchors.centerIn: parent }

    Row {
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 2
        layoutDirection: Qt.LeftToRight

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
                IconImage { anchors.centerIn: parent; implicitSize: 16; source: tray.modelData.icon ?? "" }
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
        Item_ { sym: "emblem-system-symbolic"; onClicked: Shell.toggle("controlcenter") }
        Item_ {
            id: clock
            property date now: new Date()
            text: Qt.formatDateTime(now, "ddd d MMM  h:mm")
            onClicked: Shell.toggle("notifications")
            Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
        }
    }
}
