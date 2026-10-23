import QtQuick
import qs.common

// a frosted pill around one side's items
Rectangle {
    default property alias items: holder.data
    height: 28
    width: holder.implicitWidth + 8
    anchors.verticalCenter: parent.verticalCenter
    radius: height / 2
    color: Theme.glass
    border.width: 1
    border.color: Theme.glassEdge
    Rectangle {
        anchors { fill: parent; margins: 1 }
        radius: height / 2
        color: "transparent"
        border.width: 1
        border.color: Theme.glassRim
        opacity: 0.5
    }
    Row {
        id: holder
        anchors.centerIn: parent
        spacing: 0
    }
}
