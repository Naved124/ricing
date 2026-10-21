pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import qs
import qs.common
import qs.services

// The mock's workspace dots, for this monitor: five, or as many as the
// highest one in use needs (a window on it, or being on it), shrinking back
// once those are empty.
//   empty     a dim outlined dot
//   occupied  outlined brighter
//   active    a 22 px teal pill, glowing, stretching on the drift curve
//   urgent    pink, pulsing
// Click to go, scroll to step.
Item {
    id: root

    required property var monitor
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property int count: {
        let top = Math.max(5, activeId);
        for (const w of Hyprland.workspaces.values)
            if (w.id > 0 && w.monitor === root.monitor && (w.toplevels?.values?.length ?? 0) > 0)
                top = Math.max(top, w.id);
        return top;
    }

    implicitWidth: row.implicitWidth
    implicitHeight: 22

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9

        Repeater {
            model: root.count

            delegate: Item {
                id: dot

                required property int index
                readonly property int wsId: index + 1
                readonly property var ws: Hypr.workspace(wsId)
                readonly property bool here: !!ws && ws.monitor === root.monitor
                readonly property bool active: root.activeId === wsId
                readonly property bool occupied: here && (ws.toplevels?.values?.length ?? 0) > 0
                readonly property bool urgent: here && ws.urgent && !active

                width: active ? 22 : 9
                height: 9
                anchors.verticalCenter: parent.verticalCenter
                Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drift } }

                // one that's new to the row drifts in
                NumberAnimation on opacity { from: 0; to: 1; duration: Theme.durFocus; running: dot.wsId > 5 }

                Glow {
                    anchors.centerIn: parent
                    width: parent.width + 18
                    height: 26
                    color: dot.urgent ? Theme.pink : Theme.glow
                    opacity: dot.active ? 0.7 : dot.urgent ? 0.5 * pulse.v : 0
                    Behavior on opacity { NumberAnimation { duration: 350 } }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: dot.active ? 5 : width / 2
                    color: dot.active ? Theme.glow : dot.urgent ? Theme.pinkAt(0.35 + 0.5 * pulse.v) : "transparent"
                    border.width: 1
                    border.color: dot.active ? Theme.glow : dot.urgent ? Theme.pink
                                : Theme.glowAt(dot.occupied ? 0.6 : 0.35)
                    Behavior on color { ColorAnimation { duration: 350 } }
                }
                QtObject {
                    id: pulse
                    property real v: 0
                    SequentialAnimation on v {
                        running: dot.urgent
                        loops: Animation.Infinite
                        NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 700; easing.type: Easing.InOutSine }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
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
}
