pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Switching workspace turns a page. Hyprland can't curl a window, so it
// slides the workspaces sideways (style "slide", curve "turn") and this layer
// draws what a turning page shows along the seam between the two: the back
// of the old page, lifted and folded over, darker in the crease, with its
// shadow on the new page. Same curve and duration as Hyprland's slide.
PanelWindow {
    id: win

    required property var modelData
    readonly property var monitor: Hypr.monitorFor(modelData)
    property int lastId: monitor?.activeWorkspace?.id ?? 0
    property real p: 0                 // 0 → 1 through the turn
    property bool forward: true        // to a higher workspace: the page turns right to left

    screen: modelData
    visible: anim.running
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "paper-turn"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Connections {
        target: win.monitor
        function onActiveWorkspaceChanged() {
            const id = win.monitor?.activeWorkspace?.id ?? 0;
            const from = win.lastId;
            win.lastId = id;
            // special workspaces and the first report don't turn a page;
            // nor does a fullscreen window, which covers this layer anyway
            if (id <= 0 || from <= 0 || id === from || Hypr.fullscreenOn(win.monitor)) return;
            win.forward = id > from;
            anim.restart();
        }
    }

    NumberAnimation {
        id: anim
        target: win
        property: "p"
        from: 0
        to: 1
        duration: Theme.durWorkspace
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.turn
    }

    // drawn for a forward turn; a backward one is the mirror image
    Item {
        id: page
        anchors.fill: parent
        transform: Scale { origin.x: page.width / 2; xScale: win.forward ? 1 : -1 }

        // where the old workspace ends and the new one begins
        readonly property real seam: width * (1 - win.p)
        // the lifted part: widest half way through, wider at the bottom corner
        readonly property real lift: Math.min(width * 0.16, 260) * Math.sin(Math.PI * win.p)

        // the flap's shadow on the new page
        Rectangle {
            x: page.seam
            width: 46
            height: page.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha(Theme.umber, 0.26) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        // the flap's shadow on the old page, just past its edge
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillGradient: LinearGradient {
                    x1: page.seam - page.lift - 18; y1: 0
                    x2: page.seam - page.lift * 0.55; y2: 0
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.alpha(Theme.umber, 0.18) }
                }
                startX: page.seam; startY: 0
                PathLine { x: page.seam - page.lift * 0.55 - 14; y: 0 }
                PathQuad { x: page.seam - page.lift - 18; y: page.height; controlX: page.seam - page.lift * 0.6 - 16; controlY: page.height * 0.7 }
                PathLine { x: page.seam; y: page.height }
            }
        }

        // the back of the page, folded over the old side of the seam
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(Theme.graphite, 0.35)
                strokeWidth: 1
                fillGradient: LinearGradient {
                    x1: page.seam; y1: 0
                    x2: page.seam - page.lift; y2: 0
                    GradientStop { position: 0; color: Qt.darker(Theme.paper, 1.14) }
                    GradientStop { position: 0.35; color: Theme.paper }
                    GradientStop { position: 0.85; color: Theme.card }
                    GradientStop { position: 1; color: Qt.darker(Theme.paper, 1.04) }
                }
                startX: page.seam; startY: 0
                PathLine { x: page.seam - page.lift * 0.55; y: 0 }
                PathQuad { x: page.seam - page.lift; y: page.height; controlX: page.seam - page.lift * 0.6; controlY: page.height * 0.7 }
                PathLine { x: page.seam; y: page.height }
            }
        }

        // the crease
        Rectangle {
            x: page.seam - 1
            width: 1.5
            height: page.height
            color: Theme.umber
            opacity: 0.22 * Math.sin(Math.PI * win.p)
        }
    }
}
