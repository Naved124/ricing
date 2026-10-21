pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.common
import qs.services
import "../common/paper.js" as P

// The wastebasket, bottom right: a pencil-drawn wire bin with a crumpled
// ball of paper for every window closed (up to nine show). Click to fish
// the last one out (it opens again); right-click to empty the bin, which
// tosses the balls out over the rim.
Item {
    id: root

    readonly property var shown: Bin.stack.slice(-Bin.maxShown)

    width: 96
    height: 112

    // the count, scribbled to the left
    Hand {
        anchors.right: parent.left
        anchors.rightMargin: 6
        y: 6
        rotation: -6
        text: Bin.count ? `${Bin.count} crumpled · click to fish out` : "empty bin"
        size: 15
        color: Theme.ink
    }

    // balls behind the front of the bin, stacked in rows of three
    Item {
        id: balls
        anchors.fill: parent

        Repeater {
            model: root.shown

            delegate: Item {
                id: ball

                required property var modelData
                required property int index
                readonly property real cx: 30 + (index % 3) * 18 + (index * 7 % 5)
                readonly property real cy: 24 - Math.floor(index / 3) * 10 - (index % 2) * 3
                readonly property var shape: P.crumple(cx, cy, 11, modelData.seed ?? index)

                anchors.fill: parent

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: Theme.wad
                        strokeColor: Theme.graphite
                        strokeWidth: 1
                        joinStyle: ShapePath.RoundJoin
                        PathSvg { path: ball.shape.outline }
                    }
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Theme.wadCrease
                        strokeWidth: 0.8
                        PathSvg { path: ball.shape.creases }
                    }
                }

                // a new ball lands with a little bounce
                property real drop: 0
                transform: Translate { y: ball.drop }
                Component.onCompleted: if (ball.index === root.shown.length - 1) land.start()
                SequentialAnimation {
                    id: land
                    NumberAnimation { target: ball; property: "drop"; from: -60; to: 0; duration: 420; easing.type: Easing.OutBounce }
                }
            }
        }

        // emptied: the balls fly up and out over the rim
        ParallelAnimation {
            id: toss
            NumberAnimation { target: balls; property: "y"; to: -140; duration: 520; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.toss }
            NumberAnimation { target: balls; property: "rotation"; to: 24; duration: 520 }
            NumberAnimation { target: balls; property: "opacity"; to: 0; duration: 520; easing.type: Easing.InQuad }
            onFinished: {
                Bin.empty();
                balls.y = 0;
                balls.rotation = 0;
                balls.opacity = 1;
            }
        }
    }

    // the bin: a wire basket in pencil
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Qt.alpha(Theme.basket, 0.08)
            strokeColor: Theme.pencil
            strokeWidth: 2.2
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: P.pencil([[8, 22], [88, 22], [78, 108], [18, 108], [8, 22]], 71, 0.7, true) }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(Theme.pencil, 0.55)
            strokeWidth: 1
            PathSvg {
                path: P.pencil([[14, 34], [82, 34]], 72, 0.6) + " " + P.pencil([[16, 50], [80, 50]], 73, 0.6) + " "
                    + P.pencil([[17, 66], [79, 66]], 74, 0.6) + " " + P.pencil([[19, 82], [77, 82]], 75, 0.6) + " "
                    + P.pencil([[20, 96], [76, 96]], 76, 0.6) + " " + P.pencil([[28, 22], [32, 108]], 77, 0.6) + " "
                    + P.pencil([[48, 22], [48, 108]], 78, 0.6) + " " + P.pencil([[68, 22], [64, 108]], 79, 0.6)
            }
        }
        // the rim
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.pencil
            strokeWidth: 2.2
            PathAngleArc { centerX: 48; centerY: 22; radiusX: 41; radiusY: 5; startAngle: 0; sweepAngle: 360 }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (Bin.count && !toss.running) toss.start();
            } else {
                Bin.fishOut();
            }
        }
    }
}
