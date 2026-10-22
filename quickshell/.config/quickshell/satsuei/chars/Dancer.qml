import QtQuick
import QtQuick.Shapes
import qs.common
import qs.services

// The dancer on the media card: the character cast as the dancer, standing on
// the card's top right edge on a soft contact shadow. It dances while
// something plays (its speed and size of moves from the tempo and the
// loudness) and idles otherwise; it only moves while the control centre is
// open.
Item {
    id: root

    property bool running: true
    readonly property var cast: Characters.dancer

    // the contact shadow: a soft ellipse in the plate's ink under the feet
    Shape {
        width: 70
        height: 14
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -5
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: 35; centerY: 7; centerRadius: 35
                focalX: 35; focalY: 7
                GradientStop { position: 0; color: Theme.at(Theme.ink, 0.25) }
                GradientStop { position: 1; color: Theme.at(Theme.ink, 0) }
            }
            PathSvg { path: "M 0 7 a 35 7 0 1 0 70 0 a 35 7 0 1 0 -70 0 Z" }
        }
    }

    Loader {
        id: actor
        anchors.fill: parent
        source: Qt.resolvedUrl(root.cast.file)
        onLoaded: {
            item.mode = Qt.binding(() => Media.playing ? "dance" : "idle");
            item.energy = Qt.binding(() => 0.45 + Math.min(1, Beat.level) * 0.75);
            item.running = Qt.binding(() => root.running);
        }
    }
}
