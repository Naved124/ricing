import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.chars
import qs.common
import qs.services

// The edge mascot: the character cast as the mascot, 8% in from the right
// edge of the focused screen, sitting below the edge with only the top of its
// head showing (the mock's 132 × 152, 114 px down). A notification that
// shows as a subtitle springs it up to the shoulders, waving, for 4.2 s; after
// 40 s with no input it falls asleep (a built-in sleeps its own way under a
// "z z Z", a custom one dims under its own); a click on its head makes it hop.
// Hidden while the screen has a fullscreen window, while locked, or with the
// control centre's Mascot tile off. Only its head takes the pointer.
PanelWindow {
    id: win

    screen: Hypr.focusedScreen
    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property bool shown: Settings.s.mascot && !Hypr.fullscreenOn(monitor) && !Shell.locked
    property bool waving: false
    readonly property bool asleep: idle.isIdle && !waving
    // how far below the edge: resting, peeking, or put away
    readonly property real down: !shown ? 170 : waving ? 34 : 114

    visible: shown || body.y < 170
    anchors { bottom: true; right: true }
    margins.right: Math.round((screen?.width ?? 1920) * 0.08)
    implicitWidth: 132
    implicitHeight: 176
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "satsuei-mascot"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: head }

    IdleMonitor {
        id: idle
        timeout: 40
        respectInhibitors: true
    }

    // a subtitle went up: peek and wave
    Connections {
        target: Notifs
        function onArrived(n) {
            if (Shell.dnd && !Notifs.critical(n)) return;
            win.waving = true;
            wave.restart();
        }
    }
    Timer { id: wave; interval: 4200; onTriggered: win.waving = false }

    Item {
        id: body
        x: 0
        width: 132
        height: 152
        y: 24 + win.down
        Behavior on y {
            NumberAnimation { duration: 700; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.3, 1.5, 0.5, 1, 1, 1] }
        }
        // the click's hop
        property real hop: 0
        transform: Translate { y: -body.hop }
        SequentialAnimation {
            id: hopping
            NumberAnimation { target: body; property: "hop"; to: 18; duration: 160; easing.type: Easing.OutQuad }
            NumberAnimation { target: body; property: "hop"; to: 0; duration: 420; easing.type: Easing.OutBounce }
        }

        Actor {
            anchors.fill: parent
            cast: Characters.mascot
            mode: win.waving || hopping.running ? "wave" : win.asleep ? "sleep" : "idle"
            energy: 0.7
            interval: win.waving || hopping.running ? 33 : 66
            running: win.visible
        }

        // asleep: z z Z over a built-in (a custom one floats its own)
        Label {
            x: -10
            y: -6
            display: true
            size: 15
            text: "z z Z"
            opacity: win.asleep && Characters.mascot.builtin ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }

        // the head: what peeks above the edge, and all that takes a click
        Item {
            id: head
            x: 26
            y: 6
            width: 80
            height: Math.max(0, Math.min(90, 152 - win.down - 6))
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: hopping.restart()
            }
        }
    }
}
