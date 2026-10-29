import QtQuick
import QtQuick.Shapes

// Notion's mark, drawn: a page with an N on it, in the rice's text colour.
Item {
    id: g

    property real size: DeskTheme.textSize + 2
    property color color: DeskTheme.text

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: g.size * 0.18
        color: "transparent"
        border.color: g.color
        border.width: Math.max(1.2, g.size / 11)
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: g.color
            strokeWidth: Math.max(1.3, g.size / 10)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: g.size * 0.32; startY: g.size * 0.72
            PathLine { x: g.size * 0.32; y: g.size * 0.28 }
            PathLine { x: g.size * 0.68; y: g.size * 0.72 }
            PathLine { x: g.size * 0.68; y: g.size * 0.28 }
        }
    }
}
