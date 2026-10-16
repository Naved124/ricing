pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs

// Frosted glass: a translucent pearl fill (Hyprland blurs what's behind the
// layer), a lilac hairline, and a lilac-tinted shadow. Never pure white.
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

    // a faint top sheen, like light on a shell's inner surface
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: root.radius - 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.35) }
            GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.0) }
        }
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
