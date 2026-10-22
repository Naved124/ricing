import QtQuick

// A soft round glow in one colour (a lit dot, the power menu's choice). `add` brightens what's behind it rather than covering it.
ShaderEffect {
    property color color: "transparent"
    property bool additive: true
    readonly property color tint: color
    readonly property real add: additive ? 1 : 0
    fragmentShader: Qt.resolvedUrl("../shaders/glow.frag.qsb")
}
