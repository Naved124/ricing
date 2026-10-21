pragma ComponentBehavior: Bound

import QtQuick
import "reef.js" as World

// The reef: deep water with a living reef in it, the port of
// docs/abyss/reef-mock.html. Plain Qt Quick (no Quickshell), so the
// wallpaper, the lock screen and gen.py's still (tools/still.py) all run the
// same one. Wallpaper.qml feeds it the desktop (pointer, workspaces,
// notifications, music, throttling); Theme.qml its colours.
//
//   world     reef.js: the creatures and a coarse ripple field they feel
//   scene     what's drawn of them at `sceneScale` of the screen (Scene.qml)
//   ripples   the same field on the GPU, the one you see (Ripple.qml)
//   bloom     the scene at a quarter size, blurred (two Gaussian passes)
//   water     water.frag: gradient, rays, caustics, snow, refraction,
//             bloom, glints, vignette, tone map
//
// It ticks on a Timer at `fps` (15 when cut back) rather than every frame,
// so between ticks nothing changes and nothing is redrawn; `running: false`
// stops it outright. dt is in 60 Hz frames and clamped, so it resumes
// without a jump.
Item {
    id: reef

    // ── the look ───────────────────────────────────────────────────────────
    required property var colors        // Theme.reefColors
    required property color kelpColor   // Theme.c("kelp"): kelp is drawn on the GPU
    required property var hues          // Theme.reefHues
    required property vector3d waterTop
    required property vector3d waterMid
    required property vector3d waterBottom
    property url sprites: Qt.resolvedUrl("sprites")
    property url still: ""              // shown if the water shader can't load
    property int seed: 20261021

    // run the world on for `seconds` without drawing each step (a still)
    function advance(seconds) {
        const w = holder.world;
        if (!w) return;
        for (let i = 0; i < Math.round(seconds * 30); i++) { reef.time += 2 / 60; w.update(2, reef.time); }
        w.pending = [];
        water.sweep = w.sweep;
        water.beat = w.beat;
        scene.redraw();
    }

    // ── settings (~/.config/rice/abyss.toml) ───────────────────────────────
    property int fps: 30
    property real sceneScale: 0.55
    property int plankton: 620
    property int fish: 24
    property int jellies: 5
    property bool interactive: true
    property bool reducedMotion: false

    // ── state from outside ─────────────────────────────────────────────────
    property bool running: true         // false: no frames, no simulation
    property bool reduced: false        // 15 fps, half the plankton, no bloom
    property real dim: 1                // the lock screen's reef: 0.75
    property real bloomGain: 1.05
    property real dpr: 1
    property bool breathing: false      // music with no cava: a 0.5 Hz breath
    // for the stats: which screen, why it runs as it does, how covered it is
    property string name: ""
    property string throttle: ""
    property real coverage: 0

    // ── what it's doing (stats) ────────────────────────────────────────────
    readonly property int rate: reduced ? Math.min(15, fps) : fps
    property real fpsNow: 0
    property real msWorld: 0            // reef.js update, ms a frame
    property real msDraw: 0             // recording the canvas, ms a frame
    property real time: 0               // reef time, s (stops when stopped)
    readonly property alias world: holder.world
    readonly property size sceneSize: Qt.size(Math.max(2, Math.round(width * sceneScale)),
                                              Math.max(2, Math.round(height * sceneScale)))
    readonly property size bloomSize: Qt.size(Math.max(2, Math.round(sceneSize.width / 4)),
                                              Math.max(2, Math.round(sceneSize.height / 4)))
    readonly property size gridSize: Qt.size(ripples.cells, ripples.rows)
    readonly property bool failed: water.status === ShaderEffect.Error

    // ── the desktop touching the water ─────────────────────────────────────
    function press(x, y) { return world && interactive ? world.press(x, y) : ""; }
    function move(x, y) { if (world && interactive) world.move(x, y); }
    function release() { if (world) world.release(); }
    function leave() { if (world) world.leave(); }
    function switchWs(dir) { if (world) world.switchWs(dir); }
    function notify(x, y) { if (world) world.notify(x, y); }
    function disturb(x, y, strength) { if (world) world.disturb(x, y, strength); }
    function kick() { if (world) world.kick(); }
    // a fresh reef (a new size, seed or count)
    function rebuild() { holder.build(); }

    function stats() {
        const c = world ? world.counts() : {};
        return {
            fps: +fpsNow.toFixed(1), ms: +(msWorld + msDraw).toFixed(2),
            msWorld: +msWorld.toFixed(2), msDraw: +msDraw.toFixed(2),
            scene: `${sceneSize.width}x${sceneSize.height}`, bloom: reduced ? "off" : `${bloomSize.width}x${bloomSize.height}`,
            out: `${Math.round(width * dpr)}x${Math.round(height * dpr)}`, grid: `${ripples.cells}x${ripples.rows}`,
            plankton: c.plankton ?? 0, fish: c.fish ?? 0, jellies: c.jellies ?? 0, corals: c.corals ?? 0,
            fans: c.fans ?? 0, anemones: c.anemones ?? 0, kelp: c.kelp ?? 0,
            rate: running ? rate : 0, running: running, reduced: reduced, interactive: interactive,
            reducedMotion: reducedMotion, screen: name, throttle: throttle,
            coverage: Math.round(coverage * 100) / 100
        };
    }

    // ── the world ──────────────────────────────────────────────────────────
    QtObject {
        id: holder
        property var world: null
        function build() {
            if (reef.width < 2 || reef.height < 2) return;
            const w = World.create({
                seed: reef.seed, plankton: reef.plankton, fish: reef.fish, jellies: reef.jellies,
                hues: reef.hues, pal: reef.colors, sprite: scene.sprite
            });
            w.build(reef.width, reef.height);
            w.mot = reef.reducedMotion ? 0.45 : 1;
            world = w;
            ripples.calm();
            scene.rebuild();
            scene.load(w.spriteKeys());
            driver.last = 0;
            driver.step();          // a first frame, even when stopped
        }
    }
    onWidthChanged: rebuildLater.restart()
    onHeightChanged: rebuildLater.restart()
    onSeedChanged: rebuildLater.restart()
    onPlanktonChanged: rebuildLater.restart()
    onFishChanged: rebuildLater.restart()
    onJelliesChanged: rebuildLater.restart()
    Timer { id: rebuildLater; interval: 180; onTriggered: holder.build() }
    Component.onCompleted: holder.build()

    QtObject {
        id: driver
        property double last: 0
        property double fpsT: 0
        property int frames: 0
        function step() {
            const w = holder.world;
            if (!w) return;
            const now = Date.now();
            let raw = last ? now - last : 1000 / reef.rate;
            // back from a stop, or a long stall: carry on as if it were one frame
            if (raw > 250) raw = 1000 / reef.rate;
            last = now;
            const dt = Math.min(4, raw / 16.667);
            reef.time += dt / 60;
            w.mot = reef.reducedMotion ? 0.45 : 1;
            w.reduced = reef.reduced;
            w.interactive = reef.interactive;
            w.breath = reef.breathing;
            const c0 = Date.now();
            w.update(dt, reef.time);
            const c1 = Date.now();
            ripples.advance(Math.max(1, Math.round(dt)), w.pending);
            w.pending = [];
            water.sweep = w.sweep;
            water.beat = w.beat;
            scene.mot = w.mot;
            scene.flow = w.flow;
            scene.redraw();
            reef.msWorld += ((c1 - c0) - reef.msWorld) * 0.08;
            reef.msDraw += ((scene.lastMs) - reef.msDraw) * 0.08;
            frames++;
            if (now - fpsT >= 1000) {
                reef.fpsNow = frames * 1000 / (now - fpsT || 1);
                frames = 0;
                fpsT = now;
            }
        }
    }
    Timer {
        id: tick
        interval: Math.round(1000 / Math.max(1, reef.rate))
        repeat: true
        running: reef.running && reef.visible && !!holder.world
        onTriggered: driver.step()
        onRunningChanged: if (!running) { driver.last = 0; reef.fpsNow = 0; }
    }

    // ── what's drawn ───────────────────────────────────────────────────────
    Scene {
        id: scene
        world: holder.world
        sceneScale: reef.sceneScale
        width: reef.sceneSize.width
        height: reef.sceneSize.height
        time: reef.time
        sprites: reef.sprites
        kelpColor: reef.kelpColor
    }
    ShaderEffectSource {
        id: sceneTex
        sourceItem: scene.under
        hideSource: true
        textureSize: reef.sceneSize
        smooth: true
        visible: false
    }
    ShaderEffectSource {
        id: liveTex
        sourceItem: scene.live
        hideSource: true
        textureSize: reef.sceneSize
        smooth: true
        visible: false
    }

    Ripple {
        id: ripples
        worldWidth: reef.width
        worldHeight: reef.height
    }

    // ── bloom: a quarter of the scene, blurred ────────────────────────────
    Item {
        id: bloom
        visible: false
        width: reef.bloomSize.width
        height: reef.bloomSize.height
        ShaderEffect {
            id: down
            anchors.fill: parent
            property var src: sceneTex
            property var live: liveTex
            property vector2d texel: Qt.vector2d(1 / reef.sceneSize.width, 1 / reef.sceneSize.height)
            fragmentShader: Qt.resolvedUrl("shaders/down.frag.qsb")
        }
        ShaderEffectSource { id: downTex; sourceItem: down; hideSource: true; live: !reef.reduced; textureSize: reef.bloomSize }
        ShaderEffect {
            id: across
            anchors.fill: parent
            property var src: downTex
            property vector2d dir: Qt.vector2d(1 / reef.bloomSize.width, 0)
            fragmentShader: Qt.resolvedUrl("shaders/blur.frag.qsb")
        }
        ShaderEffectSource { id: acrossTex; sourceItem: across; hideSource: true; live: !reef.reduced; textureSize: reef.bloomSize }
        ShaderEffect {
            id: upDown
            anchors.fill: parent
            property var src: acrossTex
            property vector2d dir: Qt.vector2d(0, 1 / reef.bloomSize.height)
            fragmentShader: Qt.resolvedUrl("shaders/blur.frag.qsb")
        }
        ShaderEffectSource { id: blurTex; sourceItem: upDown; hideSource: true; live: !reef.reduced; textureSize: reef.bloomSize }
    }

    // ── the water ──────────────────────────────────────────────────────────
    ShaderEffect {
        id: water
        anchors.fill: parent
        property var scene: sceneTex
        property var live: liveTex
        property var blur: blurTex
        property var field: ripples.field
        property vector2d res: Qt.vector2d(width * reef.dpr, height * reef.dpr)
        property vector2d cells: Qt.vector2d(ripples.cells, ripples.rows)
        property real time: reef.time * (reef.reducedMotion ? 0.45 : 1)
        property real sweep: 0          // set each tick from the world
        property real beat: 0
        property real bloom: reef.reduced ? 0 : reef.bloomGain
        property real dim: reef.dim
        property vector3d surface: reef.waterTop
        property vector3d middle: reef.waterMid
        property vector3d deepest: reef.waterBottom
        fragmentShader: Qt.resolvedUrl("shaders/water.frag.qsb")
    }
    // the still, if the shader can't load
    Image {
        anchors.fill: parent
        visible: reef.failed && reef.still.toString() !== ""
        source: reef.failed ? reef.still : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // ── the pointer, where no window covers the water ─────────────────────
    MouseArea {
        anchors.fill: parent
        enabled: reef.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => reef.press(mouse.x, mouse.y)
        onPositionChanged: mouse => reef.move(mouse.x, mouse.y)
        onReleased: reef.release()
        onCanceled: reef.release()
        onExited: reef.leave()
    }
}
