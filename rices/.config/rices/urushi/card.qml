import QtQuick

// Urushi's chooser card: a lacquer panel with a gold rim along the top.
// When selected the rim glints, a point of light running along it.
Item {
    id: root

    property var rice: ({})
    property bool selected: false
    property bool active: false
    property url base

    readonly property color gold: rice?.meta?.colors?.gold ?? "#c9a24a"

    Loader {
        id: inner
        anchors.fill: parent
        source: root.base
    }
    Binding { target: inner.item; property: "rice"; value: root.rice; when: inner.status === Loader.Ready }
    Binding { target: inner.item; property: "selected"; value: root.selected; when: inner.status === Loader.Ready }
    Binding { target: inner.item; property: "active"; value: root.active; when: inner.status === Loader.Ready }

    // the gold rim
    Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 2 * (rice?.meta?.shape?.panel ?? 8)
        height: 2
        color: root.gold
        opacity: root.selected ? 1 : 0.6

        // the glint
        Rectangle {
            width: 60
            height: 2
            visible: root.selected
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: "#f1cf7a" }
                GradientStop { position: 1; color: "transparent" }
            }
            NumberAnimation on x {
                running: root.selected
                loops: Animation.Infinite
                from: -60
                to: root.width
                duration: 1800
                easing.type: Easing.InOutCubic
            }
        }
    }
}
