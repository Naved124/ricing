import QtQuick

// The card for a rice that ships no card.qml: a miniature desktop drawn in
// its palette, its gradient as swatches, and its name in its own fonts.
// A rice's own card.qml gets the same three properties.
Item {
    id: root

    property var rice: ({})          // { name, meta, preview }
    property bool selected: false
    property bool active: false

    readonly property var m: rice?.meta ?? {}
    readonly property var r: m.roles ?? {}
    readonly property var grad: m.gradient ?? []
    readonly property int radius: m.shape?.panel ?? 12

    Rectangle {
        id: face
        anchors.fill: parent
        radius: root.radius
        color: root.r.surface ?? "#222"
        border.color: root.selected ? (root.r.accent ?? "#888") : (root.r.border ?? "#444")
        border.width: root.selected ? 2 : 1
        Behavior on border.color { ColorAnimation { duration: 250 } }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // the preview: a screenshot if the rice has one, otherwise a mock desktop
        Rectangle {
            width: parent.width
            height: 150
            radius: Math.max(4, root.radius - 6)
            color: root.r.bg ?? "#111"
            clip: true

            Image {
                anchors.fill: parent
                visible: !!root.rice?.preview
                source: root.rice?.preview ? "file://" + root.rice.preview : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Item {
                anchors.fill: parent
                anchors.margins: 8
                visible: !root.rice?.preview

                Rectangle {
                    id: bar
                    width: parent.width
                    height: 10
                    radius: 5
                    color: root.r.surface ?? "#333"
                }
                Rectangle {
                    id: focused
                    anchors.top: bar.bottom
                    anchors.topMargin: 8
                    anchors.bottom: parent.bottom
                    width: parent.width * 0.55 - 4
                    radius: Math.max(2, (root.m.shape?.window ?? 8) / 3)
                    color: root.r.term_bg ?? root.r.bg ?? "#111"
                    border.width: 2
                    border.color: root.grad[0] ?? root.r.accent ?? "#888"
                    Column {
                        x: 8; y: 10; spacing: 5
                        Repeater {
                            model: 5
                            delegate: Rectangle {
                                required property int index
                                width: [60, 42, 70, 30, 52][index]
                                height: 4
                                radius: 2
                                color: root.grad[index % Math.max(1, root.grad.length)] ?? root.r.fg ?? "#ccc"
                                opacity: 0.85
                            }
                        }
                    }
                }
                Column {
                    anchors.top: bar.bottom
                    anchors.topMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.left: focused.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    spacing: 8
                    Repeater {
                        model: 2
                        delegate: Rectangle {
                            width: parent.width
                            height: (parent.height - 8) / 2
                            radius: focused.radius
                            color: root.r.surface ?? "#222"
                            border.width: 1
                            border.color: root.r.border ?? "#444"
                        }
                    }
                }
            }
        }

        Row {
            spacing: 6
            Repeater {
                model: root.grad
                delegate: Rectangle {
                    required property string modelData
                    width: 18
                    height: 18
                    radius: 9
                    color: modelData
                    border.color: root.r.border ?? "#444"
                }
            }
        }

        Column {
            width: parent.width
            spacing: 2
            Text {
                text: root.m.title ?? root.rice?.name ?? ""
                color: root.r.fg ?? "#eee"
                font.family: root.m.fonts?.display ?? "sans-serif"
                font.pixelSize: 26
            }
            Text {
                width: parent.width
                text: root.m.tagline ?? ""
                color: root.r.muted ?? "#999"
                font.family: root.m.fonts?.ui ?? "sans-serif"
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        text: root.active ? "● active" : `↵ ${root.m.transition ?? "fade"}`
        color: root.active ? (root.r.fg ?? "#eee") : (root.r.muted ?? "#999")
        font.family: root.m.fonts?.ui ?? "sans-serif"
        font.pixelSize: 12
    }
}
