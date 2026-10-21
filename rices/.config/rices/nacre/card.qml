import QtQuick
import QtQuick.Shapes

// Nacre's chooser card: the generic card behind pearl glass. When selected
// the glass shimmers, an iridescent sheen drifting across it. At night it is
// a dark pearl in a ring of the dark orient.
Item {
    id: root

    property var rice: ({})
    property bool selected: false
    property bool active: false
    property url base
    property string mode: "light"

    // the rice's gradient, from its rendered meta.json
    readonly property var stops: rice?.meta?.gradient ?? []

    Loader {
        id: inner
        anchors.fill: parent
        source: root.base
    }
    Binding { target: inner.item; property: "rice"; value: root.rice; when: inner.status === Loader.Ready }
    Binding { target: inner.item; property: "selected"; value: root.selected; when: inner.status === Loader.Ready }
    Binding { target: inner.item; property: "active"; value: root.active; when: inner.status === Loader.Ready }

    // at night a dark pearl: its border is the dark orient, a conic ring
    Shape {
        id: ring
        readonly property real r: root.rice?.meta?.shape?.panel ?? 12
        // a rounded rectangle inset by i, as SVG
        function outline(i) {
            const w = root.width - 2 * i, h = root.height - 2 * i, q = Math.max(0, r - i);
            return `M ${i + q} ${i} H ${i + w - q} A ${q} ${q} 0 0 1 ${i + w} ${i + q} V ${i + h - q} `
                 + `A ${q} ${q} 0 0 1 ${i + w - q} ${i + h} H ${i + q} A ${q} ${q} 0 0 1 ${i} ${i + h - q} `
                 + `V ${i + q} A ${q} ${q} 0 0 1 ${i + q} ${i} Z`;
        }
        anchors.fill: parent
        visible: root.mode === "dark"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillRule: ShapePath.OddEvenFill
            fillGradient: ConicalGradient {
                centerX: root.width / 2
                centerY: root.height / 2
                angle: 45
                GradientStop { position: 0.0; color: root.stops[0] ?? "transparent" }
                GradientStop { position: 0.2; color: root.stops[1] ?? "transparent" }
                GradientStop { position: 0.4; color: root.stops[2] ?? "transparent" }
                GradientStop { position: 0.6; color: root.stops[3] ?? "transparent" }
                GradientStop { position: 0.8; color: root.stops[4] ?? "transparent" }
                GradientStop { position: 1.0; color: root.stops[0] ?? "transparent" }
            }
            PathSvg { path: ring.outline(0) + " " + ring.outline(2) }
        }
    }

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
                GradientStop { position: 0.3; color: root.stops[0] ?? "transparent" }
                GradientStop { position: 0.45; color: root.stops[1] ?? "transparent" }
                GradientStop { position: 0.6; color: root.stops[2] ?? "transparent" }
                GradientStop { position: 0.75; color: root.stops[4] ?? "transparent" }
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
