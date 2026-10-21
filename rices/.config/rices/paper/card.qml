pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// Paper's chooser card: a ruled sheet taped to the desk, tilted, its name
// set in Newsreader with "desk" pencilled beside it in red, and the palette
// as dabs of paint. Selected, it lifts off the desk: it straightens a
// little, rises, and its shadow spreads.
Item {
    id: root

    property var rice: ({})
    property bool selected: false
    property bool active: false

    readonly property var m: rice?.meta ?? {}
    readonly property var c: m.colors ?? {}
    readonly property var f: m.fonts ?? {}
    readonly property color umber: c.umber ?? "transparent"
    readonly property int ease: 420

    // the sheet and its two shadows tilt and lift together
    Item {
        id: sheet
        anchors.fill: parent
        anchors.margins: 14
        rotation: root.selected ? -0.6 : -1.5
        transform: Translate { y: root.selected ? -6 : 0; Behavior on y { NumberAnimation { duration: root.ease; easing.type: Easing.OutBack } } }
        Behavior on rotation { NumberAnimation { duration: root.ease; easing.type: Easing.OutBack } }

        // soft shadow, then the tight one at the edge
        Rectangle {
            x: 3; y: root.selected ? 12 : 8
            width: parent.width; height: parent.height
            radius: 4
            color: root.umber
            opacity: root.selected ? 0.14 : 0.10
            Behavior on y { NumberAnimation { duration: root.ease } }
            Behavior on opacity { NumberAnimation { duration: root.ease } }
        }
        Rectangle {
            x: 1; y: 2
            width: parent.width; height: parent.height
            radius: 3
            color: root.umber
            opacity: 0.18
        }

        Rectangle {
            id: page
            anchors.fill: parent
            radius: 3
            color: root.c.paper ?? "transparent"
            clip: true

            // ruled every 24 px below the heading, and the red margin
            Repeater {
                model: Math.max(0, Math.floor((page.height - 96) / 24))
                delegate: Rectangle {
                    required property int index
                    y: 96 + index * 24
                    width: page.width
                    height: 1
                    color: root.c.rule ?? "transparent"
                    opacity: 0.55
                }
            }
            Rectangle {
                x: 34
                width: 1.5
                height: page.height
                color: root.c.margin ?? "transparent"
                opacity: 0.8
            }

            // the name, and "desk" written beside it
            Text {
                id: title
                x: 46; y: 26
                text: root.m.title ?? "Paper"
                color: root.c.ink ?? "transparent"
                font.family: root.f.serif ?? "Newsreader"
                font.weight: root.f.display_weight ?? 600
                font.pixelSize: 38
            }
            Text {
                anchors.left: title.right
                anchors.leftMargin: 8
                anchors.baseline: title.baseline
                anchors.baselineOffset: -2
                text: "desk"
                rotation: -5
                color: root.c.red ?? "transparent"
                font.family: root.f.hand ?? "Kalam"
                font.weight: 700
                font.pixelSize: 30
            }

            // the tagline, typed along the first two rules
            Text {
                id: tagline
                x: 46
                y: 96 + 24 - 17
                width: page.width - 58
                text: root.m.tagline ?? ""
                color: root.c.pencil ?? "transparent"
                font.family: root.f.type ?? "Courier Prime"
                font.pixelSize: 12
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                lineHeightMode: Text.FixedHeight
                lineHeight: 24
            }

            // the palette, as dabs of paint along the rules
            Flow {
                x: 46
                y: 96 + 24 * (tagline.lineCount + 1) - 2
                width: page.width - 60
                spacing: 10
                Repeater {
                    model: ["ink", "red", "sticky", "pink", "mint", "rule", "kraft", "fern"]
                    delegate: Shape {
                        id: dab
                        required property string modelData
                        required property int index
                        readonly property real s: 26
                        // a lopsided blob: each point pushed in or out by its own amount
                        readonly property var w: [0.92, 1.05, 0.88, 1.08, 0.95, 1.02, 0.9, 1.06]
                            .map((v, i) => v + 0.05 * Math.sin((index + 1) * (i + 2) * 1.7))
                        width: s; height: s
                        rotation: (index * 37) % 30 - 15
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeWidth: -1
                            fillColor: root.c[dab.modelData] ?? "transparent"
                            PathPolyline {
                                path: {
                                    const pts = [];
                                    for (let i = 0; i <= 24; i++) {
                                        const a = i / 24 * Math.PI * 2;
                                        const k = dab.w[Math.floor(i / 3) % 8];
                                        pts.push(Qt.point(dab.s / 2 + Math.cos(a) * dab.s / 2 * k,
                                                          dab.s / 2 + Math.sin(a) * dab.s / 2.3 * k));
                                    }
                                    return pts;
                                }
                            }
                        }
                        // the wetter edge where the paint pooled
                        Rectangle {
                            x: dab.s * 0.18; y: dab.s * 0.22
                            width: dab.s * 0.3; height: dab.s * 0.18
                            radius: height / 2
                            color: root.c.chalk ?? "transparent"
                            opacity: 0.22
                        }
                    }
                }
            }

            // bottom right: on the desk now, or how it arrives
            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                text: root.active ? "✓ on the desk" : "↵ peel"
                rotation: root.active ? -3 : 0
                color: root.active ? (root.c.red ?? "transparent") : (root.c.graphite ?? "transparent")
                font.family: root.active ? (root.f.hand ?? "Kalam") : (root.f.type ?? "Courier Prime")
                font.weight: root.active ? 700 : 400
                font.pixelSize: root.active ? 18 : 13
            }
        }

        // washi tape over the top corners
        Repeater {
            model: [{ x: -14, r: -32 }, { x: sheet.width - 52, r: 30 }]
            delegate: Rectangle {
                required property var modelData
                x: modelData.x
                y: -6
                width: 66
                height: 20
                rotation: modelData.r
                opacity: 0.82
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: root.c.pink ?? "transparent" }
                    GradientStop { position: 0.5; color: Qt.lighter(root.c.pink ?? "transparent", 1.08) }
                    GradientStop { position: 1; color: root.c.pink ?? "transparent" }
                }
            }
        }
    }
}
