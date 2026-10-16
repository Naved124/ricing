pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.services

// Workspace numbers in Kalam. The active one has a red pen loop drawn round
// it; on a switch the old loop is erased and the new one drawn in. Only the
// workspaces that exist on this monitor are listed, plus the active one;
// empty ones are pencilled in at 35%. Click a number to go there; scroll to
// step through them.
Item {
    id: root

    required property var monitor
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property var ids: {
        const have = Hyprland.workspaces.values
            .filter(w => w.id > 0 && w.monitor === root.monitor)
            .map(w => w.id);
        if (!have.includes(activeId)) have.push(activeId);
        return have.sort((a, b) => a - b);
    }

    implicitWidth: row.implicitWidth
    implicitHeight: 34

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Repeater {
            model: ScriptModel { values: root.ids }

            delegate: Item {
                id: num

                required property int modelData
                readonly property var ws: Hypr.workspace(modelData)
                readonly property bool active: root.activeId === modelData
                readonly property bool empty: !ws || (ws.toplevels?.values?.length ?? 0) === 0
                readonly property bool urgent: !!ws && ws.urgent

                width: 32
                height: 34
                opacity: empty && !active ? 0.35 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }

                Hand {
                    anchors.centerIn: parent
                    text: num.modelData
                    size: 20
                    color: num.active ? Theme.ink : num.urgent ? Theme.red : Theme.pencil
                    Behavior on color { ColorAnimation { duration: Theme.durFocus } }
                }

                Scribble {
                    anchors.centerIn: parent
                    width: 40
                    height: 36
                    seed: num.modelData * 7 + 3
                    drawn: num.active
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hypr.focusWorkspace(num.modelData)
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Hypr.cycleWorkspace(event.angleDelta.y > 0 ? -1 : 1)
    }
}
