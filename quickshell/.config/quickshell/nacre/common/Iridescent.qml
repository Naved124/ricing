import QtQuick
import qs

// The rotating conic gradient (rose → sky → mint → sun → orchid → rose).
// Reserved for focus and active state: the orb, the active workspace,
// progress fills, borders of focused things and the lock clock.
ShaderEffect {
    id: root

    property real radius: Math.min(width, height) / 2
    property real ring: 0              // > 0: only a border this wide
    property real sheen: 0.25
    property bool spinning: true
    property int period: 8000          // ms per full turn
    property real angle: 0

    readonly property color c0: Theme.gradient[0]
    readonly property color c1: Theme.gradient[1]
    readonly property color c2: Theme.gradient[2]
    readonly property color c3: Theme.gradient[3]
    readonly property color c4: Theme.gradient[4]
    readonly property size size: Qt.size(width, height)

    fragmentShader: Qt.resolvedUrl("../shaders/iridescent.frag.qsb")
    blending: true

    NumberAnimation on angle {
        running: root.spinning && root.visible
        from: 0
        to: Math.PI * 2
        duration: root.period
        loops: Animation.Infinite
    }
}
