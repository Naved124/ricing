import QtQuick
import QtQuick.Shapes

// A round tick box: fills with the accent and draws its tick when on.
Item {
    id: box
    property bool on: false
    property bool urgent: false
    signal toggled()
    implicitWidth: 18
    implicitHeight: 18

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: box.on ? NotionLook.role("accent") : hover.containsMouse ? Qt.alpha(NotionLook.role("accent"), 0.14) : "transparent"
        border.width: box.on ? 0 : 1.5
        border.color: box.urgent ? NotionLook.ink("urgent") : hover.containsMouse ? NotionLook.role("accent") : NotionLook.role("muted")
        Behavior on color { ColorAnimation { duration: 160 } }
        scale: hover.pressed ? 0.86 : 1
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: box.on ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        ShapePath {
            fillColor: "transparent"
            strokeColor: NotionLook.on(NotionLook.role("accent"))
            strokeWidth: 2
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: box.width * 0.28; startY: box.height * 0.52
            PathLine { x: box.width * 0.44; y: box.height * 0.68 }
            PathLine { x: box.width * 0.73; y: box.height * 0.35 }
        }
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: box.toggled()
    }
}
