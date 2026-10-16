pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Sticky notes down the right edge under the bar, newest on top, three at
// most (the rest wait their turn). The surface runs the full height of the
// screen so a peeled note can fall out of sight; only the notes take clicks.
PanelWindow {
    id: win

    readonly property real ui: Theme.uiSize / 14
    readonly property int noteWidth: Math.round(186 * ui)

    screen: Hypr.focusedScreen
    // the control centre lists the same notes; don't double up
    visible: !Shell.centerOpen

    anchors { top: true; bottom: true; right: true }
    implicitWidth: noteWidth + 80
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "paper-notes"

    mask: Region { item: list }

    ListView {
        id: list
        x: win.width - win.noteWidth - 22
        y: 10 + 44 + 24
        width: win.noteWidth
        height: contentHeight
        spacing: 12
        interactive: false
        model: ScriptModel { values: Notifs.shown }

        delegate: Sticky {
            required property var modelData
            notification: modelData
            width: ListView.view.width
            ui: win.ui
        }

        // a note the app closed (or replaced) slips away; the others close up
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.durClose; easing.type: Easing.InQuad }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drop }
            NumberAnimation { property: "opacity"; to: 1; duration: Theme.durMove }
        }
    }
}
