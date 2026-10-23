pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// A banner at the top right, as macOS shows one: the system's own (Liquid
// Glass falling back to Frosted) until the notification server takes them
// over. show(title, body) puts one up for `lifetime` ms; hover holds it.
PanelWindow {
    id: root

    property string title: ""
    property string body: ""
    property bool shown: false
    property int lifetime: 6000

    function show(t, b) {
        title = t;
        body = b;
        shown = true;
        hide.restart();
    }

    anchors { top: true; right: true }
    margins { top: 6; right: 6 }
    implicitWidth: 380
    implicitHeight: card.height + 40
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "goldengate:notifications"
    color: "transparent"
    visible: shown || card.opacity > 0
    mask: Region { item: card }

    Timer {
        id: hide
        interval: root.lifetime
        onTriggered: if (!hover.hovered) root.shown = false; else restart()
    }

    GlassPane {
        id: card
        x: 20
        y: 14
        width: 340
        height: Math.max(64, text.implicitHeight + 28)
        radius: Theme.radiusPanel - 6
        screen: root.screen
        opened: root.shown
        windowOrigin: Qt.point((root.screen ? root.screen.width : 1920) - root.margins.right - root.implicitWidth, root.margins.top)
        opacity: root.shown ? 1 : 0
        transform: Translate { x: root.shown ? 0 : 40; Behavior on x { SpringAnimation { spring: Theme.spring; damping: Theme.damping } } }
        Behavior on opacity { NumberAnimation { duration: Theme.panelIn } }

        HoverHandler { id: hover }
        TapHandler { onTapped: root.shown = false }

        // the app's icon: the system's, a gear on the accent
        Rectangle {
            id: icon
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 9
            color: Theme.graphite
            Text {
                anchors.centerIn: parent
                text: "⚙"
                color: Theme.onAccent
                font.pixelSize: 22
            }
        }
        Column {
            id: text
            anchors { left: icon.right; leftMargin: 11; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 2
            Text {
                width: parent.width
                text: root.title
                color: Theme.label
                font.family: Theme.fontUi
                font.pixelSize: Theme.textSize - 1
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.body
                color: Theme.label2
                font.family: Theme.fontUi
                font.pixelSize: Theme.textSize - 1
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }
        }
    }
}
