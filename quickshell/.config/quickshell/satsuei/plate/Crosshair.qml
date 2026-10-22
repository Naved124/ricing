import QtQuick
import qs.common

// Picking the light source: a crosshair that follows the pointer over the
// plate, with a hint, until a click (Plate.qml writes it with satsuei-wall).
Item {
    id: root
    property point at: Qt.point(width / 2, height / 2)
    HoverHandler { onPointChanged: root.at = point.position }
    Rectangle { x: 0; y: root.at.y; width: root.width; height: 1; color: Theme.at(Theme.accent, 0.7) }
    Rectangle { x: root.at.x; y: 0; width: 1; height: root.height; color: Theme.at(Theme.accent, 0.7) }
    Rectangle {
        x: root.at.x - 14; y: root.at.y - 14
        width: 28; height: 28; radius: 14
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.12
        radius: 999
        color: Theme.glassDeep
        border.color: Theme.rim
        width: hint.implicitWidth + 36
        height: 40
        Text {
            id: hint
            anchors.centerIn: parent
            text: "Click where the light comes from · Esc to cancel"
            color: Theme.fg
            font.family: Style.fontUi
            font.pixelSize: 14
            font.weight: Style.weightStrong
        }
    }
}
