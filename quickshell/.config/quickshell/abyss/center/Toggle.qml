import QtQuick
import qs
import qs.common

// A quick toggle as a glowing pill: an icon, a name and a state line. On,
// the pill lights from inside, teal, and its edge glows; off it's glass.
// Right-click does the second thing (settings, the other mode).
Item {
    id: root

    property string icon: "app"
    property string name: ""
    property string detail: ""
    property bool on: false
    property bool available: true

    signal toggled()
    signal secondary()

    implicitWidth: 160
    implicitHeight: 48
    opacity: available ? 1 : 0.45
    scale: mouse.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

    // the light inside, when on
    Glow {
        anchors.centerIn: parent
        width: parent.width * 1.25
        height: parent.height * 2.2
        color: Theme.glow
        opacity: root.on ? 0.22 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drift } }
    }
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.on ? Theme.washOn : mouse.containsMouse ? Theme.washHover : Theme.wash
        border.color: root.on ? Theme.lineOn : Theme.line
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }
    }

    Item {
        id: iconBox
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.on ? Theme.glowAt(0.18) : Theme.wash
            border.color: root.on ? Theme.lineOn : Theme.line
        }
        Icon {
            anchors.centerIn: parent
            name: root.icon
            size: 15
            color: root.on ? Theme.glow : Theme.inkDim
        }
    }
    Column {
        anchors.left: iconBox.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Label {
            width: parent.width
            text: root.name
            size: 12.5
            weight: Theme.weightStrong
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            text: root.detail
            visible: text !== ""
            size: 11
            color: Theme.inkDim
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.available
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton ? root.secondary() : root.toggled()
    }
}
