import QtQuick

// Nacre's chooser card: the generic card behind pearl glass. When selected
// the glass shimmers, an iridescent sheen drifting across it.
Item {
    id: root

    property var rice: ({})
    property bool selected: false
    property bool active: false
    property url base

    Loader {
        id: inner
        anchors.fill: parent
        source: root.base
    }
    Binding { target: inner.item; property: "rice"; value: root.rice; when: inner.status === Loader.Ready }
    Binding { target: inner.item; property: "selected"; value: root.selected; when: inner.status === Loader.Ready }
    Binding { target: inner.item; property: "active"; value: root.active; when: inner.status === Loader.Ready }

    // the shimmer: a wide soft band of the gradient sliding across
    Item {
        anchors.fill: parent
        clip: true
        opacity: root.selected ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 400 } }

        Rectangle {
            id: sheen
            width: parent.width * 1.6
            height: parent.height * 2
            y: -parent.height / 2
            rotation: 20
            opacity: 0.22
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.3; color: "#f2c3d6" }
                GradientStop { position: 0.45; color: "#c3dff3" }
                GradientStop { position: 0.6; color: "#cdeedb" }
                GradientStop { position: 0.75; color: "#dcc6f2" }
                GradientStop { position: 1.0; color: "transparent" }
            }
            NumberAnimation on x {
                running: root.selected
                loops: Animation.Infinite
                from: -root.width * 1.6
                to: root.width
                duration: 2400
                easing.type: Easing.InOutSine
            }
        }
    }
}
