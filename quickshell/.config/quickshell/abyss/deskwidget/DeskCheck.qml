import QtQuick
import QtQuick.Shapes

// A task's checkbox: an outline, filled with the accent and ticked when done.
Item {
    id: box

    property bool checked: false
    property bool busy: false       // waiting on desk-sync
    property real size: DeskTheme.textSize + 4

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: DeskTheme.radiusSmall / 2
        color: box.checked ? DeskTheme.accent : "transparent"
        border.color: box.checked ? DeskTheme.accent : DeskTheme.line
        border.width: 1.5
        opacity: box.busy ? 0.6 : 1
        Behavior on color { ColorAnimation { duration: DeskTheme.reducedMotion ? 0 : 160 } }
    }
    Shape {
        anchors.fill: parent
        visible: box.checked
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: DeskTheme.onAccent
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: box.size * 0.26; startY: box.size * 0.52
            PathLine { x: box.size * 0.44; y: box.size * 0.7 }
            PathLine { x: box.size * 0.76; y: box.size * 0.32 }
        }
    }
}
