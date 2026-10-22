pragma ComponentBehavior: Bound

import QtQuick

// Wraps an item and fades its right (and optionally left) edge to nothing.
Item {
    id: root

    property real fadeWidth: 28       // px
    property real leftFade: 0         // px
    property bool active: true
    default property alias content: holder.data

    clip: true

    Item {
        id: holder
        anchors.fill: parent
        layer.enabled: root.active
        layer.effect: ShaderEffect {
            fragmentShader: Qt.resolvedUrl("../shaders/fade.frag.qsb")
            property real fadeStart: Math.max(0, 1 - root.fadeWidth / Math.max(1, root.width))
            property real fadeLeft: root.leftFade / Math.max(1, root.width)
        }
    }
}
