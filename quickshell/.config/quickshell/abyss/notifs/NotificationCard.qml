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

// One notification, the mock's card: a small glowing jelly bell on the left
// whose colour says how urgent it is (teal normal, violet low, pink
// critical; a critical one pulses until you touch it), the title spaced in
// Jura, the body in ink-dim, an image if there is one, actions as glass
// pills and an inline reply. In the island (`popup`) the island's glass is
// its glass and a teal thread drains along its foot for its 4 s.
// It rises in on the settle curve; dismissed or done, it sinks 30 px and
// fades on the sink curve (`sink()`, then `sunk`). Swipe it away to dismiss.
Item {
    id: root

    required property var notification
    property bool popup: true          // false in the island's history
    property bool held: false          // the island holds its clock (hovered)
    property bool paused: hover.hovered || reply.activeFocus || held
    property bool touched: false       // a critical one stops pulsing once touched

    readonly property int urgency: notification?.urgency ?? NotificationUrgency.Normal
    readonly property bool critical: urgency === NotificationUrgency.Critical
    readonly property color tone: critical ? Theme.pink : urgency === NotificationUrgency.Low ? Theme.glow2 : Theme.glow
    readonly property int lifetime: popup ? Notifs.lifetime : 0

    signal expired()
    signal dismissed()
    signal sunk()                      // finished sinking

    implicitWidth: 340
    implicitHeight: body.implicitHeight + 24

    // arriving: up from a little below, on the settle curve
    property real lift: 0
    opacity: 1
    transform: Translate { y: root.lift }
    Component.onCompleted: if (popup) arrive.start()
    ParallelAnimation {
        id: arrive
        NumberAnimation { target: root; property: "lift"; from: 10; to: 0; duration: Theme.durOpen; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle }
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: Theme.durOpen * 0.8; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drift }
    }
    // leaving: it sinks
    function sink() { if (!sinking.running) sinking.start(); }
    ParallelAnimation {
        id: sinking
        NumberAnimation { target: root; property: "lift"; to: 30; duration: Theme.durClose + 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sink }
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: Theme.durClose + 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sink }
        onFinished: root.sunk()
    }

    HoverHandler {
        id: hover
        onHoveredChanged: if (hovered) root.touched = true
    }

    Item {
        id: card
        anchors.fill: parent

        // in the history it carries its own glass
        Glass {
            anchors.fill: parent
            visible: !root.popup
            radius: Theme.radiusPopup
            fill: Theme.glassStrong
            line: root.critical ? Theme.pinkAt(0.35) : Theme.line
            halo: 0
        }

        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // the bell, where the mock puts it
                Item {
                    Layout.preferredWidth: 12
                    Layout.preferredHeight: 18
                    Layout.alignment: Qt.AlignTop
                    Bell {
                        y: 3
                        width: 12; height: 9
                        color: root.tone
                        pulse: root.critical && !root.touched
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Label {
                            Layout.fillWidth: true
                            text: root.notification?.summary || root.notification?.appName || ""
                            size: 13
                            weight: Theme.weightStrong
                            spacing: 0.06
                            elide: Text.ElideRight
                        }
                        Label {
                            text: root.notification?.appName ?? ""
                            color: Theme.inkDim
                            size: 11
                            spacing: 0.08
                            visible: text.length > 0 && text !== root.notification?.summary
                        }
                        Item {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            Icon {
                                anchors.centerIn: parent
                                name: "close"
                                size: 12
                                color: Theme.inkDim
                                opacity: hover.hovered || root.popup ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dismissed()
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: root.notification?.body ?? ""
                        visible: text.length > 0
                        color: Theme.inkDim
                        size: 12.5
                        spacing: 0.02
                        wrapMode: Text.Wrap
                        maximumLineCount: root.popup ? 2 : 4
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                }

                ClippingRectangle {
                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 46
                    Layout.alignment: Qt.AlignTop
                    visible: (root.notification?.image ?? "") !== ""
                    radius: Theme.radiusChip
                    color: Theme.shoal
                    Image {
                        anchors.fill: parent
                        source: root.notification?.image ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Rectangle {               // 92% brightness
                        anchors.fill: parent
                        color: Qt.alpha(Theme.abyss, 0.08)
                    }
                }
            }

            // actions, as glass pills
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                spacing: 6
                visible: (root.notification?.actions?.length ?? 0) > 0
                Repeater {
                    model: root.notification?.actions ?? []
                    delegate: Item {
                        id: action
                        required property var modelData
                        width: actionLabel.implicitWidth + 22
                        height: 24
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusChip
                            color: actionMouse.containsMouse ? Theme.washHover : Theme.wash
                            border.color: actionMouse.containsMouse ? Theme.lineOn : Theme.line
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Label {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: action.modelData.text
                            size: 12
                        }
                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.touched = true; action.modelData.invoke(); }
                        }
                    }
                }
            }

            // an inline reply
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.preferredHeight: 28
                visible: !!root.notification?.hasInlineReply
                radius: Theme.radiusChip
                color: Theme.wash
                border.color: reply.activeFocus ? Theme.lineOn : Theme.line
                TextField {
                    id: reply
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 30
                    placeholderText: root.notification?.inlineReplyPlaceholder || "Reply…"
                    placeholderTextColor: Theme.inkDim
                    color: Theme.ink
                    font.family: Theme.fontUi
                    font.weight: Theme.weight
                    font.pixelSize: 13
                    background: null
                    onActiveFocusChanged: if (activeFocus) root.touched = true
                    onAccepted: {
                        if (text.length === 0) return;
                        root.notification.sendInlineReply(text);
                        text = "";
                    }
                }
                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    name: "send"
                    size: 13
                    color: reply.text.length > 0 ? Theme.glow : Theme.inkDim
                }
            }
        }

        // its time, a thread of light draining along the foot
        Item {
            visible: root.lifetime > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.radiusPopup
            anchors.rightMargin: Theme.radiusPopup
            anchors.bottomMargin: 2
            height: 2
            Rectangle {
                id: drain
                property real remaining: 1
                height: parent.height
                width: parent.width * remaining
                radius: 1
                color: root.tone
                opacity: 0.7
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

    // swipe it away
    DragHandler {
        id: swipe
        target: card
        xAxis.enabled: true
        yAxis.enabled: false
        xAxis.minimum: 0
        onActiveChanged: {
            if (active) { root.touched = true; return; }
            if (card.x > root.width * 0.35) root.dismissed();
            else snapBack.start();
        }
    }
    NumberAnimation {
        id: snapBack
        target: card; property: "x"; to: 0
        duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle
    }

    // a click on the body runs the default action, if the app offered one
    TapHandler {
        onTapped: {
            root.touched = true;
            const acts = root.notification?.actions ?? [];
            const def = acts.find(a => a.identifier === "default");
            if (def) def.invoke();
        }
    }
}
