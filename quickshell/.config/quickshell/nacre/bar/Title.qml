import QtQuick
import Quickshell.Hyprland
import qs
import qs.common

// The active window's title. Cross-fades when it changes and fades out at
// the right edge instead of being cut off with an ellipsis.
EdgeFade {
    id: root

    required property var monitor
    readonly property var toplevel: Hyprland.activeToplevel
    readonly property string title: toplevel && toplevel.monitor === monitor ? toplevel.title : ""

    fadeWidth: 32
    active: a.implicitWidth > width || b.implicitWidth > width

    property bool showA: true

    onTitleChanged: {
        if (showA) b.text = title; else a.text = title;
        showA = !showA;
    }

    Label {
        id: a
        anchors.verticalCenter: parent.verticalCenter
        Component.onCompleted: text = root.title
        color: Theme.ink
        size: Theme.uiSize + 2
        opacity: root.showA ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bloom } }
    }

    Label {
        id: b
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.ink
        size: Theme.uiSize + 2
        opacity: root.showA ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bloom } }
    }
}
