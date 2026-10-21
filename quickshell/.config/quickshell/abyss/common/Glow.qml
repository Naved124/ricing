import QtQuick

// A soft round glow in one colour (a jelly's halo, a lit dot): the reef's
// glow falloff. `add` brightens what's behind it rather than covering it.
ShaderEffect {
    property color color: "transparent"
    property bool additive: true
    readonly property color tint: color
    readonly property real add: additive ? 1 : 0
    fragmentShader: Qt.resolvedUrl("../shaders/glow.frag.qsb")
}
