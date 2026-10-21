import QtQuick
import Quickshell.Hyprland
import qs
import qs.common

// The active window's title, just after the workspace pearls. A title too
// long for the room it has scrolls past and comes round again (Marquee);
// a new one fades in over the old.
Item {
    id: root

    required property var monitor
    readonly property var toplevel: Hyprland.activeToplevel
    readonly property string title: toplevel && toplevel.monitor === monitor ? toplevel.title : ""

    implicitWidth: line.implicitWidth
    implicitHeight: 26
    clip: true

    onTitleChanged: swap.restart()

    Marquee {
        id: line
        property string text: root.title
        width: Math.round(root.width)
        height: root.height
        delegate: Label {
            text: line.text
            color: Theme.ink
            size: Theme.uiSize + 2
        }
    }

    // a new title: out and back in
    SequentialAnimation {
        id: swap
        NumberAnimation { target: line; property: "opacity"; to: 0; duration: 120 }
        PropertyAction { target: line; property: "text"; value: root.title }
        NumberAnimation { target: line; property: "opacity"; to: 1; duration: Theme.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bloom }
    }
}
