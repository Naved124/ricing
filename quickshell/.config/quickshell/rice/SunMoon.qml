import QtQuick
import QtQuick.Shapes

// A small sun or moon, drawn in one stroke colour on a 24×24 grid: which mode
// a rice opens in, in the corner of its chooser card.
Item {
    id: root

    property bool moon: false
    property color color: Theme.role("fg")

    Shape {
        anchors.fill: parent
        scale: root.width / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: 1.8
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: root.moon
                    ? "M20 14.5A8.5 8.5 0 1 1 9.5 4a6.8 6.8 0 0 0 10.5 10.5z"
                    : "M12 8a4 4 0 1 0 0.01 0z M12 2.5v2.5 M12 19v2.5 M2.5 12h2.5 M19 12h2.5 "
                      + "M5.2 5.2l1.8 1.8 M17 17l1.8 1.8 M5.2 18.8l1.8-1.8 M17 7l1.8-1.8"
            }
        }
    }
}
