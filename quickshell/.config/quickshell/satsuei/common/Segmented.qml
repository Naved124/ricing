pragma ComponentBehavior: Bound

import QtQuick

// A row of pills, one of them chosen (the accent fill): the strip's and the
// Cast picker's Dancer | Edge mascot. `options` is [{ value, text }].
Rectangle {
    id: root

    property var options: []
    property string value: ""
    signal picked(string value)

    width: pills.implicitWidth + 4
    height: 26
    radius: 13
    color: Theme.tile

    Row {
        id: pills
        x: 2
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: root.options
            delegate: Btn {
                id: pill
                required property var modelData
                width: label.implicitWidth + 20
                height: 22
                radius: 11
                on: root.value === modelData.value
                color: on ? Theme.at(Theme.accent, 0.85) : hovered ? Theme.hover : "transparent"
                onClicked: root.picked(modelData.value)
                Label {
                    id: label
                    anchors.centerIn: parent
                    text: pill.modelData.text
                    size: 11
                    weight: Style.weightStrong
                    color: pill.on ? Theme.onAccent : Theme.fg
                }
            }
        }
    }
}
