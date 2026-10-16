import QtQuick
import QtQuick.Shapes
import "paper.js" as P

// A loop drawn round something in red pen. `drawn` draws it in (500 ms, the
// pen moving along the loop); clearing it erases it the same way back.
// Seeded, so every instance is a slightly different loop.
Item {
    id: root

    property bool drawn: false
    property int seed: 1
    property color color: Theme.red
    property real penWidth: 2
    property int duration: 500

    // 0 → nothing on the paper, 1 → the whole loop. Starts empty and binds
    // once created, so a loop that is born drawn still draws itself in.
    property real progress: 0
    Behavior on progress { NumberAnimation { duration: root.duration; easing.type: Easing.InOutQuad } }
    Component.onCompleted: progress = Qt.binding(() => root.drawn ? 1 : 0)

    readonly property var loop: P.scribble(width, height, seed)
    // dashes are measured in pen widths
    readonly property real units: loop.length / penWidth + 2

    visible: progress > 0.001

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.penWidth
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            strokeStyle: ShapePath.DashLine
            dashPattern: [root.units, root.units]
            dashOffset: root.units * (1 - root.progress)
            PathSvg { path: root.loop.path }
        }
    }
}
