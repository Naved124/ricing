pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs

// Frosted glass: a cool, half-clear fill (Hyprland blurs what's behind the
// layer), a lilac-ice hairline, a bright lip along the top edge where light
// catches it, a faint sky glow along the bottom, and a cool steel shadow.
Item {
    id: root

    property real radius: Theme.radiusPanel
    property color fill: Theme.glass
    property color hairline: Theme.hairline
    property bool shadow: true
    property real shadowBlur: 0.9
    default property alias content: inner.data

    Rectangle {
        id: plate
        anchors.fill: parent
        radius: root.radius
        color: root.fill
        border.color: root.hairline
        border.width: 1
        layer.enabled: root.shadow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: root.shadowBlur
            shadowVerticalOffset: 6
            shadowScale: 1.0
            autoPaddingEnabled: true
        }
    }

    // light on the pane: bright at the top edge, gone by 40% of the height
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.gleamAt(0.18) }
            GradientStop { position: 0.4; color: Qt.alpha(Theme.gleam, 0) }
        }
    }

    // a faint sky glow rising from the bottom edge, like light through ice
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        gradient: Gradient {
            GradientStop { position: 0.7; color: "transparent" }
            GradientStop { position: 1.0; color: Theme.glassGlow }
        }
    }

    // the 1 px top highlight: a near-white line just inside the rim, following
    // the rounded corners and fading to nothing by 40% of the height
    Item {
        anchors.fill: parent
        anchors.margins: 1
        Rectangle {
            width: parent.width
            height: parent.height
            radius: Math.max(0, root.radius - 1)
            color: "transparent"
            border.width: 1
            border.color: Theme.glassHighlight
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: lipMask
                maskThresholdMin: 0.0
                maskSpreadAtMin: 1.0
            }
        }
        Rectangle {
            id: lipMask
            visible: false
            layer.enabled: true
            width: parent.width
            height: parent.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "white" }
                GradientStop { position: 0.4; color: "transparent" }
            }
        }
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
