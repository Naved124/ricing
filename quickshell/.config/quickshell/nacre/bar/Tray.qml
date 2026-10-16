pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.common

// The system tray, collapsed into a single pearl. Click to open it.
Item {
    id: root

    required property var bar
    property bool open: false
    readonly property var items: SystemTray.items.values

    visible: items.length > 0
    implicitHeight: 26
    implicitWidth: pearl.width + 14 + (open ? icons.implicitWidth + 8 : 0)
    clip: true

    Behavior on implicitWidth { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.open ? Theme.glassSoft : "transparent"
        border.color: root.open ? Theme.hairline : "transparent"
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    Pearl {
        id: pearl
        x: 7
        anchors.verticalCenter: parent.verticalCenter
        width: 13; height: 13
        gloss: 0.9
        iri: root.items.some(i => i.status === Status.NeedsAttention) ? 1 : 0.3

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    Row {
        id: icons
        x: pearl.x + pearl.width + 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }

        Repeater {
            model: root.items

            delegate: IconImage {
                id: trayIcon
                required property var modelData
                implicitSize: 16
                source: modelData.icon
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const item = trayIcon.modelData;
                        if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                            if (item.hasMenu) {
                                const p = trayIcon.mapToItem(null, 0, trayIcon.height + 14);
                                item.display(root.bar, p.x, p.y);
                            }
                        } else {
                            item.activate();
                        }
                    }
                    onWheel: wheel => trayIcon.modelData.scroll(wheel.angleDelta.y, false)
                }
            }
        }
    }
}
