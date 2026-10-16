pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services
import "../common/paper.js" as P

// The power menu (Super+Escape): four rubber stamps on a card. SUSPEND,
// LOGOUT, REBOOT and SHUTDOWN in red Courier inside a double border, each
// turned −2° and worn where the ink didn't take. Hovering lifts a stamp;
// choosing one presses it (1.15 → 0.96, then a splash of ink) before it
// acts. REBOOT and SHUTDOWN want a second press ("sure?" is scribbled
// beside them). Arrows or h/l, 1–4, Enter; Esc or a click outside closes.
PanelWindow {
    id: win

    readonly property bool open: Shell.powerOpen
    property int current: 0
    property int armed: -1               // the stamp waiting for its "sure?"

    readonly property var actions: [
        { name: "SUSPEND", confirm: false, run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        { name: "LOGOUT", confirm: false, run: () => Quickshell.execDetached(["rice", "logout"]) },
        { name: "REBOOT", confirm: true, run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { name: "SHUTDOWN", confirm: true, run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
    ]

    signal pressed(int index)

    function choose(i) {
        if (actions[i].confirm && armed !== i) {
            armed = i;
            disarm.restart();
            return;
        }
        armed = -1;
        pressed(i);
    }

    Timer { id: disarm; interval: 4000; onTriggered: win.armed = -1 }

    screen: Hypr.focusedScreen
    visible: open
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "paper-power"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: if (open) { current = 0; armed = -1; keys.forceActiveFocus(); }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
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
            else if (k >= Qt.Key_1 && k <= Qt.Key_4) { win.current = k - Qt.Key_1; win.choose(win.current); }
            else return;
            event.accepted = true;
        }
    }

    Sheet {
        id: card
        anchors.centerIn: parent
        width: 760
        height: 250
        seed: 760
        tilt: 0.8

        MouseArea { anchors.fill: parent }

        Hand {
            x: 30
            y: 16
            text: "leaving the desk?"
            size: 22
            color: Theme.ink
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 86
            spacing: 26

            Repeater {
                model: win.actions

                delegate: Item {
                    id: stamp

                    required property var modelData
                    required property int index
                    readonly property bool lit: win.current === index

                    width: 158
                    height: 74

                    Connections {
                        target: win
                        function onPressed(i) { if (i === stamp.index) press.start(); }
                    }

                    Item {
                        id: face
                        anchors.fill: parent
                        rotation: -2
                        property real lift: stamp.lit ? 1 : 0
                        Behavior on lift { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                        scale: 1 + lift * 0.04
                        transform: Translate { y: -3 * face.lift }

                        // the ink: a double border round spaced-out Courier
                        Item {
                            id: ink
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: Theme.red
                                border.width: 3
                                radius: 3
                            }
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 6
                                color: "transparent"
                                border.color: Theme.red
                                border.width: 1.5
                                radius: 2
                            }
                            Type {
                                anchors.centerIn: parent
                                text: stamp.modelData.name
                                size: 19
                                weight: 700
                                color: Theme.red
                                font.letterSpacing: 19 * 0.18
                            }
                        }
                        // worn: where the ink took (assets/ink-wear.png's alpha)
                        Image {
                            id: wear
                            anchors.fill: parent
                            source: "file://" + Theme.inkWear
                            fillMode: Image.Tile
                            visible: false
                            layer.enabled: true
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: ink
                            maskEnabled: true
                            maskSource: wear
                            maskThresholdMin: 0.3
                            maskSpreadAtMin: 0.2
                            opacity: stamp.lit ? 0.95 : 0.8
                            shadowEnabled: face.lift > 0
                            shadowColor: Theme.umber
                            shadowOpacity: 0.25 * face.lift
                            shadowBlur: 0.4
                            shadowVerticalOffset: 4
                        }
                    }

                    // the splash when it hits the paper
                    Repeater {
                        model: 7
                        delegate: Rectangle {
                            id: blot
                            required property int index
                            readonly property real a: P.between(stamp.index * 50 + index, 0, Math.PI * 2)
                            readonly property real d: P.between(stamp.index * 70 + index, 50, 96)
                            x: stamp.width / 2 + Math.cos(a) * d * splash.t - width / 2
                            y: stamp.height / 2 + Math.sin(a) * d * 0.55 * splash.t - height / 2
                            width: P.between(stamp.index * 90 + index, 4, 10)
                            height: width
                            radius: width / 2
                            color: Theme.red
                            opacity: splash.t > 0 ? 0.8 * (1 - splash.t * 0.6) : 0
                        }
                    }
                    QtObject { id: splash; property real t: 0 }

                    // "sure?", scribbled beside it
                    Hand {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 8
                        rotation: -6
                        visible: win.armed === stamp.index
                        text: "sure? press again"
                        size: 17
                        color: Theme.red
                    }

                    SequentialAnimation {
                        id: press
                        NumberAnimation { target: face; property: "scale"; to: 1.15; duration: 110; easing.type: Easing.OutQuad }
                        NumberAnimation { target: face; property: "scale"; to: 0.96; duration: 90; easing.type: Easing.InQuad }
                        NumberAnimation { target: splash; property: "t"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
                        PauseAnimation { duration: 120 }
                        ScriptAction {
                            script: {
                                Shell.powerOpen = false;
                                splash.t = 0;
                                face.scale = Qt.binding(() => 1 + face.lift * 0.04);
                                stamp.modelData.run();
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.current = stamp.index
                        onClicked: win.choose(stamp.index)
                    }
                }
            }
        }
    }
}
