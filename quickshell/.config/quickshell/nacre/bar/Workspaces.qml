pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import qs
import qs.common
import qs.services

// Five workspace pearls for this monitor.
//   empty     a matte pearl
//   occupied  glossy
//   active    stretches into an iridescent capsule (animated width)
//   urgent    pulses rose
// Scroll to switch. When a window is sent to another workspace, a pearl
// travels from the current dot to the target, which pulses once.
Item {
    id: root

    required property var monitor
    readonly property int count: 5
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1

    implicitWidth: row.implicitWidth
    implicitHeight: 26

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        Repeater {
            id: dots
            model: root.count

            delegate: Item {
                id: dot

                required property int index
                readonly property int wsId: index + 1
                readonly property var ws: Hypr.workspace(wsId)
                readonly property bool here: !!ws && ws.monitor === root.monitor
                readonly property bool active: root.activeId === wsId
                readonly property bool occupied: here && (ws.toplevels?.values?.length ?? 0) > 0
                readonly property bool urgent: here && ws.urgent

                function pulse() { pulseAnim.restart(); }

                width: active ? 30 : 12
                height: 12
                anchors.verticalCenter: parent.verticalCenter

                Behavior on width {
                    NumberAnimation { duration: Theme.durWorkspace; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle }
                }

                // empty: a small matte pearl; occupied: a full glossy one
                Pearl {
                    anchors.centerIn: parent
                    width: dot.occupied || dot.urgent ? 12 : 8
                    height: width
                    opacity: dot.active ? 0 : (dot.occupied || dot.urgent ? 1 : 0.85)
                    base: dot.urgent ? Theme.rose : dot.occupied ? Theme.pearl : Theme.shell
                    shade: dot.urgent ? Qt.darker(Theme.rose, 1.15) : dot.occupied ? Theme.lilac : Qt.darker(Theme.lilac, 1.05)
                    gloss: dot.occupied || dot.urgent ? 1.0 : 0.0
                    iri: dot.occupied ? 0.45 : 0.0
                    Behavior on width { NumberAnimation { duration: Theme.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
                    Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }
                }

                Iridescent {
                    anchors.fill: parent
                    radius: height / 2
                    opacity: dot.active ? 1 : 0
                    spinning: dot.active
                    period: 6000
                    sheen: 0.5
                    Behavior on opacity { NumberAnimation { duration: Theme.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bloom } }
                }

                // urgent: a slow rose pulse until attended to
                SequentialAnimation on scale {
                    running: dot.urgent && !dot.active
                    loops: Animation.Infinite
                    onStopped: dot.scale = 1
                    NumberAnimation { to: 1.3; duration: 520; easing.type: Easing.OutSine }
                    NumberAnimation { to: 1.0; duration: 520; easing.type: Easing.InSine }
                }

                // one pulse when a window lands here
                SequentialAnimation {
                    id: pulseAnim
                    NumberAnimation { target: dot; property: "scale"; to: 1.45; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: dot; property: "scale"; to: 1.0; duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hypr.focusWorkspace(dot.wsId)
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Hypr.cycleWorkspace(event.angleDelta.y > 0 ? -1 : 1)
    }

    // ── send-to-workspace: a pearl travels to the target dot ───────────────
    Pearl {
        id: traveller
        width: 9; height: 9
        visible: false
        gloss: 1
        iri: 1
        z: 10
    }

    ParallelAnimation {
        id: flight
        property real fromX: 0
        property real toX: 0
        property int target: 1

        onStopped: {
            traveller.visible = false;
            dots.itemAt(target - 1)?.pulse();
        }

        PathAnimation {
            target: traveller
            duration: 520
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.sink
            path: Path {
                startX: flight.fromX
                startY: (root.height - traveller.height) / 2
                PathQuad {
                    x: flight.toX
                    y: (root.height - traveller.height) / 2
                    controlX: (flight.fromX + flight.toX) / 2
                    controlY: root.height + 4      // dip below the pill line
                }
            }
        }
        SequentialAnimation {
            NumberAnimation { target: traveller; property: "scale"; from: 1.0; to: 0.7; duration: 260 }
            NumberAnimation { target: traveller; property: "scale"; to: 1.0; duration: 260 }
        }
    }

    function centreOf(id) {
        const d = dots.itemAt(id - 1);
        return d ? row.x + d.x + d.width / 2 - traveller.width / 2 : 0;
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // movewindowv2>>ADDRESS,WORKSPACEID,WORKSPACENAME
            if (event.name !== "movewindowv2" || !root.monitor?.focused) return;
            const to = parseInt(event.data.split(",")[1]);
            const from = root.activeId;
            if (isNaN(to) || to === from || to < 1 || to > root.count) return;
            flight.stop();
            flight.fromX = root.centreOf(from);
            flight.toX = root.centreOf(to);
            flight.target = to;
            traveller.visible = true;
            flight.start();
        }
    }
}
