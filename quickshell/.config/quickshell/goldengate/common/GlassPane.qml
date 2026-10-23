import QtQuick
import QtQuick.Effects
import qs.common

// The glass every Golden Gate panel is: the tint (Theme.glass, by the
// clarity), a hairline edge, the rim the light catches and a sheen across
// the top. Behind it, hyprglass bends and lights the picture under Liquid,
// or Hyprland blurs it under Frosted; Solid is the window colour. The shadow
// is soft and large, and faint under a plugin (its mask would take it).
Item {
    id: root

    property real radius: Theme.radiusPanel
    // menus, the Spotlight field: a stronger pane
    property bool thick: false
    property bool shadow: true
    default property alias content: inner.data

    RectangularShadow {
        anchors.fill: plate
        visible: root.shadow
        radius: root.radius
        offset.y: Theme.liquidPlugin ? 2 : 10
        blur: Theme.liquidPlugin ? 12 : 36
        spread: 0
        color: Theme.glassShadow
    }
    Rectangle {
        id: plate
        anchors.fill: parent
        radius: root.radius
        color: root.thick ? Theme.glassThick : Theme.glass
        border.width: 1
        border.color: Theme.glassEdge
    }
    // the light along the rim, brightest on top
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        color: "transparent"
        border.width: 1
        border.color: Theme.glassRim
        opacity: 0.6
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        visible: !Theme.solid
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.glassRim, Theme.glassRim.a * 0.5) }
            GradientStop { position: 0.35; color: "transparent" }
        }
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
