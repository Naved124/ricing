import QtQuick
import QtQuick.Shapes

// One filled (or stroked) shape of a character, in the rig's 120 × 160
// coordinates. The curve renderer keeps the edges smooth at any size with no
// multisampling.
Shape {
    id: s

    property string d: ""
    property color fill: "transparent"
    property color stroke: "transparent"
    property real line: 0
    property alias gradient: path.fillGradient

    width: 120
    height: 160
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        id: path
        fillColor: s.fill
        strokeColor: s.stroke
        strokeWidth: s.line > 0 ? s.line : -1
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathSvg { path: s.d }
    }
}
