import QtQuick
import qs
import qs.common
import qs.services

// The active window's title, just after the workspace pearls. A title too
// long for the room it has scrolls past and comes round again (Marquee);
// a new one fades in over the old.
Item {
    id: root

    required property var monitor
    // the focused window is on the focused monitor; other bars stay quiet
    readonly property string title: monitor?.focused ? (Hypr.activeTitle || Hypr.activeClass) : ""

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
        // read the title when the swap gets here, not when it was queued (a
        // bound value can still hold the previous window's)
        ScriptAction { script: line.text = root.title }
        NumberAnimation { target: line; property: "opacity"; to: 1; duration: Theme.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bloom }
    }
}
