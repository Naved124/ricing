pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import Quickshell
import qs
import qs.common
import qs.services

// One monitor's lock screen: the wallpaper's still frame, blurred and
// veiled in pearl; a large Italiana clock with the iridescent gradient
// running through its digits; the date in small caps; and a pill password
// field. A wrong password shakes the pill and rings it in rose.
Item {
    id: root

    required property var lock
    property var screen
    readonly property string still: Quickshell.env("HOME") + "/.cache/rice/nacre/still.png"
    readonly property bool primary: screen === Hypr.focusedScreen || Quickshell.screens.length === 1

    // the backdrop
    Image {
        id: backdrop
        anchors.fill: parent
        source: "file://" + root.still
        fillMode: Image.PreserveAspectCrop
        cache: false
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: backdrop
        visible: backdrop.status === Image.Ready
        blurEnabled: true
        blurMax: 64
        blur: 1
        saturation: 0.1
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.pearl, backdrop.status === Image.Ready ? 0.35 : 1) }
            GradientStop { position: 1; color: Qt.alpha(Theme.shell, backdrop.status === Image.Ready ? 0.55 : 1) }
        }
    }

    // everything that blooms in on lock and out on unlock
    Item {
        id: stage
        anchors.fill: parent

        property bool shown: false
        Component.onCompleted: shown = true

        readonly property bool visibleNow: shown && !root.lock.leaving
        opacity: visibleNow ? 1 : 0
        scale: visibleNow ? 1 : (root.lock.leaving ? 1.06 : 0.97)
        Behavior on opacity { NumberAnimation { duration: stage.visibleNow ? Theme.durOpen : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: stage.visibleNow ? Theme.bloom : Theme.sink } }
        Behavior on scale { NumberAnimation { duration: stage.visibleNow ? Theme.durOpen : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: stage.visibleNow ? Theme.bloom : Theme.sink } }

        SystemClock { id: clock; precision: SystemClock.Minutes }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.22
            spacing: 6

            // the clock: an iridescent field seen through the digits
            Item {
                id: clockBox
                anchors.horizontalCenter: parent.horizontalCenter
                width: digits.implicitWidth
                height: digits.implicitHeight

                Text {
                    id: digits
                    text: Qt.formatTime(clock.date, "HH:mm")
                    font.family: Theme.fontDisplay
                    font.pixelSize: Math.min(180, root.height * 0.2)
                    color: "black"
                    visible: false
                    layer.enabled: true
                }
                Iridescent {
                    id: field
                    anchors.fill: parent
                    anchors.margins: -20
                    radius: 0
                    sheen: 0.2
                    period: 16000
                    visible: false
                    layer.enabled: true
                }
                // a soft ink shadow keeps pale digits legible on a pale screen
                Text {
                    anchors.fill: digits
                    text: digits.text
                    font: digits.font
                    color: Qt.alpha(Theme.ink, 0.28)
                    layer.enabled: true
                    layer.effect: MultiEffect { blurEnabled: true; blur: 0.35; blurMax: 16 }
                }
                MultiEffect {
                    anchors.fill: parent
                    source: field
                    maskEnabled: true
                    maskSource: digits
                    maskThresholdMin: 0.4
                    maskSpreadAtMin: 0.3
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(clock.date, "dddd, d MMMM")
                font.capitalization: Font.SmallCaps
                font.letterSpacing: 2
                size: 19
                color: Theme.ink
            }
        }

        // the password pill (on the focused monitor; the others just show the time)
        Item {
            id: pill
            visible: root.primary
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.62
            width: 300
            height: 48

            property real shakeX: 0
            transform: Translate { x: pill.shakeX }

            Connections {
                target: root.lock
                function onShake() { shakeAnim.restart(); }
            }
            SequentialAnimation {
                id: shakeAnim
                loops: 1
                NumberAnimation { target: pill; property: "shakeX"; to: -14; duration: 50 }
                NumberAnimation { target: pill; property: "shakeX"; to: 12; duration: 70 }
                NumberAnimation { target: pill; property: "shakeX"; to: -8; duration: 70 }
                NumberAnimation { target: pill; property: "shakeX"; to: 5; duration: 70 }
                NumberAnimation { target: pill; property: "shakeX"; to: 0; duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle }
            }

            Glass {
                anchors.fill: parent
                radius: height / 2
                fill: Theme.glassStrong
                hairline: root.lock.failed ? Theme.rose : field2.activeFocus ? Theme.orchid : Theme.hairline
            }
            // the rose ring on failure
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: height / 2
                color: "transparent"
                border.width: 2
                border.color: Theme.rose
                opacity: root.lock.failed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }
            }
            // busy: the iridescent ring turns
            Iridescent {
                anchors.fill: parent
                anchors.margins: -3
                radius: height / 2
                ring: 2
                sheen: 0
                period: 1600
                visible: root.lock.busy
            }

            Icon {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                name: "lock"
                size: 16
                color: Theme.inkSoft
            }

            TextField {
                id: field2
                anchors.fill: parent
                anchors.leftMargin: 44
                anchors.rightMargin: 44
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                placeholderText: "Password"
                placeholderTextColor: Theme.inkSoft
                color: Theme.ink
                font.family: Theme.fontUi
                font.weight: Theme.weight
                font.pixelSize: 16
                font.letterSpacing: text ? 3 : 0
                background: null
                enabled: !root.lock.busy
                focus: root.primary
                text: root.lock.password
                onTextEdited: { root.lock.password = text; root.lock.failed = false; }
                onAccepted: root.lock.submit()
                Keys.onEscapePressed: root.lock.password = ""

                cursorDelegate: Rectangle {
                    width: 2
                    radius: 1
                    color: Theme.orchid
                    visible: field2.activeFocus
                }
            }
            Component.onCompleted: if (root.primary) field2.forceActiveFocus()

            Icon {
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron-right"
                size: 16
                color: root.lock.password ? Theme.ink : Theme.lilac
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.lock.submit()
                }
            }
        }

        Label {
            visible: root.primary
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: pill.bottom
            anchors.topMargin: 14
            text: root.lock.message
            color: Theme.inkSoft
            size: Theme.uiSize + 2
        }

        // a quiet footer: battery and what's playing
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            spacing: 18
            visible: root.primary

            Row {
                spacing: 6
                visible: Battery.present
                Icon { name: Battery.charging ? "bolt" : "battery"; size: 15; color: Theme.inkSoft; anchors.verticalCenter: parent.verticalCenter }
                Label { text: `${Math.round(Battery.level * 100)}%`; color: Theme.inkSoft; size: Theme.uiSize + 1 }
            }
            Row {
                spacing: 6
                visible: !!Media.player && Media.playing
                Icon { name: "play"; size: 13; color: Theme.inkSoft; anchors.verticalCenter: parent.verticalCenter }
                Label {
                    text: Media.player ? `${Media.player.trackTitle}${Media.player.trackArtist ? " — " + Media.player.trackArtist : ""}` : ""
                    color: Theme.inkSoft
                    size: Theme.uiSize + 1
                    width: Math.min(implicitWidth, 360)
                    elide: Text.ElideRight
                }
            }
        }
    }
}
