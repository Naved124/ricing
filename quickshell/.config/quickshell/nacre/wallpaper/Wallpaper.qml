pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs
import qs.services

// The living wallpaper: iridescent blooms drifting over pearl. It runs at
// 30 fps and freezes while a window on this monitor is fullscreen or the
// laptop is on battery. Clicking the desktop drops a ripple.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property bool paused: Hypr.fullscreenOn(monitor) || UPower.onBattery

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "nacre-wallpaper"
    color: Theme.pearl

    property real time: 0
    property real rippleAge: -1
    property point ripplePos: Qt.point(0.5, 0.5)

    Timer {
        // 30 fps: the blooms are slow, a higher rate buys nothing
        running: !root.paused
        interval: 33
        repeat: true
        onTriggered: {
            root.time += 0.033;
            if (root.rippleAge >= 0) {
                root.rippleAge += 0.033;
                if (root.rippleAge > 3) root.rippleAge = -1;
            }
        }
    }

    ShaderEffect {
        id: surface
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("../shaders/wallpaper.frag.qsb")

        readonly property color ground0: Theme.wallGround[0]
        readonly property color ground1: Theme.wallGround[1]
        readonly property color lilac: Theme.lilac
        readonly property color c0: Theme.wallBlooms[0]
        readonly property color c1: Theme.wallBlooms[1]
        readonly property color c2: Theme.wallBlooms[2]
        readonly property color c3: Theme.wallBlooms[3]
        readonly property color c4: Theme.wallBlooms[4]
        readonly property color a0: Theme.wallAccents[0]
        readonly property color a1: Theme.wallAccents[1]
        readonly property color a2: Theme.wallAccents[2]
        readonly property size resolution: Qt.size(width, height)
        readonly property real time: root.time
        readonly property point ripplePos: root.ripplePos
        readonly property real rippleAge: root.rippleAge
        readonly property real dark: Theme.k
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => {
            root.ripplePos = Qt.point(mouse.x / width, mouse.y / height);
            root.rippleAge = 0;
        }
    }

    // Export one still frame for the lock screen and the login greeter:
    // ~/.cache/rice/nacre/still.png (+ still-blur.png when ImageMagick exists).
    readonly property string stillDir: Quickshell.env("HOME") + "/.cache/rice/nacre"

    Timer {
        running: root.screen === Quickshell.screens[0]
        interval: 1500
        onTriggered: mkdir.running = true
    }

    Process {
        id: mkdir
        command: ["mkdir", "-p", root.stillDir]
        onExited: surface.grabToImage(result => {
            if (result.saveToFile(root.stillDir + "/still.png")) blur.running = true;
        })
    }

    Process {
        id: blur
        command: ["sh", "-c", 'command -v magick >/dev/null && magick "$0/still.png" -resize 50% -blur 0x24 -resize 200% "$0/still-blur.png" || true', root.stillDir]
    }
}
