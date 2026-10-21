import QtQuick
import qs
import qs.common

// A quick-settings tile: an icon in a pearl over a name and a state line.
// On, the tile wears the rose→sky wash and its pearl turns iridescent.
Item {
    id: root

    property string icon: "app"
    property string name: ""
    property string detail: ""
    property bool on: false
    property bool available: true
    property bool orient: false          // a small pearl turning its orient instead of the icon

    signal toggled()
    signal secondary()       // right-click

    implicitWidth: 112
    implicitHeight: 88
    opacity: available ? 1 : 0.45
    scale: mouse.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPopup + 4
        color: mouse.containsMouse ? Theme.pearl : Theme.glassSoft
        border.color: Theme.hairline
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPopup + 4
        opacity: root.on ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bloom } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.washFrom }
            GradientStop { position: 1; color: Theme.washTo }
        }
        border.color: Theme.hairline
    }

    Item {
        id: pearl
        anchors.horizontalCenter: parent.horizontalCenter
        y: 11
        width: 34
        height: 34

        Pearl {
            anchors.fill: parent
            gloss: root.on ? 0.8 : 0.4
            iri: root.on ? 0.6 : 0
        }
        Icon {
            anchors.centerIn: parent
            visible: !root.orient
            name: root.icon
            size: 17
            color: Theme.ink
        }
        Pearl {
            anchors.centerIn: parent
            visible: root.orient
            width: 16
            height: 16
            gloss: 0.6
            iri: 1
            spinning: root.orient && Theme.dark
        }
    }

    Column {
        anchors.top: pearl.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 6
        spacing: 0

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.name
            size: Theme.uiSize + 1
            weight: Theme.weightStrong
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.detail
            visible: text !== ""
            size: Theme.uiSize - 1
            color: Theme.inkSoft
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
