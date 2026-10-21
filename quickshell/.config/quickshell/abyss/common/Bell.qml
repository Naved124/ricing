import QtQuick
import QtQuick.Shapes
import qs

// A small jelly's bell, glowing: the notification glyph (its colour says how
// urgent: teal normal, violet low, pink critical) and the island's count.
// The mock's: a dome 12 × 9 with a soft glow of its own colour; `pulse`
// breathes it slowly, `tentacles` lets a few threads hang below.
Item {
    id: root

    property color color: Theme.glow
    property bool pulse: false
    property bool tentacles: false
    property real glow: 0.9

    implicitWidth: 12
    implicitHeight: 9

    Glow {
        anchors.centerIn: dome
        width: dome.width * 3
        height: width
        color: root.color
        opacity: root.glow * (0.45 + 0.35 * breath.v)
    }
    QtObject {
        id: breath
        property real v: 0.5
        SequentialAnimation on v {
            running: root.pulse
            loops: Animation.Infinite
            NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.2; duration: 1100; easing.type: Easing.InOutSine }
        }
    }

    Shape {
        id: dome
        width: root.width
        height: root.height
        preferredRendererType: Shape.CurveRenderer
        scale: 1 + (root.pulse ? 0.12 * (breath.v - 0.5) : 0)
        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            // a dome, its rim scalloped like the reef's jellies
            startX: 0; startY: dome.height * 0.78
            PathCubic {
                x: dome.width; y: dome.height * 0.78
                control1X: 0; control1Y: -dome.height * 0.25
                control2X: dome.width; control2Y: -dome.height * 0.25
            }
            PathQuad { x: dome.width * 0.75; y: dome.height * 0.78; controlX: dome.width * 0.875; controlY: dome.height }
            PathQuad { x: dome.width * 0.5; y: dome.height * 0.78; controlX: dome.width * 0.625; controlY: dome.height }
            PathQuad { x: dome.width * 0.25; y: dome.height * 0.78; controlX: dome.width * 0.375; controlY: dome.height }
            PathQuad { x: 0; y: dome.height * 0.78; controlX: dome.width * 0.125; controlY: dome.height }
        }
    }
    Shape {
        visible: root.tentacles
        anchors.top: dome.bottom
        anchors.topMargin: -1
        width: root.width
        height: root.height * 0.9
        preferredRendererType: Shape.CurveRenderer
        opacity: 0.6
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: 0.9
            capStyle: ShapePath.RoundCap
            PathSvg { path: `M ${root.width * 0.3} 0 q -1.5 ${root.height * 0.45} 0 ${root.height * 0.9} M ${root.width * 0.5} 0 q 1.5 ${root.height * 0.45} 0 ${root.height * 0.9} M ${root.width * 0.7} 0 q -1.5 ${root.height * 0.45} 0 ${root.height * 0.9}` }
        }
    }
}
