import QtQuick

// The shader a custom character is drawn through (shaders/scenematch.frag):
// its colours remapped to the plate's tokens, lit and graded like the plate,
// with a rim toward the light, an optional outline and the plate's grain.
// Plain properties, no singletons: Custom.qml feeds it from Theme and the
// character's meta.json (and the tests feed it by hand).
//   rules    [{ from, to, tol, strength }], up to four (colours)
//   protect  [colour], up to four: never shifted
ShaderEffect {
    id: root

    property var source                              // the layer (or any texture provider)
    property var rules: []
    property var protect: []
    property vector3d mulV: Qt.vector3d(1, 1, 1)
    property vector3d liftV: Qt.vector3d(0, 0, 0)
    property real sat: 1
    property real expo: 1
    property real ambient: 0
    property real rim: 0
    property vector3d rimV: Qt.vector3d(1, 1, 1)
    property point light: Qt.point(0, -1)          // toward the light, y down
    property real outline: 0
    property color outlineCol: "transparent"
    property real grain: 0
    property real seed: Math.random() * 100

    function rule(i) { return rules[i] ?? null; }
    function c4(c, on) { return on ? Qt.vector4d(c.r, c.g, c.b, 1) : Qt.vector4d(0, 0, 0, 0); }

    readonly property vector4d from0: c4(Qt.color(rule(0)?.from ?? "transparent"), !!rule(0))
    readonly property vector4d from1: c4(Qt.color(rule(1)?.from ?? "transparent"), !!rule(1))
    readonly property vector4d from2: c4(Qt.color(rule(2)?.from ?? "transparent"), !!rule(2))
    readonly property vector4d from3: c4(Qt.color(rule(3)?.from ?? "transparent"), !!rule(3))
    readonly property vector4d to0: c4(Qt.color(rule(0)?.to ?? "transparent"), !!rule(0))
    readonly property vector4d to1: c4(Qt.color(rule(1)?.to ?? "transparent"), !!rule(1))
    readonly property vector4d to2: c4(Qt.color(rule(2)?.to ?? "transparent"), !!rule(2))
    readonly property vector4d to3: c4(Qt.color(rule(3)?.to ?? "transparent"), !!rule(3))
    readonly property vector4d tol: Qt.vector4d(rule(0)?.tol ?? 0.1, rule(1)?.tol ?? 0.1, rule(2)?.tol ?? 0.1, rule(3)?.tol ?? 0.1)
    readonly property vector4d strength: Qt.vector4d(rule(0)?.strength ?? 1, rule(1)?.strength ?? 1,
                                                     rule(2)?.strength ?? 1, rule(3)?.strength ?? 1)
    readonly property vector4d prot0: c4(Qt.color(protect[0] ?? "transparent"), protect.length > 0)
    readonly property vector4d prot1: c4(Qt.color(protect[1] ?? "transparent"), protect.length > 1)
    readonly property vector4d prot2: c4(Qt.color(protect[2] ?? "transparent"), protect.length > 2)
    readonly property vector4d prot3: c4(Qt.color(protect[3] ?? "transparent"), protect.length > 3)
    readonly property vector4d mul: Qt.vector4d(mulV.x, mulV.y, mulV.z, 1)
    readonly property vector4d lift: Qt.vector4d(liftV.x, liftV.y, liftV.z, 0)
    readonly property vector4d rimCol: Qt.vector4d(rimV.x, rimV.y, rimV.z, 1)
    readonly property point lightDir: {
        const l = Math.hypot(light.x, light.y) || 1;
        return Qt.point(light.x / l, light.y / l);
    }
    readonly property point texel: Qt.point(1 / Math.max(1, width), 1 / Math.max(1, height))

    fragmentShader: Qt.resolvedUrl("../shaders/scenematch.frag.qsb")
}
