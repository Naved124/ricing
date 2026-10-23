pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Notification banners, top right as on the Mac: the queue's first, for
// Notifs.lifetime (hover holds it), its actions on hover, a click opens it,
// a swipe to the right dismisses it. Everything stays in Notification Center.
PanelWindow {
    id: root

    readonly property var n: Notifs.current
    anchors { top: true; right: true }
    margins { top: 6; right: 6 }
    implicitWidth: 380
    implicitHeight: 150
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "goldengate:notifications"
    color: "transparent"
    visible: n !== null && !Shell.isOpen("notifications")
    mask: Region { item: card }

    Timer {
        id: life
        interval: Notifs.lifetime
        running: root.n !== null && !hover.hovered
        onTriggered: Notifs.done(root.n)
    }
    onNChanged: { card.x = 20; life.restart(); }

    GlassPane {
        id: card
        x: 20
        y: 14
        width: 340
        height: Math.max(66, col.implicitHeight + 26)
        radius: Theme.radiusPanel - 6
        screen: root.screen
        windowOrigin: Qt.point((root.screen ? root.screen.width : 1920) - 6 - root.implicitWidth, 6)
        opened: root.visible
        Behavior on x { SpringAnimation { spring: Theme.spring; damping: Theme.damping } }

        HoverHandler { id: hover }
        DragHandler {
            xAxis.minimum: 20
            yAxis.enabled: false
            onActiveChanged: if (!active) { if (card.x > 120) Notifs.dismiss(root.n); else card.x = 20; }
        }
        TapHandler {
            onTapped: {
                const a = root.n ? root.n.actions.find(x => x.identifier === "default") : null;
                if (a) a.invoke();
                Notifs.done(root.n);
            }
        }

        AppIcon {
            id: icon
            x: 14; y: 14
            implicitSize: 36
            app: root.n ? (root.n.desktopEntry || root.n.appIcon || root.n.appName || "") : ""
        }
        Column {
            id: col
            anchors { left: icon.right; leftMargin: 11; right: parent.right; rightMargin: 14; top: parent.top; topMargin: 13 }
            spacing: 2
            Label { width: parent.width; strong: true; font.pixelSize: Theme.textSize - 1; text: root.n ? root.n.summary : "" }
            Label {
                width: parent.width; secondary: true; font.pixelSize: Theme.textSize - 1
                wrapMode: Text.Wrap; maximumLineCount: 4
                text: root.n ? root.n.body : ""
            }
            Row {
                spacing: 6
                visible: hover.hovered && root.n && root.n.actions.length > 0
                Repeater {
                    model: root.n ? root.n.actions.filter(a => a.identifier !== "default") : []
                    delegate: Rectangle {
                        required property var modelData
                        width: t.implicitWidth + 20; height: 24; radius: 12
                        color: Theme.fill
                        Label { id: t; anchors.centerIn: parent; text: parent.modelData.text; font.pixelSize: Theme.smallSize }
                        MouseArea { anchors.fill: parent; onClicked: { parent.modelData.invoke(); Notifs.done(root.n); } }
                    }
                }
            }
        }
    }
}
