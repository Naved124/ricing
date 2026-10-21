pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.common
import qs.services
import "../common/paper.js" as P

// One notification as a sticky note: mint for low urgency, yellow for
// normal, pink for critical; a darker adhesive band across the top, light
// catching the top-left corner, and a tilt between −3.5° and +3.5° that is
// the same every time for the same notification.
// The island's history lays them out; a click peels one off (a twist and
// a skew, then it drops away) and dismisses it. Actions are underlined
// words; an image is taped onto the corner; the app's icon is a small
// pencil sketch.
Item {
    id: root

    required property var notification
    property real ui: 1          // UI scale (Theme.uiSize / 14)

    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property bool low: notification?.urgency === NotificationUrgency.Low
    readonly property color paperColour: critical ? Theme.pink : low ? Theme.mint : Theme.sticky
    // at night the note is black card and the colour is only its strip of
    // adhesive; by day the whole note is the colour
    readonly property color body: Theme.mode.mix(paperColour, Theme.card)
    readonly property real tilt: P.between(P.hash((notification?.id ?? 0) + ":" + (notification?.appName ?? "")), -3.5, 3.5)
    property bool leaving: false

    implicitWidth: 186 * ui
    implicitHeight: Math.max(110 * ui, content.y + content.implicitHeight + 28 * ui)

    // done with the note: peel it, then dismiss it
    function peel() {
        if (leaving) return;
        leaving = true;
        peelAnim.start();
    }

    Item {
        id: note
        width: root.width
        height: root.height
        transformOrigin: Item.TopLeft

        property real skew: 0         // degrees, for the peel
        rotation: root.tilt
        transform: [
            Matrix4x4 {
                matrix: Qt.matrix4x4(1, Math.tan(note.skew * Math.PI / 180), 0, 0,
                                     0, 1, 0, 0,
                                     0, 0, 1, 0,
                                     0, 0, 0, 1)
            }
        ]

        // the note's shadow: close at the top where it's stuck, falling
        // away towards the curling bottom
        Rectangle {
            anchors.fill: paper
            anchors.topMargin: 6
            color: Theme.umber
            visible: false
            id: shadowSrc
        }
        MultiEffect {
            anchors.fill: shadowSrc
            source: shadowSrc
            autoPaddingEnabled: true
            shadowEnabled: true
            shadowColor: Theme.umber
            shadowOpacity: 0.35
            shadowBlur: 0.55
            shadowHorizontalOffset: 2
            shadowVerticalOffset: 10
            opacity: 0.6
            // only the shadow: the source rectangle itself is covered by the note
        }

        Rectangle {
            id: paper
            anchors.fill: parent
            color: root.body

            // light on the top-left corner
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: Qt.lighter(root.body, 1.12) }
                GradientStop { position: 0.4; color: root.body }
                GradientStop { position: 1; color: Qt.darker(root.body, 1.02) }
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.alpha(Theme.chalk, 0.2) }
                    GradientStop { position: 0.4; color: Qt.alpha(Theme.chalk, 0) }
                }
            }
            // the adhesive band: a faint shade by day, the note's colour at night
            Rectangle {
                width: parent.width
                height: 14 * root.ui
                color: Theme.mode.mix(Qt.alpha(Theme.soot, 0.05), root.paperColour)
            }
            Image {
                anchors.fill: parent
                source: "file://" + Theme.paperTex
                fillMode: Image.Tile
                opacity: 0.12
            }
        }

        Column {
            id: content
            x: 16 * root.ui
            y: 22 * root.ui
            width: parent.width - 32 * root.ui
            spacing: 4 * root.ui

            Hand {
                width: parent.width
                text: root.notification?.summary || root.notification?.appName || ""
                size: 16 * root.ui
                weight: 700
                color: Theme.mode.mix(Theme.felt, Theme.ink)    // the summary in gel-blue at night
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Hand {
                width: parent.width
                visible: text.length > 0
                text: root.notification?.body ?? ""
                size: 16 * root.ui
                color: Theme.felt
                lineHeight: 0.95
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
            // actions: underlined words
            Flow {
                width: parent.width
                spacing: 10 * root.ui
                visible: actions.count > 0
                Repeater {
                    id: actions
                    model: (root.notification?.actions ?? []).filter(a => a.identifier !== "default" || a.text)
                    delegate: Hand {
                        required property var modelData
                        text: modelData.text || "open"
                        size: 15 * root.ui
                        color: Theme.ink
                        font.underline: true
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -3
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { parent.modelData.invoke(); root.peel(); }
                        }
                    }
                }
            }
        }

        // the app, sketched small in the corner
        Item {
            x: 8 * root.ui
            y: root.height - height - 6 * root.ui
            width: 16 * root.ui
            height: width
            IconImage {
                id: appIcon
                anchors.fill: parent
                implicitSize: parent.width
                visible: false
                source: {
                    const n = root.notification;
                    const name = n?.appIcon || n?.desktopEntry || "";
                    return name.startsWith("/") || name.startsWith("file:") ? name
                        : name ? Quickshell.iconPath(name, true) : "";
                }
            }
            MultiEffect {
                anchors.fill: parent
                source: appIcon
                visible: appIcon.status === Image.Ready
                saturation: -1
                colorization: 1
                colorizationColor: Theme.pencil
                opacity: 0.6
            }
        }
        Hand {
            anchors.right: parent.right
            anchors.rightMargin: 10 * root.ui
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6 * root.ui
            text: root.critical ? "important · tap to peel" : "tap to peel"
            size: 12 * root.ui
            color: Theme.felt
            opacity: 0.55
        }

        // an image, taped onto the corner
        Item {
            visible: (root.notification?.image ?? "") !== ""
            x: root.width - width + 12 * root.ui
            y: -10 * root.ui
            width: 64 * root.ui
            height: 64 * root.ui
            rotation: 5
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                color: Theme.chalk
            }
            Image {
                anchors.fill: parent
                source: root.notification?.image ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            // 92% brightness at night
            Rectangle {
                anchors.fill: parent
                color: Theme.imageShade
            }
            Tape {
                x: -12
                y: -8
                width: 44
                height: 16
                rotation: -12
            }
        }
    }

    // peeled off: a twist and a skew as it comes unstuck, then it drops
    SequentialAnimation {
        id: peelAnim
        ParallelAnimation {
            NumberAnimation { target: note; property: "rotation"; to: -14; duration: 240; easing.type: Easing.OutQuad }
            NumberAnimation { target: note; property: "skew"; to: -6; duration: 240 }
            NumberAnimation { target: note; property: "y"; to: -8; duration: 240 }
        }
        ParallelAnimation {
            NumberAnimation { target: note; property: "rotation"; to: 30; duration: 360; easing.type: Easing.InQuad }
            NumberAnimation { target: note; property: "x"; to: 80; duration: 360; easing.type: Easing.InQuad }
            NumberAnimation { target: note; property: "y"; to: 520; duration: 360; easing.type: Easing.InQuad }
            NumberAnimation { target: note; property: "opacity"; to: 0; duration: 360; easing.type: Easing.InQuad }
        }
        ScriptAction { script: Notifs.dismiss(root.notification) }
    }

    // a click on the note peels it off
    TapHandler {
        onTapped: root.peel()
    }
}
