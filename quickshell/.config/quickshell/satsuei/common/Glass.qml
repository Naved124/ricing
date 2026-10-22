import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// The cel layer's glass, the mock's: the plate's darkest colour at 40% over
// Hyprland's blur, a 1 px light rim, a soft highlight along the top inside
// edge, a faint diagonal sheen that leans to the accent at its far corner,
// and a large soft shadow (0 20px 50px, pulled in 14px, at 50%).
Item {
    id: root

    property real radius: Style.radiusPanel
    property color fill: Theme.glassFill
    property bool shadow: true
    property bool sheen: true
    default property alias content: inner.data

    RectangularShadow {
        anchors.fill: plate
        anchors.margins: 14
        visible: root.shadow
        radius: root.radius
        offset.y: 20
        blur: 50
        spread: 0
        color: Theme.shadowCol
    }
    Rectangle {
        id: plate
        anchors.fill: parent
        radius: root.radius
        color: root.fill
        border.color: Theme.rim
        border.width: 1
    }
    // the highlight: 1 px of light just inside the top edge
    Rectangle {
        x: root.radius * 0.7
        y: 1
        width: Math.max(0, parent.width - root.radius * 1.4)
        height: 1
        color: Theme.highlight
    }
    // the sheen: 140°, light at the top left, nothing in the middle, a touch of
    // the accent at the bottom right
    Shape {
        anchors.fill: parent
        visible: root.sheen && width > 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0; y1: 0
                x2: root.width; y2: root.width * 0.84
                GradientStop { position: 0.0; color: Theme.sheen }
                GradientStop { position: 0.38; color: "transparent" }
                GradientStop { position: 0.7; color: "transparent" }
                GradientStop { position: 1.0; color: Theme.sheenTint }
            }
            PathRectangle {
                width: root.width
                height: root.height
                radius: root.radius
            }
        }
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
