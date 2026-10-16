import QtQuick
import qs
import qs.common

// A status chip: just an icon until hovered, then it opens to show its value.
Item {
    id: chip

    property string icon: "app"
    property color tint: Theme.ink
    property string label: ""
    property bool expanded: hover.hovered
    default property alias glyph: glyphSlot.data   // replaces the icon when set

    signal clicked(var mouse)
    signal scrolled(real delta)

    implicitHeight: 26
    implicitWidth: row.implicitWidth + 14

    Behavior on implicitWidth { NumberAnimation { duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: chip.expanded ? Theme.glassSoft : "transparent"
        border.color: chip.expanded ? Theme.hairline : "transparent"
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Item {
            id: glyphSlot
            // children[0] is the default icon; a chip may supply its own glyph
            readonly property bool custom: children.length > 1
            width: custom ? children[1].width : icon.width
            height: 18
            anchors.verticalCenter: parent.verticalCenter

            Icon {
                id: icon
                visible: !glyphSlot.custom
                name: chip.icon
                size: 17
                color: chip.tint
            }
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: chip.expanded && chip.label.length > 0 ? value.implicitWidth : 0
            height: value.implicitHeight
            clip: true
            Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

            Label {
                id: value
                text: chip.label
                size: Theme.uiSize + 1
                opacity: chip.expanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => chip.clicked(mouse)
        onWheel: wheel => chip.scrolled(wheel.angleDelta.y / 120)
    }
}
