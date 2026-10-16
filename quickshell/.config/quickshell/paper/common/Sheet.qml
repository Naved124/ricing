import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "paper.js" as P

// A sheet of paper: the surface under every Paper panel.
//   · card stock with the paper texture, and a torn (deckle) edge: the
//     outline wavers 0.6–1.2 px, seeded, so no two sheets match
//   · two warm-brown shadows, a tight contact one and a soft one; `lifted`
//     makes them larger, as if the sheet were picked up
//   · `ruled` draws blue rule lines, `margin` the red margin line
//   · `tilt` turns the paper (±1.5° at most). Only the paper: what's put
//     inside stays level unless `tiltContent` is set, so text fields are
//     never drawn at an angle.
Item {
    id: root

    property color fill: Theme.card
    property bool texture: true
    // the stock is paper-coloured: strong on white sheets, faint on coloured ones
    property real textureOpacity: Qt.colorEqual(fill, Theme.card) || Qt.colorEqual(fill, Theme.paper) ? 0.55 : 0.18
    property int seed: 1

    property bool ruled: false
    property real ruleGap: 26
    property real ruleTop: 30          // y of the first rule line
    property bool margin: false
    property real marginX: 52

    property real tilt: 0
    property bool tiltContent: false
    property bool lifted: false
    property bool shadow: true

    default property alias content: holder.data
    readonly property real angle: Math.max(-1.5, Math.min(1.5, tilt))

    // the paper, turned as a whole
    Item {
        id: paper
        anchors.fill: parent
        rotation: root.angle
        antialiasing: true

        // the silhouette: drawn once into a texture the shadows and the
        // fill share, then left alone (nothing here moves)
        Shape {
            id: outline
            anchors.fill: parent
            visible: false
            layer.enabled: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: root.fill
                PathSvg { path: P.deckle(outline.width, outline.height, root.seed) }
            }
        }

        // soft shadow, further out
        MultiEffect {
            anchors.fill: outline
            source: outline
            visible: root.shadow
            autoPaddingEnabled: true
            shadowEnabled: true
            shadowColor: Theme.umber
            shadowOpacity: root.lifted ? Theme.shadowLiftOpacity : Theme.shadowSoftOpacity
            shadowBlur: root.lifted ? 1.0 : 0.7
            shadowHorizontalOffset: root.lifted ? 10 : 3
            shadowVerticalOffset: root.lifted ? 26 : 8
            Behavior on shadowHorizontalOffset { NumberAnimation { duration: 300 } }
            Behavior on shadowVerticalOffset { NumberAnimation { duration: 300 } }
        }
        // tight contact shadow, drawn with the paper itself on top
        MultiEffect {
            anchors.fill: outline
            source: outline
            autoPaddingEnabled: true
            shadowEnabled: root.shadow
            shadowColor: Theme.umber
            shadowOpacity: Theme.shadowTightOpacity
            shadowBlur: 0.12
            shadowHorizontalOffset: root.lifted ? 2 : 1
            shadowVerticalOffset: root.lifted ? 4 : 2
        }

        // fibres: the tiled stock, kept just inside the torn edge
        Image {
            anchors.fill: parent
            anchors.margins: 1.5
            visible: root.texture
            source: root.texture ? "file://" + Theme.paperTex : ""
            fillMode: Image.Tile
            opacity: root.textureOpacity
            asynchronous: true
            cache: true
        }

        // rule lines
        Repeater {
            model: root.ruled ? Math.max(0, Math.floor((root.height - root.ruleTop - 4) / root.ruleGap) + 1) : 0
            delegate: Rectangle {
                required property int index
                x: 2
                width: root.width - 4
                y: root.ruleTop + index * root.ruleGap
                height: 1
                color: Theme.ruleLine
                opacity: 0.85
            }
        }
        // the margin line
        Rectangle {
            visible: root.margin
            x: root.marginX
            y: 2
            width: 1.5
            height: root.height - 4
            color: Theme.marginLine
        }
    }

    // content: level, or turned with the paper
    Item {
        id: holder
        anchors.fill: parent
        rotation: root.tiltContent ? root.angle : 0
        antialiasing: true
    }
}
