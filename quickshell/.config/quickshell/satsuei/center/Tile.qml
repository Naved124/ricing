import QtQuick
import qs.common

// A quick toggle, the mock's tile: an icon over a bold name and a small line
// of state; on, it fills with the accent (85%) and its text turns onAccent.
// Right-click does `secondary` (the record tile's region).
Rectangle {
    id: root

    property string icon: "app"
    property string title: ""
    property string sub: ""
    property bool on: false
    signal toggled()
    signal secondary()

    implicitHeight: 68
    radius: 14
    color: on ? Theme.at(Theme.accent, 0.85) : mouse.containsMouse ? Theme.at(Theme.fg, 0.1) : Theme.tile
    border.width: 1
    border.color: on ? "transparent" : Theme.tile
    Behavior on color { ColorAnimation { duration: 250 } }

    Column {
        x: 10
        y: 10
        width: parent.width - 20
        spacing: 8
        Icon { name: root.icon; color: root.on ? Theme.onAccent : Theme.fg }
        Column {
            width: parent.width
            Label {
                width: parent.width
                text: root.title
                size: 12
                weight: Style.weightStrong
                elide: Text.ElideRight
                color: root.on ? Theme.onAccent : Theme.fg
            }
            Label {
                width: parent.width
                text: root.sub
                size: 10.5
                elide: Text.ElideRight
                color: root.on ? Theme.at(Theme.onAccent, 0.7) : Theme.fgDim
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => m.button === Qt.RightButton ? root.secondary() : root.toggled()
    }
}
