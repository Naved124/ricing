import QtQuick

// Paper's chooser card: a sheet of stock. When selected it lifts and tilts
// a little, like a page picked up off the desk.
Item {
    id: root

    property var rice: ({})
    property bool selected: false
    property bool active: false
    property url base

    // a second sheet underneath, glimpsed when the top one tilts
    Rectangle {
        anchors.fill: parent
        radius: rice?.meta?.shape?.panel ?? 6
        color: "#ddd3bf"
        y: 3
        rotation: root.selected ? 1.5 : 0
        Behavior on rotation { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    }

    Loader {
        id: inner
        anchors.fill: parent
        source: root.base
        rotation: root.selected ? -1.5 : 0
        transform: Translate { y: root.selected ? -8 : 0; Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } } }
        Behavior on rotation { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    }
    Binding { target: inner.item; property: "rice"; value: root.rice; when: inner.status === Loader.Ready }
    Binding { target: inner.item; property: "selected"; value: root.selected; when: inner.status === Loader.Ready }
    Binding { target: inner.item; property: "active"; value: root.active; when: inner.status === Loader.Ready }
}
