pragma ComponentBehavior: Bound

import QtQuick

// The ripple field the water shows, on the GPU: one texel per cell (the
// mock's grid, a seventh of the width), the height now in r and the step
// before in g, at half-float precision. Four chained passes take one to four
// steps a frame (60 a second whatever the frame rate); `field` feeds the
// first pass and the water. Drops arrive as [x, y, amp, radius] in screen px
// and land on the frame's first step (8 at most; the rest wait a frame).
// reef.js keeps the same field on the CPU for the creatures.
Item {
    id: root

    // the screen it covers, in px; the grid is the mock's (reef.js initWave)
    property real worldWidth: 1
    property real worldHeight: 1
    readonly property int cells: Math.round(Math.max(110, Math.min(230, worldWidth / 7)))
    readonly property int rows: Math.max(8, Math.round(cells * worldHeight / Math.max(1, worldWidth)))
    readonly property alias field: field

    width: cells
    height: rows
    visible: false

    property var queue: []
    property int steps: 0

    // n steps this frame, with these drops
    function advance(n, drops) {
        queue = queue.concat(drops);
        const now = queue.slice(0, 8);
        queue = queue.slice(8);
        const sx = cells / worldWidth, sy = rows / worldHeight;
        const v = now.map(d => Qt.vector4d(d[0] * sx, d[1] * sy, d[2], Math.max(1.2, d[3] * sx)));
        while (v.length < 8) v.push(Qt.vector4d(0, 0, 0, 1));
        first.d = v;
        first.nd = now.length;
        steps = Math.max(1, Math.min(4, n));
        s1.scheduleUpdate(); s2.scheduleUpdate(); s3.scheduleUpdate(); field.scheduleUpdate();
    }
    // a still sea (a resize, or after a long pause)
    function calm() {
        queue = [];
        clear.visible = true;
        field.scheduleUpdate();
        clearOff.restart();
    }
    Timer { id: clearOff; interval: 0; onTriggered: clear.visible = false }

    component Pass: ShaderEffect {
        property var src
        property int index: 0
        property var d: []
        property real nd: 0
        readonly property vector2d cells: Qt.vector2d(root.cells, root.rows)
        readonly property real on: index < root.steps ? 1 : 0
        readonly property vector4d d0: d[0] ?? Qt.vector4d(0, 0, 0, 1)
        readonly property vector4d d1: d[1] ?? Qt.vector4d(0, 0, 0, 1)
        readonly property vector4d d2: d[2] ?? Qt.vector4d(0, 0, 0, 1)
        readonly property vector4d d3: d[3] ?? Qt.vector4d(0, 0, 0, 1)
        readonly property vector4d d4: d[4] ?? Qt.vector4d(0, 0, 0, 1)
        readonly property vector4d d5: d[5] ?? Qt.vector4d(0, 0, 0, 1)
        readonly property vector4d d6: d[6] ?? Qt.vector4d(0, 0, 0, 1)
        readonly property vector4d d7: d[7] ?? Qt.vector4d(0, 0, 0, 1)
        width: root.cells
        height: root.rows
        blending: false
        fragmentShader: Qt.resolvedUrl("shaders/ripple.frag.qsb")
    }
    component Layer: ShaderEffectSource {
        live: false
        hideSource: true
        smooth: false
        format: ShaderEffectSource.RGBA16F
        textureSize: Qt.size(root.cells, root.rows)
        width: root.cells
        height: root.rows
    }

    // smooth: the water reads its slope between cells, as the mock's texture did
    Layer { id: field; sourceItem: last; recursive: true; smooth: true }
    Pass { id: first; src: field; index: 0 }
    Layer { id: s1; sourceItem: first }
    Pass { id: p2; src: s1; index: 1 }
    Layer { id: s2; sourceItem: p2 }
    Pass { id: p3; src: s2; index: 2 }
    Layer { id: s3; sourceItem: p3 }
    Item {
        id: last
        width: root.cells
        height: root.rows
        Pass { src: s3; index: 3 }
        // a still sea, over the last pass, for one update
        ShaderEffect {
            id: clear
            anchors.fill: parent
            visible: false
            blending: false
            fragmentShader: Qt.resolvedUrl("shaders/zero.frag.qsb")
        }
    }
}
