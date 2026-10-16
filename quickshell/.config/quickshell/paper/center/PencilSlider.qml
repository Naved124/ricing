import QtQuick
import QtQuick.Shapes
import qs.common
import "../common/paper.js" as P

// A level as a pencil line with a red dot to drag: the line is drawn darker
// up to the dot. `max` may be past 1 (the speaker goes to 150%), with a
// small tick at 100%.
Item {
    id: root

    property string glyph: "speaker"
    property real value: 0
    property real max: 1
    property bool muted: false
    property bool available: true
    signal moved(real value)
    signal glyphClicked()

    implicitWidth: parent ? parent.width : 300
    implicitHeight: 32
    opacity: available ? 1 : 0.4

    readonly property real frac: Math.max(0, Math.min(1, value / max))

    Glyph {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        name: root.glyph
        size: 20
        color: root.muted ? Theme.graphite : Theme.ink
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: root.glyphClicked()
        }
    }

    Item {
        id: track
        anchors.left: icon.right
        anchors.leftMargin: 14
        anchors.right: pct.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 20

        // the whole line, faint; then the part up to the dot, firm
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(Theme.pencil, 0.35)
                strokeWidth: 1.4
                capStyle: ShapePath.RoundCap
                PathSvg { path: P.pencil([[0, 10], [track.width, 10]], 5 + Math.round(track.width), 0.8, false) }
            }
        }
        Item {
            width: track.width * root.frac
            height: parent.height
            clip: true
            Shape {
                width: track.width
                height: track.height
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.muted ? Theme.graphite : Theme.ink
                    strokeWidth: 2
                    capStyle: ShapePath.RoundCap
                    PathSvg { path: P.pencil([[0, 10], [track.width, 10]], 9 + Math.round(track.width), 0.8, false) }
                }
            }
        }
        Rectangle {
            visible: root.max > 1
            x: track.width / root.max
            y: 4
            width: 1
            height: 12
            color: Qt.alpha(Theme.pencil, 0.6)
        }
        Rectangle {
            x: track.width * root.frac - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: drag.pressed ? 14 : 12
            height: width
            radius: width / 2
            color: Theme.red
            Behavior on width { NumberAnimation { duration: 120 } }
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            anchors.topMargin: -6
            anchors.bottomMargin: -6
            enabled: root.available
            cursorShape: Qt.PointingHandCursor
            function set(x) { root.moved(Math.max(0, Math.min(1, x / track.width)) * root.max); }
            onPressed: mouse => set(mouse.x)
            onPositionChanged: mouse => { if (pressed) set(mouse.x); }
            onWheel: wheel => root.moved(Math.max(0, Math.min(root.max, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }

    Hand {
        id: pct
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 46
        horizontalAlignment: Text.AlignRight
        text: `${Math.round(root.value * 100)}%`
        size: 16
        color: root.value > 1 ? Theme.red : Theme.pencil
        font.features: { "tnum": 1 }
    }
}
