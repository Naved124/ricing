pragma ComponentBehavior: Bound

import QtQuick

// Abyss's chooser card: the generic card, its picture the reef at rest
// (preview.png), with a few plankton drifting up through the water over it
// and the edge lit teal while it's chosen. Cheap: a dozen dots, animated only
// while the chooser shows it.
Item {
    id: root

    property var rice: ({})
    property bool selected: false
    property bool active: false
    property url base
    property string mode: "dark"

    readonly property var c: rice?.meta?.colors ?? {}

    Loader {
        id: inner
        anchors.fill: parent
        source: root.base
    }
    Binding { target: inner.item; property: "rice"; value: root.rice; when: inner.status === Loader.Ready }
    Binding { target: inner.item; property: "selected"; value: root.selected; when: inner.status === Loader.Ready }
    Binding { target: inner.item; property: "active"; value: root.active; when: inner.status === Loader.Ready }

    // over the picture (GenericCard's 16 px margin, 150 tall)
    Item {
        x: 16
        y: 16
        width: root.width - 32
        height: 150
        clip: true

        Repeater {
            model: 12
            delegate: Item {
                id: speck
                required property int index
                readonly property real seed: (index * 0.6180339) % 1
                property real t: seed
                x: parent.width * ((seed * 7.3) % 1) + Math.sin(t * 8 + index) * 3
                y: parent.height * (1 - t)
                width: 2; height: 2
                opacity: Math.sin(Math.PI * t) * (root.selected ? 1 : 0.6)
                Rectangle {
                    anchors.centerIn: parent
                    width: 9; height: 9; radius: 4.5
                    color: root.c.glow ?? "transparent"
                    opacity: 0.25
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 1
                    color: root.c.ink ?? "transparent"
                }
                NumberAnimation on t {
                    running: root.visible
                    from: 0; to: 1
                    loops: Animation.Infinite
                    duration: 5000 + speck.seed * 5000
                }
            }
        }
    }

    // chosen: the edge glows like the reef's teal
    Rectangle {
        anchors.fill: parent
        radius: root.rice?.meta?.shape?.panel ?? 14
        color: "transparent"
        border.width: 2
        border.color: root.c.glow ?? "transparent"
        opacity: root.selected ? 0.8 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }
}
