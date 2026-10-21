pragma ComponentBehavior: Bound

import QtQuick

// What's drawn of the reef, at `sceneScale` of the screen (scene px), in two
// layers that Reef.qml takes as textures:
//   under  what is dark or still, and what the GPU sways: the ridge, the
//          kelp, the back corals, the seafloor, the fans and corals, the
//          anemones' bodies. Corals and fans are drawn once at rest and
//          moved by their vertex shaders; ridge, floor and bodies are drawn
//          once; kelp is built by its own.
//   live   a canvas of everything that glows and moves on its own, redrawn
//          each tick (reef.js drawLive): tips, tentacles, the school, the
//          jellies, the plankton. It all adds light, so the water adds it.
// The order is the mock's; only the canvas's place among the additive
// things differs, which adds the same light.
Item {
    id: root

    property var world: null
    property real sceneScale: 0.55
    property real time: 0
    property url sprites
    property color kelpColor: "transparent"
    property real lastMs: 0          // recording the canvas, ms
    readonly property alias under: under
    readonly property alias live: live
    // bumped each tick, so the GPU things read the world again
    property int frame: 0
    // the world's lists, set when it's (re)built
    property var corals: []
    property var backCorals: []
    property var fans: []
    property var kelp: []
    // the world's pace (0.45 with reduced motion) and current, set each tick
    property real mot: 1
    property real flow: 0

    function sprite(h, s, l) { return `${root.sprites}/glow-${h}-${s}-${l}.png`; }
    // how lit a coral or fan is (1 + .25 when just touched) and how a fan
    // bends, read again each frame (the frame number is what changes)
    function gainOf(o, frame) { return 1 + 0.25 * o.excite; }
    function exciteOf(o, frame) { return o.excite; }
    function bendOf(o, frame) { return world ? world.fanBend(o, time) : 0; }
    function load(keys) {
        for (const k of keys) live.loadImage(sprite(k[0], k[1], k[2]));
    }
    // a new world: everything drawn once is drawn again
    function rebuild() {
        corals = []; backCorals = []; fans = []; kelp = [];
        if (!world) return;
        corals = world.corals; backCorals = world.backCorals; fans = world.fans; kelp = world.kelp;
        ridge.requestPaint(); floor.requestPaint(); bodies.requestPaint();
    }
    function redraw() {
        frame++;
        live.requestPaint();
    }

    // something drawn once, in world px
    component Still: Canvas {
        property var draw: null
        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.setTransform(1, 0, 0, 1, 0, 0);
            ctx.clearRect(0, 0, width, height);
            if (!root.world || !draw) return;
            ctx.setTransform(root.sceneScale, 0, 0, root.sceneScale, 0, 0);
            draw(ctx);
        }
    }

    Item {
        id: under
        width: root.width
        height: root.height

        Still { id: ridge; draw: ctx => root.world.drawRidge(ctx) }
        Repeater {
            model: root.kelp
            Kelp { scene: root }
        }
        Repeater {
            model: root.backCorals
            Coral { scene: root }
        }
        Still { id: floor; draw: ctx => root.world.drawFloor(ctx) }
        Repeater {
            model: root.fans
            Fan { scene: root }
        }
        Repeater {
            model: root.corals
            Coral { scene: root }
        }
        Still { id: bodies; draw: ctx => root.world.drawBases(ctx) }
    }

    Canvas {
        id: live
        width: root.width
        height: root.height
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Threaded
        onPaint: {
            if (!root.world) return;
            const c0 = Date.now();
            const ctx = getContext("2d");
            ctx.setTransform(1, 0, 0, 1, 0, 0);
            ctx.clearRect(0, 0, width, height);
            ctx.setTransform(root.sceneScale, 0, 0, root.sceneScale, 0, 0);
            root.world.drawLive(ctx, root.time);
            root.lastMs = Date.now() - c0;
        }
    }
}
