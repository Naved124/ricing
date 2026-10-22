pragma ComponentBehavior: Bound

import QtQuick
import qs.common

// One plate with its compositing pass (shaders/satsuei.frag): the desktop's
// wallpaper, the lock's background, the selector's live preview and the
// chooser's tile all draw it through this. The light comes from Theme.grade
// (one keyframe table for everything); each effect's strength is given
// 0–1 and eased by whoever holds it.
//
// The rays are worked out at an eighth of the size (shaders/rays.frag) and
// only when time moves: with `time` still and nothing changing, nothing
// redraws at all.
Item {
    id: root

    property string source: ""          // file:// the plate
    property string bloomSource: ""     // its blur maps; empty for a preview
    property string softSource: ""      //   (the plate's own mips stand in)
    property bool animated: false
    property bool playing: true         // an animated plate's frames
    property size plateSize: Qt.size(1920, 1080)
    property point light: Qt.point(0.69, 0.2)
    property point parallax: Qt.point(0, 0)
    property real time: 0
    property real bloom: 1
    property real rays: 1
    property real motes: 1
    property real grain: 0
    property real grade: 1
    property real pass: 1
    property real expo: 1
    property real seed: 0
    property Grade grading: Theme.grade
    readonly property bool ready: (animated ? anim.status : still.status) === Image.Ready
    readonly property bool maps: bloomSource !== "" && softSource !== ""

    // the plate, decoded no larger than it covers the screen at (the shader
    // covers the screen with it): a 4K picture sampled at 1080p with no mips
    // costs the pass more than all its effects
    readonly property size cover: {
        const W = Math.ceil(width * 1.04), H = Math.ceil(height * 1.04), I = plateSize;
        if (W <= 0 || H <= 0 || I.width <= 0 || I.height <= 0) return Qt.size(1920, 1080);
        // the side that covers decides; the other follows the picture
        return I.width / I.height > W / H ? Qt.size(0, Math.min(H, I.height)) : Qt.size(Math.min(W, I.width), 0);
    }
    Image {
        id: still
        visible: false
        source: root.animated ? "" : root.source
        asynchronous: true
        cache: false
        mipmap: !root.maps
        smooth: true
        sourceSize: root.maps ? root.cover : Qt.size(1280, 720)
    }
    AnimatedImage {
        id: anim
        visible: false
        source: root.animated ? root.source : ""
        asynchronous: true
        cache: false
        playing: root.playing
        smooth: true
    }
    Image {
        id: bloomImg
        visible: false
        source: root.bloomSource
        asynchronous: true
        cache: false
        smooth: true
    }
    Image {
        id: softImg
        visible: false
        source: root.softSource
        asynchronous: true
        cache: false
        smooth: true
    }
    readonly property Image plateTex: animated ? anim : still
    readonly property Image bloomTex: maps && bloomImg.status === Image.Ready ? bloomImg : plateTex
    readonly property Image softTex: maps && softImg.status === Image.Ready ? softImg : plateTex
    readonly property real lod: maps ? 0 : 3.4
    readonly property size plateSz: {
        // what was decoded (sourceSize reads back the 0 it was given)
        const t = plateTex;
        return t.implicitWidth > 0 && t.implicitHeight > 0 ? Qt.size(t.implicitWidth, t.implicitHeight) : root.plateSize;
    }

    // the shafts, an eighth of the size
    ShaderEffect {
        id: rayPass
        visible: false
        width: Math.max(16, Math.round(root.width / 8))
        height: Math.max(9, Math.round(root.height / 8))
        layer.enabled: root.rays > 0.001
        layer.smooth: true
        property vector2d res: Qt.vector2d(root.width, root.height)
        property vector2d img: Qt.vector2d(root.plateSz.width, root.plateSz.height)
        property vector2d light: Qt.vector2d(root.light.x, root.light.y)
        property vector2d par: Qt.vector2d(root.parallax.x, root.parallax.y)
        property real time: root.time
        property real mapLod: root.lod
        property var softMap: root.softTex
        fragmentShader: Qt.resolvedUrl("shaders/rays.frag.qsb")
    }

    ShaderEffect {
        id: main
        anchors.fill: parent
        visible: root.ready
        property vector2d res: Qt.vector2d(width, height)
        property vector2d img: rayPass.img
        property vector2d light: rayPass.light
        property vector2d par: rayPass.par
        property real time: root.time
        property real bloom: root.bloom
        property real rays: root.rays
        property real motes: root.motes
        property real grain: root.grain
        property real grade: root.grade
        property real pass: root.pass
        property real expo: root.expo
        property real sat: root.grading.sat
        property real rayAmt: root.grading.rays
        property real mapLod: root.lod
        property real seed: root.seed
        property vector3d mul: root.grading.mul
        property vector3d lift: root.grading.lift
        property vector3d rayCol: root.grading.rayCol
        property var plate: root.plateTex
        property var bloomMap: root.bloomTex
        property var softMap: root.softTex
        property var rayMap: rayPass
        fragmentShader: Qt.resolvedUrl("shaders/satsuei.frag.qsb")
    }
}
