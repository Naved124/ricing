import QtQuick

// A flat button on glass: nothing until hovered (or `on`), then a faint light
// wash; rounded like the mock's icon buttons (11 px).
Rectangle {
    id: root

    property bool on: false
    property bool hovered: mouse.containsMouse
    property alias cursorShape: mouse.cursorShape
    property alias acceptedButtons: mouse.acceptedButtons
    signal clicked(var mouse)
    signal scrolled(real delta)

    radius: 11
    color: on || hovered ? Theme.hover : "transparent"
    Behavior on color { ColorAnimation { duration: 200 } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: m => root.clicked(m)
        onWheel: w => root.scrolled(w.angleDelta.y / 120)
    }
}
