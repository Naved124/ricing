pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.common
import qs.services

// One notification: frosted glass with a lilac hairline, the app icon in a
// pearl, title, a two-line body, an image when there is one, pill actions
// and an inline reply. As a popup, a thin gradient line drains along the
// bottom; critical ones wear a moving iridescent border instead.
Item {
    id: root

    required property var notification
    property bool popup: true          // false inside the control centre
    property bool paused: hover.hovered || reply.activeFocus

    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property int lifetime: popup ? Notifs.lifetime(notification) : 0

    signal expired()
    signal dismissed()

    implicitWidth: 360
    implicitHeight: body.implicitHeight + 28

    HoverHandler { id: hover }

    Glass {
        id: card
        anchors.fill: parent
        radius: Theme.radiusPopup
        shadow: root.popup
        fill: root.popup ? Theme.glassStrong : Theme.glassSoft

        // critical: the border itself is iridescent and moving
        Iridescent {
            anchors.fill: parent
            visible: root.critical
            radius: Theme.radiusPopup
            ring: 2
            period: 4000
            sheen: 0
        }

        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // the app icon sits in a pearl
                Item {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignTop

                    Pearl {
                        anchors.fill: parent
                        gloss: 0.5
                        iri: root.critical ? 0.8 : 0.15
                    }
                    IconImage {
                        id: appIcon
                        anchors.centerIn: parent
                        implicitSize: 20
                        source: {
                            const n = root.notification;
                            const name = n?.appIcon || n?.desktopEntry || "";
                            return name.startsWith("/") || name.startsWith("file:") ? name
                                : name ? Quickshell.iconPath(name, true) : "";
                        }
                        visible: status === Image.Ready
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: !appIcon.visible
                        name: "bell"
                        size: 18
                        color: Theme.inkSoft
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            text: root.notification?.summary || root.notification?.appName || ""
                            weight: Theme.weightStrong
                            size: Theme.uiSize + 2
                            elide: Text.ElideRight
                        }
                        Label {
                            text: root.notification?.appName ?? ""
                            color: Theme.inkSoft
                            size: Theme.uiSize - 1
                            visible: text.length > 0 && text !== root.notification?.summary
                        }
                        Item {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            Icon {
                                anchors.centerIn: parent
                                name: "close"
                                size: 14
                                color: Theme.inkSoft
                                opacity: hover.hovered ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dismissed()
                            }
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.notification?.body ?? ""
                        visible: text.length > 0
                        color: Theme.ink
                        size: Theme.uiSize + 1
                        weight: Theme.weight
                        wrapMode: Text.Wrap
                        maximumLineCount: root.popup ? 2 : 4
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                }

                ClippingRectangle {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    Layout.alignment: Qt.AlignTop
                    visible: (root.notification?.image ?? "") !== ""
                    radius: Theme.radiusChip
                    color: Theme.shell

                    Image {
                        anchors.fill: parent
                        source: root.notification?.image ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Rectangle {           // 92% brightness at night
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.imageShade
                    }
                }
            }

            // pill actions
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: 48
                spacing: 6
                visible: (root.notification?.actions?.length ?? 0) > 0

                Repeater {
                    model: root.notification?.actions ?? []

                    delegate: Item {
                        id: action
                        required property var modelData
                        width: actionLabel.implicitWidth + 24
                        height: 26

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: actionMouse.containsMouse ? Theme.pearl : Theme.glassSoft
                            border.color: Theme.hairline
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Label {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: action.modelData.text
                            size: Theme.uiSize
                        }
                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: action.modelData.invoke()
                        }
                    }
                }
            }

            // inline reply
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 48
                Layout.preferredHeight: 32
                visible: !!root.notification?.hasInlineReply
                radius: height / 2
                color: Theme.glassSoft
                border.color: reply.activeFocus ? Theme.orchid : Theme.hairline

                TextField {
                    id: reply
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 34
                    placeholderText: root.notification?.inlineReplyPlaceholder || "Reply…"
                    placeholderTextColor: Theme.inkSoft
                    color: Theme.ink
                    font.family: Theme.fontUi
                    font.weight: Theme.weight
                    font.pixelSize: Theme.uiSize + 1
                    background: null
                    onAccepted: {
                        if (text.length === 0) return;
                        root.notification.sendInlineReply(text);
                        text = "";
                    }
                }
                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    name: "send"
                    size: 15
                    color: reply.text.length > 0 ? Theme.ink : Theme.inkSoft
                }
            }
        }

        // the draining timer line
        Item {
            visible: root.lifetime > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.radiusPopup
            anchors.rightMargin: Theme.radiusPopup
            anchors.bottomMargin: 2
            height: 3

            Iridescent {
                id: drain
                property real remaining: 1
                height: parent.height
                width: parent.width * remaining
                radius: 1.5
                sheen: 0
                period: 6000

                NumberAnimation on remaining {
                    running: root.lifetime > 0
                    paused: running && root.paused
                    from: 1
                    to: 0
                    duration: root.lifetime
                    onFinished: root.expired()
                }
            }
        }
    }

    // swipe right to dismiss
    DragHandler {
        id: swipe
        target: card
        xAxis.enabled: true
        yAxis.enabled: false
        xAxis.minimum: 0
        onActiveChanged: {
            if (active) return;
            if (card.x > root.width * 0.35) {
                flingOut.start();
            } else {
                snapBack.start();
            }
        }
    }

    NumberAnimation {
        id: snapBack
        target: card; property: "x"; to: 0
        duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle
    }
    ParallelAnimation {
        id: flingOut
        NumberAnimation { target: card; property: "x"; to: root.width + 40; duration: 220; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: 220 }
        onFinished: root.dismissed()
    }

    // a click on the body runs the default action, if the app offered one
    TapHandler {
        onTapped: {
            const acts = root.notification?.actions ?? [];
            const def = acts.find(a => a.identifier === "default");
            if (def) def.invoke();
        }
    }
}
