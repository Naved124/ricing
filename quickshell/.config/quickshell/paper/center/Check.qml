import QtQuick
import QtQuick.Shapes
import qs.common
import "../common/paper.js" as P

// A checkbox drawn in ink, a red tick when on, its label in Kalam (and a
// smaller note after it). Click to toggle; right-click for `secondary`.
Item {
    id: root

    property string label
    property string detail
    property bool on: false
    property bool available: true
    signal toggled()
    signal secondary()

    implicitWidth: parent ? parent.width : 300
    implicitHeight: 30
    opacity: available ? 1 : 0.4

    Item {
        id: box
        x: 2
        anchors.verticalCenter: parent.verticalCenter
        width: 17
        height: 17
        rotation: -3

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.ink
                strokeWidth: 1.6
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: P.pencil([[0.5, 1], [16.5, 0.5], [16, 16.5], [1, 16.2], [0.5, 1]], P.hash(root.label), 0.6, false) }
            }
        }
        // the tick, overshooting the box like a quick hand
        Shape {
            x: 2
            y: -7
            width: 22
            height: 22
            visible: root.on
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.red
                strokeWidth: 2.2
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M 1 12 Q 5 15 7 19 Q 11 9 21 1" }
            }
        }
    }

    Row {
        x: 30
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Hand {
            id: name
            text: root.label
            size: 19
            color: Theme.ink
        }
        Hand {
            anchors.baseline: name.baseline
            visible: text.length > 0
            text: root.detail
            size: 14
            color: Theme.graphite
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.width - 140)
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.available
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => mouse.button === Qt.RightButton ? root.secondary() : root.toggled()
    }
}
