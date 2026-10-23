pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// A glass panel that opens over everything on one screen: a click outside
// it or Esc closes it. `name` is its Shell.open name; the pane is placed
// by paneX/paneY (from the screen's top left) at paneWidth × paneHeight.
PanelWindow {
    id: root

    required property string name
    property string part: name               // the layer namespace, goldengate:<part>
    property real paneX: 0
    property real paneY: 0
    property real paneWidth: 320
    property real paneHeight: 240
    property bool dim: false                 // darken the screen behind (Launchpad, Mission Control)
    property alias pane: glass
    default property alias content: glass.content
    // the screen's name, given once (reading `screen` here loops as the window maps)
    property string at: ""
    readonly property bool shown: Shell.open === name && (Shell.openScreen === "" || at === "" || Shell.openScreen === at)

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "goldengate:" + part
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: shown || glass.opacity > 0.01

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: root.dim && root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.panelIn } }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: Shell.closeAll()
    }

    GlassPane {
        id: glass
        x: root.paneX
        y: root.paneY
        width: root.paneWidth
        height: root.paneHeight
        screen: root.screen
        windowOrigin: Qt.point(0, 0)
        opened: root.shown
        thick: true
        focus: true
        opacity: root.shown ? 1 : 0
        scale: root.shown || Theme.reduceMotion ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: root.shown ? Theme.panelIn : Theme.panelOut } }
        Behavior on scale { SpringAnimation { spring: Theme.spring; damping: Theme.damping } }
        Keys.onEscapePressed: Shell.closeAll()
        // clicks on the pane stay on it
        MouseArea { anchors.fill: parent; z: -1 }
    }
    onShownChanged: if (shown) glass.forceActiveFocus()
}
