pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.common
import qs.services

// The power menu (Super+Escape): the screen frosts over and four pearls
// rise in a row: lock, log out, restart, shut down. The hovered (or
// selected) pearl turns iridescent. Arrows/hjkl and Enter, 1–4, or Esc.
PanelWindow {
    id: win

    readonly property bool open: Shell.powerOpen
    property int current: 0

    readonly property var actions: [
        { icon: "lock", name: "Lock", run: () => Quickshell.execDetached(["rice", "lock"]) },
        { icon: "logout", name: "Log out", run: () => Quickshell.execDetached(["rice", "logout"]) },
        { icon: "reboot", name: "Restart", run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { icon: "power", name: "Shut down", run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
    ]

    function choose(i) {
        Shell.powerOpen = false;
        actions[i].run();
    }

    screen: Hypr.focusedScreen
    visible: open || veil.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nacre-power"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: if (open) { current = 0; keys.forceActiveFocus(); }

    // the frost: Hyprland blurs this layer; the pearl veil softens it further
    Rectangle {
        id: veil
        anchors.fill: parent
        color: Theme.glass
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.open ? Theme.durPanelIn : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Theme.bloom : Theme.sink } }

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
            const k = event.key;
            if (k === Qt.Key_Escape) Shell.powerOpen = false;
            else if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Backtab) win.current = (win.current + 3) % 4;
            else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Tab) win.current = (win.current + 1) % 4;
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) win.choose(win.current);
            else if (k >= Qt.Key_1 && k <= Qt.Key_4) win.choose(k - Qt.Key_1);
            else return;
            event.accepted = true;
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 34

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Until next time"
            font.family: Theme.fontDisplay
            size: 44
            weight: Font.Normal
            opacity: veil.opacity
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 36

            Repeater {
                model: win.actions

                delegate: Item {
                    id: choice

                    required property var modelData
                    required property int index
                    readonly property bool lit: win.current === index

                    width: 104
                    height: 140

                    // rise in one after another, 30 ms apart
                    opacity: win.open ? 1 : 0
                    property real rise: win.open ? 0 : 24
                    transform: Translate { y: choice.rise }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: win.open ? choice.index * Theme.stagger : 0 } NumberAnimation { duration: win.open ? Theme.durPanelIn : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Theme.bloom : Theme.sink } } }
                    Behavior on rise { SequentialAnimation { PauseAnimation { duration: win.open ? choice.index * Theme.stagger : 0 } NumberAnimation { duration: win.open ? Theme.durOpen : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Theme.settle : Theme.sink } } }

                    Item {
                        id: orb
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 96
                        height: 96
                        scale: choice.lit ? 1.06 : 1
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

                        Pearl {
                            anchors.fill: parent
                            gloss: choice.lit ? 0.9 : 0.55
                            iri: choice.lit ? 0.85 : 0.05
                        }
                        Icon {
                            anchors.centerIn: parent
                            name: choice.modelData.icon
                            size: 30
                            stroke: 1.5
                            color: Theme.ink
                        }
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: orb.bottom
                        anchors.topMargin: 14
                        text: choice.modelData.name
                        size: Theme.uiSize + 3
                        color: choice.lit ? Theme.ink : Theme.inkSoft
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.current = choice.index
                        onClicked: win.choose(choice.index)
                    }
                }
            }
        }
    }
}
