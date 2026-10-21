import QtQuick

// One sea fan: drawn once at rest (reef.js bakeFan) and bent by
// shaders/fan.vert; its light is added to the scene.
Item {
    id: fan

    required property var modelData       // the fan, from reef.js
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
            ctx.setTransform(fan.s, 0, 0, fan.s, 0, 0);
            fan.scene.world.bakeFan(ctx, fan.modelData);
        }
        Component.onCompleted: requestPaint()
    }
    ShaderEffect {
        anchors.fill: parent
        property var src: ShaderEffectSource { sourceItem: bake; hideSource: true }
        mesh: GridMesh { resolution: Qt.size(18, 14) }
        property vector2d origin: Qt.vector2d(fan.rest.x0, fan.rest.y0)
        property real sceneScale: fan.s
        property vector2d foot: Qt.vector2d(fan.modelData.x, fan.modelData.y)
        property real len: fan.modelData.L
        property real bend: fan.scene.bendOf(fan.modelData, fan.scene.frame)
        property real excite: fan.scene.exciteOf(fan.modelData, fan.scene.frame)
        vertexShader: Qt.resolvedUrl("shaders/fan.vert.qsb")
        fragmentShader: Qt.resolvedUrl("shaders/fan.frag.qsb")
    }
}
