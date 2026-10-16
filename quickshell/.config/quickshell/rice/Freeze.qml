pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// One per monitor: the screenshot `rice` took just before switching, held
// above everything while the new rice loads underneath, then dissolved by
// the incoming rice's transition shader (~/.config/rices/<name>/transition.frag.qsb),
// or a plain fade when it has none.
PanelWindow {
    id: win

    required property var modelData
    property bool frozen: false
    property string frame: ""
    property url shader: Qt.resolvedUrl("shaders/fade.frag.qsb")
    property int duration: 600
    property real progress: 0

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

    function dissolve(shaderPath, ms) {
        if (!frozen) return;
        shader = shaderPath;
        duration = ms;
        anim.restart();
    }

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
        easing.type: Easing.Linear
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
