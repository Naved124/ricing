import QtQuick

// One coral: drawn once at rest (reef.js bakeCoral) and swayed by
// shaders/coral.vert; its light is added to the scene.
Item {
    id: coral

    required property var modelData       // the coral, from reef.js
    required property var scene          // the Scene it belongs to
    readonly property var rest: modelData.rest
    readonly property real s: scene.sceneScale

    x: rest.x0 * s
    y: rest.y0 * s
    width: Math.max(1, Math.ceil((rest.x1 - rest.x0) * s))
    height: Math.max(1, Math.ceil((rest.y1 - rest.y0) * s))

    Canvas {
        id: bake
        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.setTransform(1, 0, 0, 1, 0, 0);
            ctx.clearRect(0, 0, width, height);
            ctx.setTransform(coral.s, 0, 0, coral.s, 0, 0);
            coral.scene.world.bakeCoral(ctx, coral.modelData);
        }
        Component.onCompleted: requestPaint()
    }
    ShaderEffect {
        anchors.fill: parent
        property var src: ShaderEffectSource { sourceItem: bake; hideSource: true }
        mesh: GridMesh { resolution: Qt.size(4, 14) }
        property vector2d origin: Qt.vector2d(coral.rest.x0, coral.rest.y0)
        property real sceneScale: coral.s
        property vector2d foot: Qt.vector2d(coral.modelData.x, coral.modelData.y)
        property real tall: coral.rest.height
        property real swing: coral.rest.swing
        property real lean: coral.rest.lean
        property real ph: coral.modelData.ph
        property real wt: coral.scene.time * 0.85 * coral.scene.mot
        property real flow: coral.scene.flow
        property real gain: coral.scene.gainOf(coral.modelData, coral.scene.frame)
        vertexShader: Qt.resolvedUrl("shaders/coral.vert.qsb")
        fragmentShader: Qt.resolvedUrl("shaders/coral.frag.qsb")
    }
}
