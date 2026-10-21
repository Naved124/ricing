pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.common

// The system tray: the apps' icons, always out, in a row.
Item {
    id: root

    required property var bar
    readonly property var items: SystemTray.items.values

    visible: items.length > 0
    implicitHeight: 26
    implicitWidth: icons.implicitWidth + 16

    Row {
        id: icons
        anchors.centerIn: parent
        spacing: 8

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
