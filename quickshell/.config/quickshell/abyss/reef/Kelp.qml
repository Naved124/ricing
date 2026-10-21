import QtQuick

// One kelp stalk, built and swayed by shaders/kelp.vert: a dark silhouette.
ShaderEffect {
    id: kelp

    required property var modelData       // the stalk, from reef.js
    required property var scene          // the Scene it belongs to

    width: scene.width
    height: scene.height
    mesh: GridMesh { resolution: Qt.size(1, 48) }
    property vector2d foot: Qt.vector2d(modelData.x, modelData.y)
    property real sceneScale: scene.sceneScale
    property real count: modelData.n
    property real seg: modelData.seg
    property real girth: modelData.w
    property real ph: modelData.ph
    property real wt: scene.time * 0.5 * scene.mot
    property real flow: scene.flow
    property color color: scene.kelpColor
    vertexShader: Qt.resolvedUrl("shaders/kelp.vert.qsb")
    fragmentShader: Qt.resolvedUrl("shaders/kelp.frag.qsb")
}
