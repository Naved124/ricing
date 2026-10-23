import QtQuick
import QtQuick.Effects
import qs.common

// The glass every Golden Gate panel is: the tint (Theme.glass, by the
// clarity), a hairline edge, the rim the light catches and a sheen across
// the top. Behind it, hyprglass bends and lights the picture under Liquid,
// or Hyprland blurs it under Frosted; Solid is the window colour. The shadow
// is soft and large, and faint under a plugin (its mask would take it).
// With the shell's own Liquid (no plugin) a LiquidLayer bends and blurs a
// copy of what's behind it, under the tint.
Item {
    id: root

    property real radius: Theme.radiusPanel
    // menus, the Spotlight field: a stronger pane
    property bool thick: false
    property bool shadow: true
    // for the shell's own Liquid (Theme.shaderGlass): the screen, and where
    // the pane's window sits on it
    property var screen: null
    property point windowOrigin: Qt.point(0, 0)
    // false while the pane is hidden: Accurate takes its still as it opens
    property bool opened: true
    default property alias content: inner.data
    // the shell's own Liquid taking its still: hidden from it for that moment
    readonly property bool capturing: liquid.item ? liquid.item.capturing : false

    RectangularShadow {
        anchors.fill: parent
        visible: root.shadow && !root.capturing
        radius: root.radius
        offset.y: Theme.liquidPlugin ? 2 : 10
        blur: Theme.liquidPlugin ? 12 : 36
        spread: 0
        color: Theme.glassShadow
    }
    // the bend and blur, under the tint
    Loader {
        id: liquid
        anchors.fill: parent
        active: Theme.shaderGlass
        sourceComponent: LiquidLayer {
            pane: root
            screen: root.screen
            windowOrigin: root.windowOrigin
            radius: root.radius
            opened: root.opened
        }
    }

    Item {
        id: face
        anchors.fill: parent
        opacity: root.capturing ? 0 : 1

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
}
