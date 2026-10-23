import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// The shell's own Liquid Glass (shaders/liquid.frag), when no compositor
// plugin can draw it: what's behind the pane (the wallpaper, drawn again
// here exactly as the desktop draws it, or in Accurate mode a still of the
// screen taken as the pane opens), bent at the rim and blurred by the
// clarity. A layer surface can't see under itself, so this is a copy: windows
// behind the pane show only in Accurate mode, as they were when it opened.
Item {
    id: root

    // the pane this sits under, and where its window is on the screen
    required property Item pane
    property var screen: null
    property point windowOrigin: Qt.point(0, 0)
    property real radius: Theme.radiusPanel
    // Accurate: a still of the screen, taken again each time the pane opens
    property bool accurate: Settings.glass.accurate
    property bool opened: true
    // plain frost: no bend at the rim, blurred whatever the clarity
    property bool frost: false
    readonly property real pad: 24
    // while the still is taken: the pane hides so the capture doesn't see it
    readonly property bool capturing: shot.active

    readonly property real screenW: screen ? screen.width : 1920
    readonly property real screenH: screen ? screen.height : 1080
    // the pane's top-left on the screen, where it comes to rest (its own
    // slide transform isn't counted)
    property point at: Qt.point(0, 0)
    function place() {
        const p = pane.parent ? pane.parent.mapToItem(null, pane.x, pane.y) : Qt.point(pane.x, pane.y);
        at = Qt.point(windowOrigin.x + p.x, windowOrigin.y + p.y);
    }
    Component.onCompleted: place()
    onWindowOriginChanged: place()
    onWidthChanged: Qt.callLater(place)
    onHeightChanged: Qt.callLater(place)
    // a dragged pane (the desktop widgets) takes its picture along
    Connections {
        target: root.pane
        function onXChanged() { root.place() }
        function onYChanged() { root.place() }
    }
    // the pane's first frames are nearly transparent: the still is what's behind
    onOpenedChanged: if (opened) { place(); if (accurate) take(); }
    // an open pane would only see itself: the still waits for its next opening
    onAccurateChanged: if (accurate && !opened) take()
    Component.onDestruction: shot.active = false

    // An open capture holds the screen's screencopy, and grim and hyprlock then
    // wait on it forever, so it lives only until its frame is copied into
    // `still` (or two seconds, if no frame comes).
    function take() {
        shot.active = true;
        giveUp.restart();
    }
    Timer {
        id: giveUp
        interval: 2000
        onTriggered: shot.active = false
    }

    // what's behind, pad px past every side
    Item {
        id: stage
        x: -root.pad
        y: -root.pad
        width: root.width + 2 * root.pad
        height: root.height + 2 * root.pad
        clip: true

        Item {
            x: -(root.at.x - root.pad)
            y: -(root.at.y - root.pad)
            width: root.screenW
            height: root.screenH

            Picture { source: Walls.day; visible: !still.visible }
            Picture { source: Walls.night; visible: !still.visible && Walls.night !== ""; opacity: Theme.k }
            Image {
                id: still
                anchors.fill: parent
                visible: root.accurate && status === Image.Ready
                cache: false
            }
            Loader {
                id: shot
                anchors.fill: parent
                active: false
                sourceComponent: ScreencopyView {
                    captureSource: root.screen
                    live: false
                    onHasContentChanged: if (hasContent) grabToImage(r => {
                        still.source = r.url;
                        shot.active = false;
                    })
                }
            }
        }
    }

    ShaderEffectSource {
        id: sharp
        sourceItem: stage
        hideSource: true
        visible: false
        smooth: true
    }
    ShaderEffectSource {
        id: soft
        sourceItem: stage
        visible: false
        smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(stage.width / 8)), Math.max(1, Math.round(stage.height / 8)))
    }

    ShaderEffect {
        anchors.fill: parent
        opacity: root.capturing ? 0 : 1
        property var sharp: sharp
        property var soft: soft
        property size size: Qt.size(root.width, root.height)
        property real radius: root.radius
        property real rim: root.frost ? 0.5 : Math.min(22, Math.min(root.width, root.height) * 0.3)
        property real pad: root.pad
        property real clarity: root.frost ? 1 : Theme.clarity
        property real dark: Theme.k
        fragmentShader: Qt.resolvedUrl("../shaders/liquid.frag.qsb")
    }

    component Picture: Image {
        anchors.fill: parent
        asynchronous: true
        smooth: true
        sourceSize: Qt.size(root.screenW, root.screenH)
        fillMode: Walls.fillMode
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
    }
}
