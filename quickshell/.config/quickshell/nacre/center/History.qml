pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.common
import qs.notifs
import qs.services

// Notification history, grouped by app (newest group first). Each group
// shows its two newest and folds the rest behind "N more". Empty, it says
// so quietly.
Column {
    id: root

    spacing: 10

    Item {
        width: parent.width
        height: 28

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            font.family: Theme.fontDisplay
            size: 22
            weight: Font.Normal
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifs.all.length > 0
            width: clearLabel.implicitWidth + 24
            height: 26
            radius: 13
            color: clearMouse.containsMouse ? Theme.pearl : Theme.glassSoft
            border.color: Theme.hairline
            Behavior on color { ColorAnimation { duration: 150 } }
            Label {
                id: clearLabel
                anchors.centerIn: parent
                text: "Clear all"
                size: Theme.uiSize
            }
            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.clearAll()
            }
        }
    }

    // all quiet
    Column {
        width: parent.width
        visible: Notifs.all.length === 0
        topPadding: 18
        bottomPadding: 18
        spacing: 8
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: Shell.dnd ? "moon" : "bell-off"
            size: 22
            color: Theme.lilac
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Shell.dnd ? "Do not disturb is on" : "All quiet"
            color: Theme.inkSoft
            size: Theme.uiSize + 1
        }
    }

    Repeater {
        model: Notifs.groups

        delegate: Column {
            id: group

            required property var modelData
            property bool expanded: false
            readonly property int folded: Math.max(0, modelData.items.length - 2)

            width: root.width
            spacing: 6

            // the app, its icon and a count
            Item {
                width: parent.width
                height: 22
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 14
                        source: {
                            const name = group.modelData.icon || "";
                            return name.startsWith("/") || name.startsWith("file:") ? name : name ? Quickshell.iconPath(name, true) : "";
                        }
                        visible: status === Image.Ready
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: group.modelData.app
                        font.capitalization: Font.SmallCaps
                        font.letterSpacing: 0.8
                        size: Theme.uiSize + 1
                        weight: Font.DemiBold
                        color: Theme.inkSoft
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: group.modelData.items.length > 1
                        text: group.modelData.items.length
                        size: Theme.uiSize - 1
                        color: Theme.inkSoft
                    }
                }
                Icon {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    name: "close"
                    size: 13
                    color: Theme.inkSoft
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: group.modelData.items.slice().forEach(n => Notifs.dismiss(n))
                    }
                }
            }

            Repeater {
                model: group.expanded ? group.modelData.items : group.modelData.items.slice(0, 2)
                delegate: NotificationCard {
                    required property var modelData
                    notification: modelData
                    popup: false
                    width: group.width
                    onDismissed: Notifs.dismiss(modelData)
                }
            }

            Label {
                visible: group.folded > 0
                text: group.expanded ? "Show less" : `${group.folded} more`
                size: Theme.uiSize
                color: Theme.inkSoft
                leftPadding: 4
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: group.expanded = !group.expanded
                }
            }
        }
    }
}
