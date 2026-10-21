import QtQuick
import Quickshell
import qs.common

// The lamp's pull-chain, the mode toggle: a thin beaded chain hanging from
// the bar's right-hand tape, 18 px of 2 px graphite beads ending in a small
// pull bead (cream at night). A click tugs it down 6 px, lets it spring back
// on the drop curve and runs `rice mode toggle`. Hovering says "lamp on" or
// "lamp off"; a tiny "auto" sits beside it while the sun decides.
Item {
    id: root

    readonly property int beads: 6           // 6 × 3 px = 18 px of chain
    property real pull: 0

    implicitWidth: 14
    implicitHeight: beads * 3 + 9 + 6

    SequentialAnimation {
        id: tug
        NumberAnimation { target: root; property: "pull"; to: 6; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation {
            target: root; property: "pull"; to: 0; duration: Theme.durOpen
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drop
        }
    }

    Column {
        id: chain
        x: (root.width - 2) / 2
        y: root.pull
        spacing: 1
        Repeater {
            model: root.beads
            delegate: Rectangle { width: 2; height: 2; radius: 1; color: Theme.graphite }
        }
    }
    // the pull bead
    Rectangle {
        x: (root.width - width) / 2
        y: chain.y + chain.height + 1
        width: 7
        height: 9
        radius: 3.5
        color: Theme.carbon
        border.width: 1
        border.color: Qt.alpha(Theme.graphite, 0.6)
    }

    Hand {
        anchors.left: parent.right
        anchors.leftMargin: 3
        y: chain.height - 4
        visible: Theme.mode.auto
        text: "auto"
        size: 14
        color: Theme.graphite
    }
    Hand {
        anchors.right: parent.left
        anchors.rightMargin: 6
        y: chain.height - 4
        visible: area.containsMouse
        text: Theme.dark ? "lamp on" : "lamp off"
        size: 15
        color: Theme.ink
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            tug.restart();
            Quickshell.execDetached(["rice", "mode", "toggle"]);
        }
    }
}
