import QtQuick
import qs.common

// A Control Center slider: a capsule filled to `value` of `max`, the glyph inside
Rectangle {
    id: root
    property string glyph: ""
    property real value: 0
    property real max: 1
    signal moved(real v)

    implicitHeight: 30
    radius: height / 2
    color: Theme.fill
    clip: true

    Rectangle {
        width: Math.max(parent.height, parent.width * Math.min(1, root.value / root.max))
        height: parent.height
        radius: parent.radius
        color: Theme.sliderFill
    }
    Label { x: 10; anchors.verticalCenter: parent.verticalCenter; text: root.glyph; color: Theme.label2; font.pixelSize: 14 }
    MouseArea {
        anchors.fill: parent
        function set(mx) { root.moved(Math.max(0, Math.min(1, mx / width)) * root.max); }
        onPressed: e => set(e.x)
        onPositionChanged: e => { if (pressed) set(e.x) }
        onWheel: e => root.moved(Math.max(0, Math.min(root.max, root.value + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
