pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.common
import qs.plate
import qs.services

// One monitor's title card: the plate with the hour's grade only (or as it
// is, with the Compositing switch off), blurred a little, darkened and fading into the glass tint at the bottom. Bottom left,
// 第295話 · EPISODE 295 in the accent, today's title huge in Dela Gothic One
// with its English under it, and the time and date; bottom right, the
// password in a glass pill with the accent's arrow. A wrong password shakes
// the pill and says so; the right one fades the card out.
Item {
    id: root

    required property var lock
    property var screen
    readonly property bool primary: screen === Hypr.focusedScreen || Quickshell.screens.length === 1

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var ep: lock.episode(clock.date)

    opacity: lock.leaving ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: 550; easing.type: Easing.InOutQuad } }

    // ── the plate: graded, softened, darkened ───────────────────────────────
    Pass {
        id: plate
        anchors.fill: parent
        source: Theme.plate
        bloomSource: Theme.bloomMap
        softSource: Theme.softMap
        animated: false
        plateSize: Theme.plateSize
        light: Qt.point(Theme.lightX, Theme.lightY)
        // the Compositing switch holds here too: off, the plate as it is
        bloom: Settings.s.pass && Settings.s.bloom ? 0.6 : 0
        rays: 0
        motes: 0
        grain: 0
        grade: Settings.s.pass && Settings.s.grade ? 1 : 0
        pass: Settings.s.pass ? 1 : 0
        frost: 0
        expo: Settings.s.expo * 0.8
        playing: false
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.35
            blurMax: 24
            brightness: -0.12
            saturation: 0.2
        }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.35; color: Theme.at(Theme.ink, 0) }
            GradientStop { position: 1.0; color: Theme.at(Theme.ink, 0.7) }
        }
    }

    // ── the card ────────────────────────────────────────────────────────────
    Item {
        id: card
        anchors.fill: parent
        anchors.margins: 56
        anchors.leftMargin: 64

        Column {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: Math.min(parent.width * 0.62, 1100)
            spacing: 0

            Label {
                text: `第${root.ep.n}話 · EPISODE ${root.ep.n}`
                size: 14
                weight: Style.weightStrong
                spacing: 0.32
                color: Theme.accent
            }
            Item { width: 1; height: 12 }
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                display: true
                size: Math.min(96, root.height * 0.09)
                lineHeight: 1.02
                text: root.ep.ja
                style: Text.Raised
                styleColor: Theme.at(Theme.ink, 0.45)
            }
            Item { width: 1; height: 10 }
            Label {
                text: root.ep.en
                size: Math.min(20, root.height * 0.02)
                color: Theme.fgDim
            }
            Item { width: 1; height: 34 }
            Label {
                display: true
                size: Math.min(76, root.height * 0.07)
                text: Qt.formatTime(clock.date, "HH:mm")
            }
            Item { width: 1; height: 6 }
            Label {
                text: Qt.formatDate(clock.date, "dddd, d MMMM")
                size: 15
                weight: Style.weightStrong
                color: Theme.fgDim
            }
        }

        // ── the password ─────────────────────────────────────────────────
        Column {
            visible: root.primary
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 10

            Label {
                anchors.right: parent.right
                anchors.rightMargin: 18
                text: root.lock.message
                size: 12.5
                weight: Style.weightStrong
                color: root.lock.failed ? Theme.urgent : Theme.fgDim
            }
            Glass {
                id: pill
                width: 320
                height: 48
                radius: 24
                property real shakeX: 0
                transform: Translate { x: pill.shakeX }

                Connections {
                    target: root.lock
                    function onShake() { shake.restart(); }
                }
                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: pill; property: "shakeX"; to: -10; duration: 60; easing.type: Easing.OutSine }
                    NumberAnimation { target: pill; property: "shakeX"; to: 8; duration: 90; easing.type: Easing.InOutSine }
                    NumberAnimation { target: pill; property: "shakeX"; to: -5; duration: 90; easing.type: Easing.InOutSine }
                    NumberAnimation { target: pill; property: "shakeX"; to: 0; duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.settle }
                }

                TextInput {
                    id: input
                    x: 20
                    width: parent.width - 76
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    focus: root.primary
                    color: Theme.fg
                    selectionColor: Theme.at(Theme.accent, 0.3)
                    font.family: Style.fontUi
                    font.pixelSize: 15
                    font.letterSpacing: 3
                    clip: true
                    text: root.lock.password
                    onTextEdited: { root.lock.password = text; root.lock.failed = false; }
                    onAccepted: root.lock.submit()
                    Keys.onEscapePressed: root.lock.password = ""
                    Label {
                        visible: !input.text
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.lock.busy ? "Checking…" : "Press Enter to unlock"
                        size: 14
                        color: Theme.fgDim
                    }
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 36; radius: 18
                    color: Theme.accent
                    opacity: root.lock.busy ? 0.6 : 1
                    Icon {
                        anchors.centerIn: parent
                        name: "chevron-right"
                        size: 18
                        stroke: 2.4
                        color: Theme.onAccent
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.lock.submit()
                    }
                }
            }
        }
    }
    // a click anywhere gives the field its keys back
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: input.forceActiveFocus()
    }
}
