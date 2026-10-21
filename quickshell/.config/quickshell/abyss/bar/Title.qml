import QtQuick
import qs
import qs.common
import qs.services

// The active window's title, after the workspace dots, in ink-dim like the
// mock's status text. Too long for its room, it drifts past and comes
// round again (Marquee); a new one fades in over the old.
Item {
    id: root

    required property var monitor
    // the focused window is on the focused monitor; other bars stay quiet
    readonly property string title: monitor?.focused ? (Hypr.activeTitle || Hypr.activeClass) : ""

    implicitWidth: line.implicitWidth
    implicitHeight: 22
    clip: true

    onTitleChanged: swap.restart()

    Marquee {
        id: line
        property string text: root.title
        width: Math.round(root.width)
        height: root.height
        speed: 30
        delegate: Label {
            text: line.text
            color: Theme.inkDim
            size: Theme.uiSize - 2
            spacing: 0.08
        }
    }

    SequentialAnimation {
        id: swap
        NumberAnimation { target: line; property: "opacity"; to: 0; duration: 120 }
        // read the title when the swap gets here, not when it was queued (a
        // bound value can still hold the previous window's)
        ScriptAction { script: line.text = root.title }
        NumberAnimation { target: line; property: "opacity"; to: 1; duration: Theme.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drift }
    }
}
