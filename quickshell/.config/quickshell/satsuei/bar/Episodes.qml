pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Hyprland
import qs.common
import qs.services

// Workspaces as episodes: "01"–"05" in Dela Gothic One on a sunken tray, the
// active one an accent pill with a glow, the occupied ones marked with a dot.
// Only this monitor's; past five it grows to the highest in use. Click to go,
// scroll to step.
Rectangle {
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

    implicitWidth: row.implicitWidth + 6
    implicitHeight: 34
    radius: 12
    color: Theme.well

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Hypr.cycleWorkspace(event.angleDelta.y > 0 ? -1 : 1)
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.count
            delegate: Item {
                id: ep
                required property int index
                readonly property int wsId: index + 1
                readonly property var ws: Hypr.workspace(wsId)
                readonly property bool active: root.activeId === wsId
                readonly property bool occupied: !!ws && ws.monitor === root.monitor
                                                 && (ws.toplevels?.values?.length ?? 0) > 0
                readonly property bool urgent: !!ws && ws.urgent && !active
                width: Math.max(44, num.implicitWidth + 16)
                height: 28

                RectangularShadow {
                    anchors.fill: pill
                    radius: pill.radius
                    blur: 18
                    spread: -2
                    color: Theme.at(Theme.accent, 0.8)
                    opacity: ep.active ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                }
                Rectangle {
                    id: pill
                    anchors.fill: parent
                    radius: 9
                    color: ep.active ? Theme.accent : hover.containsMouse ? Theme.at(Theme.fg, 0.07) : "transparent"
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Label {
                    id: num
                    anchors.centerIn: parent
                    text: String(ep.wsId).padStart(2, "0")
                    display: true
                    size: 11
                    spacing: 0.06
                    color: ep.active ? Theme.onAccent : ep.urgent ? Theme.urgent
                         : hover.containsMouse ? Theme.fg : Theme.fgDim
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                // occupied: a small dot under the number
                Rectangle {
                    visible: ep.occupied && !ep.active
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    width: 4; height: 4; radius: 2
                    color: num.color
                    opacity: 0.7
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hypr.focusWorkspace(ep.wsId)
                }
            }
        }
    }
}
