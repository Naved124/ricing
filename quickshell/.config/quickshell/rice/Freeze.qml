pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// One per monitor: the screenshot `rice` took just before switching, held
// above everything while the new rice loads underneath, then dissolved by
// the incoming rice's transition shader (~/.config/rices/<name>/transition.frag.qsb),
// or a plain fade when it has none. `rice mode` reveals the same way with the
// rice's mode shader (lamp, orient), which also reads origin, dark, tint and
// the target mode's gradient (c0–c4); shaders ignore what they don't declare.
PanelWindow {
    id: win

    required property var modelData
    property bool frozen: false
    property string frame: ""
    property url shader: Qt.resolvedUrl("shaders/fade.frag.qsb")
    property int duration: 600
    property real progress: 0
    property var curve: null              // Easing.BezierSpline points, or linear
    property point origin: Qt.point(0.5, 0.5)
    property real dark: 0
    property color tint: "transparent"
    property var stops: []

    screen: modelData
    visible: frozen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-freeze"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    function freeze(dir) {
        frameDir = dir;
        frame = "";          // force a reload even if the path repeats
        frame = `file://${dir}/${modelData.name}.png`;
        progress = 0;
        anim.stop();
        frozen = true;
    }
    property string frameDir: ""

    // params (for `rice mode`): { origin: [x, y], dark, tint, stops, curve }
    function dissolve(shaderPath, ms, params) {
        if (!frozen) return;
        const p = params ?? {};
        const o = p.origin ?? [0.5, 0.5];
        origin = Qt.point(o[0], o[1]);
        dark = p.dark ?? 0;
        tint = p.tint ?? "transparent";
        stops = p.stops ?? [];
        curve = p.curve ?? null;
        shader = shaderPath;
        duration = ms;
        anim.restart();
    }
    function stop(i) { return stops.length ? stops[i % stops.length] : "transparent"; }

    Image {
        id: shot
        anchors.fill: parent
        source: win.frame
        cache: false
        asynchronous: false
        fillMode: Image.Stretch
        visible: false
        // no per-monitor shot (grim without hyprctl): use the whole-desktop one
        onStatusChanged: {
            if (status === Image.Error && win.frameDir && !win.frame.endsWith("/all.png"))
                win.frame = `file://${win.frameDir}/all.png`;
        }
    }

    ShaderEffect {
        anchors.fill: parent
        property variant source: shot
        property real progress: win.progress
        property real aspect: width / Math.max(1, height)
        property point origin: win.origin
        property real dark: win.dark
        property color tint: win.tint
        property color c0: win.stop(0)
        property color c1: win.stop(1)
        property color c2: win.stop(2)
        property color c3: win.stop(3)
        property color c4: win.stop(4)
        fragmentShader: win.shader
        // a broken shader must not leave the screen frozen
        onStatusChanged: if (status === ShaderEffect.Error) win.shader = Qt.resolvedUrl("shaders/fade.frag.qsb")
    }

    NumberAnimation {
        id: anim
        target: win
        property: "progress"
        from: 0
        to: 1
        duration: win.duration
        easing.type: win.curve ? Easing.BezierSpline : Easing.Linear
        easing.bezierCurve: win.curve ?? []
        onFinished: {
            win.frozen = false;
            win.frame = "";
            win.progress = 0;
        }
    }

    // never stay frozen: if no dissolve arrives, let go after 8 s
    Timer {
        running: win.frozen && !anim.running
        interval: 8000
        onTriggered: win.dissolve(Qt.resolvedUrl("shaders/fade.frag.qsb"), 300)
    }
}
