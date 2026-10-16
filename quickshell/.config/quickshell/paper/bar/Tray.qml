pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.common

// The system tray, its icons drained to 15% of their colour so they sit on
// the paper like pencil sketches. Left-click activates, right-click opens
// the menu, middle-click is the secondary action.
Row {
    id: root

    required property var bar

    spacing: 10
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items.values

        delegate: Item {
            id: trayItem

            required property var modelData
            width: 18
            height: 18

            IconImage {
                id: icon
                anchors.fill: parent
                implicitSize: 18
                source: trayItem.modelData.icon
                visible: false
            }
            MultiEffect {
                anchors.fill: icon
                source: icon
                saturation: -0.85
                opacity: trayItem.modelData.status === Status.NeedsAttention ? 1 : 0.85
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -3
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    const item = trayItem.modelData;
                    if (mouse.button === Qt.MiddleButton) {
                        item.secondaryActivate();
                    } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                        if (item.hasMenu) {
                            const p = trayItem.mapToItem(null, 0, trayItem.height + 12);
                            item.display(root.bar, p.x, p.y);
                        }
                    } else {
                        item.activate();
                    }
                }
                onWheel: wheel => trayItem.modelData.scroll(wheel.angleDelta.y, false)
            }
        }
    }
}
