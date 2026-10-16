import QtQuick
import qs

// Open/close motion shared by every panel: blooms in from 96% with a fade
// (Theme.bloom, durPanelIn), sinks out (Theme.sink, durPanelOut).
// Set `shown`; read `settled` to know when it is fully hidden.
Item {
    id: root

    property bool shown: false
    property real fromScale: 0.96
    property point origin: Qt.point(width / 2, height / 2)
    readonly property bool settled: !shown && opacity === 0
    default property alias content: holder.data

    property real grow: shown ? 1 : fromScale

    opacity: shown ? 1 : 0
    visible: opacity > 0

    transform: Scale {
        origin.x: root.origin.x
        origin.y: root.origin.y
        xScale: root.grow
        yScale: root.grow
    }

    Behavior on opacity {
        NumberAnimation {
            duration: root.shown ? Theme.durPanelIn : Theme.durPanelOut
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.shown ? Theme.bloom : Theme.sink
        }
    }
    Behavior on grow {
        NumberAnimation {
            duration: root.shown ? Theme.durPanelIn : Theme.durPanelOut
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.shown ? Theme.bloom : Theme.sink
        }
    }

    Item {
        id: holder
        anchors.fill: parent
    }
}
