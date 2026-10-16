import QtQuick
import QtQuick.Shapes
import qs.common
import qs.services
import "../common/paper.js" as P

// The battery, drawn: a crooked ink outline with up to four red tally
// strokes for the charge, a small bolt while charging. Click for the
// control centre. (The bar hides it where there's no battery.)
Item {
    id: root

    readonly property int strokes: Math.max(0, Math.min(4, Math.ceil(Battery.level * 4 - 0.15)))

    implicitWidth: label.implicitWidth + 4 + 38
    implicitHeight: 24

    Hand {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: "batt"
        color: Battery.low ? Theme.red : Theme.ink
    }

    Item {
        id: cell
        x: label.implicitWidth + 4
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 18

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.ink
                strokeWidth: 1.6
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap
                PathSvg {
                    path: P.pencil([[2, 3], [32, 2.5], [33, 15], [2.5, 15.5], [2, 3]], 11, 0.5, false)
                        + " " + P.pencil([[34, 6.5], [36.5, 6.8], [36.3, 11.4], [34, 11.5]], 12, 0.3, false)
                }
            }
            // the charge, in tally strokes
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.red
                strokeWidth: 1.4
                capStyle: ShapePath.RoundCap
                PathSvg {
                    path: [[5, 24, 4.6], [8, 24.5, 7.8], [11, 24, 11.2], [13.2, 23.5, 13.3]]
                        .slice(0, root.strokes)
                        .map(s => `M 4.5 ${s[0]} L ${s[1]} ${s[2]}`).join(" ") || "M 0 0"
                }
            }
        }

        Glyph {
            anchors.centerIn: parent
            visible: Battery.charging
            name: "bolt"
            size: 12
            penWidth: 1.2
            color: Theme.ink
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: Shell.toggleCenter()
    }
}
