pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// The power menu (Super+Escape): "That's a wrap" over the dimmed plate, and
// five glass orbs rise in a row: lock, suspend, log out, restart, shut down.
// The one under the pointer (or chosen with the arrows) glows. The three
// that end the session take a second click: the first rings the orb in
// the urgent colour and says so. Arrows/hjkl and Enter, 1–5, or Esc.
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
    WlrLayershell.namespace: "satsuei-power"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: if (open) { current = 0; armed = -1; keys.forceActiveFocus(); }
    // a second click has to come soon
    Timer { id: disarm; interval: 3000; onTriggered: win.armed = -1 }

    // the plate darkens; Hyprland blurs this layer
    Rectangle {
        id: veil
        anchors.fill: parent
        color: Theme.glassDeep
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.open ? Style.durPanelIn : Style.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Style.bloom : Style.sink } }
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
            text: win.armed >= 0 ? `${win.actions[win.armed].name}? Click again` : "That's a wrap"
            font.family: Style.fontDisplay
            size: 30
            weight: Style.weightDisplay
            spacing: 0.2
            color: win.armed >= 0 ? Theme.urgent : Theme.fg
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
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: win.open ? choice.index * Style.stagger : 0 } NumberAnimation { duration: win.open ? Style.durPanelIn : Style.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Style.bloom : Style.sink } } }
                    Behavior on rise { SequentialAnimation { PauseAnimation { duration: win.open ? choice.index * Style.stagger : 0 } NumberAnimation { duration: win.open ? Style.durOpen : Style.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Style.settle : Style.sink } } }

                    Item {
                        id: orb
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 80
                        height: 80
                        scale: choice.lit ? 1.06 : 1
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.settle } }

                        // the jelly's halo, when lit
                        Glow {
                            anchors.centerIn: parent
                            width: 190; height: 190
                            color: choice.armed ? Theme.urgent : Theme.accent
                            opacity: choice.armed ? 0.55 : choice.lit ? 0.42 : 0
                            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.bloom } }
                        }
                        Glass {
                            anchors.fill: parent
                            radius: width / 2
                            fill: Theme.glassFill
                            line: choice.armed ? Theme.urgent : choice.lit ? Theme.at(Theme.accent, 0.6) : Theme.rim
                            halo: 0
                        }
                        // asked to be sure: a pink rim
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -4
                            radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: Theme.urgent
                            opacity: choice.armed ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                        Icon {
                            anchors.centerIn: parent
                            name: choice.modelData.icon
                            size: 26
                            stroke: 1.5
                            color: choice.armed ? Theme.urgent : choice.lit ? Theme.accent : Theme.fg
                        }
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: orb.bottom
                        anchors.topMargin: 14
                        text: choice.modelData.name.toUpperCase()
                        size: 11
                        spacing: 0.16
                        color: choice.armed ? Theme.urgent : choice.lit ? Theme.fg : Theme.fgDim
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
