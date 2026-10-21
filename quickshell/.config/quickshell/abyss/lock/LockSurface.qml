pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs
import qs.common
import qs.reef
import qs.services

// One monitor's lock screen: its own reef, a quarter darker with its bloom a
// little up; a big Jura clock glowing teal; the date, spaced; and the
// password as a row of plankton that light up one by one as you type. A
// wrong password sends a pink ripple out from the row (and through the
// water) and shakes it softly; the right one clears the water upward, from
// the bottom of the screen to the top.
Item {
    id: root

    required property var lock
    property var screen
    readonly property bool primary: screen === Hypr.focusedScreen || Quickshell.screens.length === 1

    Item {
        id: scene
        anchors.fill: parent

        Reef {
            id: reef
            anchors.fill: parent
            seed: 20261021 + 104729
            colors: Theme.reefColors
            kelpColor: Theme.c("kelp")
            hues: Theme.reefHues
            waterTop: Theme.waterTop
            waterMid: Theme.waterMid
            waterBottom: Theme.waterBottom
            still: "file://" + Quickshell.env("HOME") + "/.config/rices/abyss/assets/wall-static.png"
            fps: Config.fps
            sceneScale: Config.scale
            plankton: Config.plankton
            fish: Config.fish
            jellies: Config.jellies
            interactive: true
            reducedMotion: Motion.reduced
            dim: 0.75
            bloomGain: 1.3
            dpr: root.screen?.devicePixelRatio ?? 1
            name: (root.screen?.name ?? "") + " (lock)"
            throttle: "lock"
        }

        SystemClock { id: clock; precision: SystemClock.Minutes }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.2
            spacing: 4

            Text {
                id: digits
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.date, "HH:mm")
                color: Theme.ink
                font.family: Theme.fontDisplay
                font.weight: Theme.weightDisplay
                readonly property real big: Math.min(160, root.height * 0.17)
                font.pixelSize: big
                font.letterSpacing: big * 0.08
                font.features: { "tnum": 1 }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.glowAt(0.45)
                    shadowBlur: 1.0
                    shadowVerticalOffset: 0
                    shadowHorizontalOffset: 0
                    autoPaddingEnabled: true
                }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(clock.date, "dddd  d  MMMM").toUpperCase()
                size: 14
                spacing: 0.3
                color: Theme.inkDim
            }
        }

        // the password: plankton, lit one per character
        Item {
            id: field
            visible: root.primary
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.64
            width: 320
            height: 40

            readonly property int lit: root.lock.password.length
            readonly property int slots: Math.max(12, lit + 2)
            property real shakeX: 0
            transform: Translate { x: field.shakeX }

            Connections {
                target: root.lock
                function onShake() {
                    shakeAnim.restart();
                    ring.restart();
                    const p = field.mapToItem(root, field.width / 2, field.height / 2);
                    reef.disturb(p.x, p.y, 1);
                }
            }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: field; property: "shakeX"; to: -10; duration: 60; easing.type: Easing.OutSine }
                NumberAnimation { target: field; property: "shakeX"; to: 8; duration: 90; easing.type: Easing.InOutSine }
                NumberAnimation { target: field; property: "shakeX"; to: -5; duration: 90; easing.type: Easing.InOutSine }
                NumberAnimation { target: field; property: "shakeX"; to: 0; duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle }
            }

            // a pink ring running out from the row
            Rectangle {
                id: ringShape
                anchors.centerIn: parent
                property real grow: 0
                width: field.width * (0.6 + 1.6 * grow)
                height: field.height * (1 + 5 * grow)
                radius: height / 2
                color: "transparent"
                border.width: 2
                border.color: Theme.pink
                opacity: (1 - grow) * 0.8
                visible: grow > 0 && grow < 1
            }
            NumberAnimation {
                id: ring
                target: ringShape; property: "grow"; from: 0.001; to: 1
                duration: 1100; easing.type: Easing.OutCubic
            }

            Row {
                id: dots
                anchors.centerIn: parent
                spacing: 12
                Repeater {
                    model: field.slots
                    delegate: Item {
                        id: speck
                        required property int index
                        readonly property bool on: index < field.lit
                        width: 6; height: 6
                        Glow {
                            anchors.centerIn: parent
                            width: speck.on ? 34 : 14; height: width
                            color: root.lock.failed ? Theme.pink : Theme.glow
                            opacity: speck.on ? 0.85 : 0.15
                            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
                            Behavior on opacity { NumberAnimation { duration: 260 } }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: speck.on ? 5 : 3; height: width; radius: width / 2
                            color: speck.on ? Theme.ink : Theme.inkDim
                            opacity: speck.on ? 1 : 0.4
                        }
                    }
                }
            }
            // busy: the lit dots breathe
            SequentialAnimation on opacity {
                running: root.lock.busy
                loops: Animation.Infinite
                onStopped: field.opacity = 1
                NumberAnimation { to: 0.55; duration: 450 }
                NumberAnimation { to: 1; duration: 450 }
            }

            // what you type goes here; nothing of it is shown but the dots
            TextInput {
                id: input
                anchors.fill: parent
                opacity: 0
                echoMode: TextInput.Password
                enabled: !root.lock.busy
                focus: root.primary
                text: root.lock.password
                onTextEdited: { root.lock.password = text; root.lock.failed = false; }
                onAccepted: root.lock.submit()
                Keys.onEscapePressed: root.lock.password = ""
            }
            Component.onCompleted: if (root.primary) input.forceActiveFocus()
            MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }
        }

        Label {
            visible: root.primary
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: field.bottom
            anchors.topMargin: 12
            text: root.lock.message || (root.lock.password ? "" : "type to surface")
            color: root.lock.failed ? Theme.pink : Theme.inkDim
            size: 12
            spacing: 0.16
        }

        // a quiet footer: battery and what's playing
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 34
            spacing: 18
            visible: root.primary
            Row {
                spacing: 6
                visible: Battery.present
                Icon { name: Battery.charging ? "bolt" : "battery"; size: 14; color: Theme.inkDim; anchors.verticalCenter: parent.verticalCenter }
                Label { text: `${Math.round(Battery.level * 100)}%`; color: Theme.inkDim; size: 12 }
            }
            Row {
                spacing: 6
                visible: !!Media.player && Media.playing
                Icon { name: "play"; size: 12; color: Theme.inkDim; anchors.verticalCenter: parent.verticalCenter }
                Label {
                    text: Media.player ? `${Media.player.trackTitle}${Media.player.trackArtist ? " — " + Media.player.trackArtist : ""}` : ""
                    color: Theme.inkDim
                    size: 12
                    width: Math.min(implicitWidth, 360)
                    elide: Text.ElideRight
                }
            }
        }

        // unlocking: the water clears upward
        layer.enabled: clearing.clear > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: clearing
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.25
        }
    }

    // the mask: opaque above the clearing front, clear below it, the front
    // rising from the bottom edge to the top
    Item {
        id: clearing
        property real clear: root.lock.leaving ? 1 : 0
        Behavior on clear { NumberAnimation { duration: 850; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drift } }
        anchors.fill: parent
        visible: false
        layer.enabled: true
        // twice the screen: opaque over its top half, its soft front just
        // under that, clear below; at rest it covers the screen, cleared it
        // has risen past the top
        Rectangle {
            width: parent.width
            height: parent.height * 2
            y: -parent.height * 1.2 * clearing.clear
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.ink }
                GradientStop { position: 0.5; color: Theme.ink }
                GradientStop { position: 0.6; color: "transparent" }
            }
        }
    }
}
