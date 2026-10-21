pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.common
import qs.services

// The power menu (Super+Escape): the water dims and five glass orbs rise in
// a row: lock, suspend, log out, restart, shut down. The one under the
// pointer (or chosen with the arrows) glows like a jelly's halo. The three
// that end the session take a second click: the first rings the orb in
// pink and says so. Arrows/hjkl and Enter, 1–5, or Esc.
PanelWindow {
    id: win

    readonly property bool open: Shell.powerOpen
    property int current: 0
    property int armed: -1              // the orb waiting for its second click

    readonly property var actions: [
        { icon: "lock", name: "Lock", sure: false, run: () => Quickshell.execDetached(["rice", "lock"]) },
        { icon: "suspend", name: "Suspend", sure: false, run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        { icon: "logout", name: "Log out", sure: true, run: () => Quickshell.execDetached(["rice", "logout"]) },
        { icon: "reboot", name: "Restart", sure: true, run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { icon: "power", name: "Shut down", sure: true, run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
    ]

    function choose(i) {
        const a = actions[i];
        if (a.sure && armed !== i) { armed = i; current = i; disarm.restart(); return; }
        Shell.powerOpen = false;
        armed = -1;
        a.run();
    }

    screen: Hypr.focusedScreen
    visible: open || veil.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "abyss-power"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: if (open) { current = 0; armed = -1; keys.forceActiveFocus(); }
    // a second click has to come soon
    Timer { id: disarm; interval: 3000; onTriggered: win.armed = -1 }

    // the water darkens; Hyprland blurs this layer
    Rectangle {
        id: veil
        anchors.fill: parent
        color: Theme.glassStrong
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.open ? Theme.durPanelIn : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Theme.drift : Theme.sink } }
        MouseArea {
            anchors.fill: parent
            onClicked: Shell.powerOpen = false
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const k = event.key, n = win.actions.length;
            if (k === Qt.Key_Escape) { if (win.armed >= 0) win.armed = -1; else Shell.powerOpen = false; }
            else if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Backtab) { win.current = (win.current + n - 1) % n; win.armed = -1; }
            else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Tab) { win.current = (win.current + 1) % n; win.armed = -1; }
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) win.choose(win.current);
            else if (k >= Qt.Key_1 && k <= Qt.Key_5) win.choose(k - Qt.Key_1);
            else return;
            event.accepted = true;
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 30

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: win.armed >= 0 ? `${win.actions[win.armed].name}? Click again` : "Surface"
            font.family: Theme.fontDisplay
            size: 30
            weight: Theme.weightDisplay
            spacing: 0.2
            color: win.armed >= 0 ? Theme.pink : Theme.ink
            opacity: veil.opacity
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 30

            Repeater {
                model: win.actions
                delegate: Item {
                    id: choice
                    required property var modelData
                    required property int index
                    readonly property bool lit: win.current === index
                    readonly property bool armed: win.armed === index

                    width: 88
                    height: 128

                    // they rise in one after another, on the settle curve
                    opacity: win.open ? 1 : 0
                    property real rise: win.open ? 0 : 26
                    transform: Translate { y: choice.rise }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: win.open ? choice.index * Theme.stagger : 0 } NumberAnimation { duration: win.open ? Theme.durPanelIn : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Theme.drift : Theme.sink } } }
                    Behavior on rise { SequentialAnimation { PauseAnimation { duration: win.open ? choice.index * Theme.stagger : 0 } NumberAnimation { duration: win.open ? Theme.durOpen : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Theme.settle : Theme.sink } } }

                    Item {
                        id: orb
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 80
                        height: 80
                        scale: choice.lit ? 1.06 : 1
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

                        // the jelly's halo, when lit
                        Glow {
                            anchors.centerIn: parent
                            width: 190; height: 190
                            color: choice.armed ? Theme.pink : Theme.glow
                            opacity: choice.armed ? 0.55 : choice.lit ? 0.42 : 0
                            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drift } }
                        }
                        Glass {
                            anchors.fill: parent
                            radius: width / 2
                            fill: Theme.glass
                            line: choice.armed ? Theme.pink : choice.lit ? Theme.lineOn : Theme.line
                            halo: 0
                        }
                        // asked to be sure: a pink rim
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -4
                            radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: Theme.pink
                            opacity: choice.armed ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                        Icon {
                            anchors.centerIn: parent
                            name: choice.modelData.icon
                            size: 26
                            stroke: 1.5
                            color: choice.armed ? Theme.pink : choice.lit ? Theme.glow : Theme.ink
                        }
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: orb.bottom
                        anchors.topMargin: 14
                        text: choice.modelData.name.toUpperCase()
                        size: 11
                        spacing: 0.16
                        color: choice.armed ? Theme.pink : choice.lit ? Theme.ink : Theme.inkDim
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: { win.current = choice.index; if (win.armed !== choice.index) win.armed = -1; }
                        onClicked: win.choose(choice.index)
                    }
                }
            }
        }
    }
}
