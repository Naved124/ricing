import QtQuick
import QtQuick.Shapes

// Pencil hatching: diagonal ink strokes filling a box, like shading done by
// hand. Put it inside something that clips to show only part of it.
Item {
    id: root

    property color color: Theme.hatch
    property real gap: 5
    property real penWidth: 1.1

    readonly property string strokes: {
        const out = [];
        // lines at 60°, from below the bottom edge to above the top
        const rise = height / Math.tan(Math.PI / 3);
        for (let x = -rise; x < width + gap; x += gap)
            out.push(`M ${x.toFixed(1)} ${height} L ${(x + rise).toFixed(1)} 0`);
        return out.join(" ") || "M 0 0";
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.penWidth
            capStyle: ShapePath.RoundCap
            PathSvg { path: root.strokes }
        }
    }
}
