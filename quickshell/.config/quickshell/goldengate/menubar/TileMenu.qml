pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.common
import qs.services

// The green light's menu, as macOS has it over the button: Move & Resize
// (the halves and the quarters, drawn as little screens), then Fill,
// Center and Full Screen. `gg win tilemenu` opens it under the pointer for
// the window whose button was clicked (Shell.tileFor).
Panel {
    id: root

    name: "tilemenu"
    part: "controlcenter"
    paneWidth: 236
    paneHeight: col.implicitHeight + 16
    readonly property var at_: Shell.tileFor
    paneX: at_ && screen ? Math.max(8, Math.min(screen.width - paneWidth - 8, at_.x - screen.x - 24)) : 0
    paneY: at_ && screen ? Math.max(8, Math.min(screen.height - paneHeight - 8, at_.y - screen.y + 14)) : 0
    pane.radius: Theme.radiusPopup

    function act(args) {
        const a = Shell.tileFor ? Shell.tileFor.address : "";
        Shell.closeAll();
        Shell.gg(["win"].concat(args).concat(a ? [a] : []));
    }

    // a screen with the part the window would take: x, y, w, h as fractions
    component Shape: Rectangle {
        id: shape
        property var part: [0, 0, 1, 1]
        property var go: []
        property string tip: ""
        width: 44; height: 30; radius: 6
        color: hover.containsMouse ? Theme.fillHover : "transparent"
        Rectangle {
            id: scr
            anchors.centerIn: parent
            width: 34; height: 22; radius: 4
            color: "transparent"
            border.width: 1.5
            border.color: hover.containsMouse ? Theme.accent : Theme.label
            opacity: hover.containsMouse ? 1 : 0.7
            Rectangle {
                x: 3 + shape.part[0] * (scr.width - 6)
                y: 3 + shape.part[1] * (scr.height - 6)
                width: shape.part[2] * (scr.width - 6)
                height: shape.part[3] * (scr.height - 6)
                radius: 1.5
                color: hover.containsMouse ? Theme.accent : Theme.label
            }
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.act(shape.go)
        }
    }
    component Item_: Rectangle {
        id: item
        property string text: ""
        property var go: []
        width: col.width; height: 26; radius: 6
        color: m.containsMouse ? Theme.accent : "transparent"
        Label {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            text: item.text
            color: m.containsMouse ? Theme.onAccent : Theme.label
        }
        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; onClicked: root.act(item.go) }
    }

    Column {
        id: col
        x: 8; y: 8
        width: root.paneWidth - 16
        spacing: 2
        Label { x: 10; text: qsTr("Move & Resize"); secondary: true; font.pixelSize: Theme.smallSize }
        Row {
            x: 4
            spacing: 6
            Shape { part: [0, 0, 0.5, 1]; go: ["tile", "left"] }
            Shape { part: [0.5, 0, 0.5, 1]; go: ["tile", "right"] }
            Shape { part: [0, 0, 1, 0.5]; go: ["tile", "up"] }
            Shape { part: [0, 0.5, 1, 0.5]; go: ["tile", "down"] }
        }
        Row {
            x: 4
            spacing: 6
            Shape { part: [0, 0, 0.5, 0.5]; go: ["tile", "topleft"] }
            Shape { part: [0.5, 0, 0.5, 0.5]; go: ["tile", "topright"] }
            Shape { part: [0, 0.5, 0.5, 0.5]; go: ["tile", "bottomleft"] }
            Shape { part: [0.5, 0.5, 0.5, 0.5]; go: ["tile", "bottomright"] }
        }
        Rectangle { width: col.width; height: 1; color: Theme.separator }
        Item_ { text: qsTr("Fill"); go: ["fill"] }
        Item_ { text: qsTr("Center"); go: ["center"] }
        Rectangle { width: col.width; height: 1; color: Theme.separator }
        Item_ { text: qsTr("Enter Full Screen"); go: ["zoom"] }
    }
}
