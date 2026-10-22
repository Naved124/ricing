import QtQuick

// A check box and its words, on a flat button: Shuffle daily, Follow the
// clock.
Btn {
    id: root

    property bool checked: false
    property string text: ""
    signal toggled()

    width: row.implicitWidth + 16
    height: 26
    radius: 13
    onClicked: root.toggled()

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14
            radius: 4
            color: root.checked ? Theme.at(Theme.accent, 0.85) : "transparent"
            border.width: root.checked ? 0 : 1.2
            border.color: Theme.fgDim
            Icon {
                anchors.centerIn: parent
                visible: root.checked
                name: "check"
                size: 11
                stroke: 2.6
                color: Theme.onAccent
            }
        }
        Label { anchors.verticalCenter: parent.verticalCenter; text: root.text; size: 11; color: Theme.fgDim }
    }
}
