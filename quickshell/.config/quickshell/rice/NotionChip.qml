import QtQuick

// A small pill: a due date, a status, a priority, a filter.
Rectangle {
    id: chip
    property string text: ""
    property string tone: "muted"       // a role
    property bool lit: false
    property bool clickable: false
    signal clicked()
    implicitWidth: label.implicitWidth + 14
    implicitHeight: 20
    radius: height / 2
    color: lit ? NotionLook.role(tone) : Qt.alpha(NotionLook.role(tone), mouse.containsMouse ? 0.22 : 0.13)
    NotionText {
        id: label
        anchors.centerIn: parent
        text: chip.text
        size: NotionLook.uiSize - 3
        bold: true
        // the tone mixed into the text colour, so a pastel accent still reads
        color: chip.lit ? NotionLook.on(NotionLook.role(chip.tone)) : NotionLook.ink(chip.tone)
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: chip.clickable
        hoverEnabled: chip.clickable
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
