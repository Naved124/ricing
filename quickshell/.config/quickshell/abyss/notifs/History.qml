pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.common
import qs.services

// The notification history (in the island's drop-down), grouped by app,
// newest group first; each group shows its two newest and folds the rest.
// Quiet, it says so.
Column {
    id: root

    spacing: 10

    Item {
        width: parent.width
        height: 26
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: "NOTIFICATIONS"
            size: 11
            weight: Theme.weightStrong
            spacing: 0.18
            color: Theme.inkDim
        }
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifs.all.length > 0
            width: clearLabel.implicitWidth + 22
            height: 24
            radius: Theme.radiusChip
            color: clearMouse.containsMouse ? Theme.washHover : Theme.wash
            border.color: Theme.line
            Behavior on color { ColorAnimation { duration: 150 } }
            Label {
                id: clearLabel
                anchors.centerIn: parent
                text: "Clear all"
                size: 12
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

    // all quiet: a lone jelly drifting
    Column {
        width: parent.width
        visible: Notifs.all.length === 0
        topPadding: 14
        bottomPadding: 14
        spacing: 10
        Bell {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 18; height: 13
            color: Shell.dnd ? Theme.glow2 : Theme.glow
            tentacles: true
            glow: 0.6
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Shell.dnd ? "Do not disturb is on" : "All quiet down here"
            color: Theme.inkDim
            size: 12.5
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

            Item {
                width: parent.width
                height: 20
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 13
                        source: {
                            const name = group.modelData.icon || "";
                            return name.startsWith("/") || name.startsWith("file:") ? name : name ? Quickshell.iconPath(name, true) : "";
                        }
                        visible: status === Image.Ready
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: group.modelData.app.toUpperCase()
                        size: 11
                        weight: Theme.weightStrong
                        spacing: 0.14
                        color: Theme.inkDim
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: group.modelData.items.length > 1
                        text: group.modelData.items.length
                        size: 11
                        color: Theme.inkDim
                    }
                }
                Icon {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    name: "close"
                    size: 12
                    color: Theme.inkDim
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
                size: 12
                color: Theme.inkDim
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
