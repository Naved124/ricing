import QtQuick
import qs.common

// A Control Center module: a round glyph that lights in the accent when on,
// its name and state beside it. Click toggles, right-click is `more`.
Rectangle {
    id: root
    property string glyph: ""
    property string title: ""
    property string detail: ""
    property bool on: false
    signal clicked()
    signal more()

    implicitHeight: 56
    radius: 18
    color: hover.hovered ? Theme.fillHover : Theme.fill

    Rectangle {
        id: dot
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 34; height: 34; radius: 17
        color: root.on ? Theme.accent : Theme.fillPress
        Behavior on color { ColorAnimation { duration: Theme.fadeMs } }
        Label {
            anchors.centerIn: parent
            text: root.glyph
            color: root.on ? Theme.onAccent : Theme.label
            font.pixelSize: 16
        }
    }
    Column {
        anchors { left: dot.right; leftMargin: 9; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        Label { width: parent.width; text: root.title; strong: true; font.pixelSize: Theme.smallSize + 1 }
        Label { width: parent.width; text: root.detail; secondary: true; font.pixelSize: Theme.smallSize; visible: text !== "" }
    }
    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? root.more() : root.clicked()
    }
}
