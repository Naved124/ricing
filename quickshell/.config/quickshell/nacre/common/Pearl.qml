import QtQuick
import qs

// A small pearl: matte when empty, glossy when something is in it,
// iridescent at the rim when it matters.
ShaderEffect {
    id: root

    property color base: Theme.pearl
    property color shade: Theme.lilac
    property real gloss: 0.6
    property real iri: 0.0
    property real angle: 0
    property bool spinning: iri > 0

    readonly property color c0: Theme.gradient[0]
    readonly property color c1: Theme.gradient[1]
    readonly property color c2: Theme.gradient[2]
    readonly property color c3: Theme.gradient[3]
    readonly property color c4: Theme.gradient[4]

    fragmentShader: Qt.resolvedUrl("../shaders/pearl.frag.qsb")
    blending: true

    Behavior on gloss { NumberAnimation { duration: Theme.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bloom } }
    Behavior on iri { NumberAnimation { duration: Theme.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bloom } }

    NumberAnimation on angle {
        running: root.spinning && root.visible
        from: 0
        to: Math.PI * 2
        duration: 6000
        loops: Animation.Infinite
    }
}
