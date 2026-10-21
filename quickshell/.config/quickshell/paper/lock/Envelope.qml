pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.common
import qs.services
import "../common/paper.js" as P

// One monitor's lock screen: a torn envelope on a dimmed kraft desk (at
// night, dark walnut kraft under the lamp's pool, with cream type). The
// time huge in Newsreader above it, the date in Courier. On the envelope
// the password is typed out as • with a blinking carriage underscore, each
// dot struck a little off its line like a real typebar. A wrong password
// shakes the envelope and strikes the line through in red. The right one
// opens the flap, slides the letter up and fades the whole thing out.
Item {
    id: root

    required property var lock
    property var screen
    readonly property bool primary: screen === Hypr.focusedScreen || Quickshell.screens.length <= 1
    readonly property real k: Math.max(0.6, Math.min(width / 1920, height / 1080))

    // the desk: kraft, dimmed towards the edges
    Rectangle {
        anchors.fill: parent
        color: Qt.darker(Theme.kraft, 1.25)
    }
    Image {
        anchors.fill: parent
        source: "file://" + Theme.paperTex
        fillMode: Image.Tile
        opacity: 0.18
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.soot, 0.2) }
            GradientStop { position: 0.35; color: Qt.alpha(Theme.soot, 0) }
            GradientStop { position: 0.75; color: Qt.alpha(Theme.soot, 0) }
            GradientStop { position: 1; color: Qt.alpha(Theme.soot, 0.25) }
        }
    }
    // at night the lamp's warm pool lies on the desk, top left
    Shape {
        anchors.fill: parent
        visible: Theme.k > 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: Theme.lampPos.x * root.width
                centerY: Theme.lampPos.y * root.height
                centerRadius: 0.45 * root.width
                focalX: centerX
                focalY: centerY
                GradientStop { position: 0; color: Theme.lampPool }
                GradientStop { position: 1; color: "transparent" }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }

    Item {
        id: stage
        anchors.fill: parent
        opacity: root.lock.opening ? 0 : 1
        Behavior on opacity { SequentialAnimation { PauseAnimation { duration: root.lock.opening ? 450 : 0 } NumberAnimation { duration: 600; easing.type: Easing.InQuad } } }

        SystemClock { id: clock; precision: SystemClock.Minutes }

        Column {
            id: header
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * 0.12
            spacing: 4
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10 * root.k
                Serif {
                    id: time
                    text: Qt.formatTime(clock.date, "h:mm ap").split(" ")[0]
                    size: Math.round(170 * root.k)
                    weight: 500
                    color: Theme.deskType
                    style: Text.Raised
                    styleColor: Qt.alpha(Theme.soot, 0.333)
                }
                Hand {
                    anchors.baseline: time.baseline
                    text: Qt.formatTime(clock.date, "h:mm ap").split(" ")[1] ?? ""
                    size: Math.round(34 * root.k)
                    color: Theme.deskType
                }
            }
            Type {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(clock.date, "dddd d MMMM yyyy").toUpperCase()
                size: Math.round(16 * root.k)
                color: Theme.deskType
                font.letterSpacing: 16 * root.k * 0.3
            }
        }

        // ── the envelope ───────────────────────────────────────────────
        Item {
            id: envelope
            width: Math.round(520 * root.k)
            height: Math.round(320 * root.k)
            x: (root.width - width) / 2 + shakeX
            y: root.height * 0.5
            property real shakeX: 0

            Connections {
                target: root.lock
                function onShake() { shakeAnim.restart(); }
            }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: envelope; property: "shakeX"; to: -16; duration: 50 }
                NumberAnimation { target: envelope; property: "shakeX"; to: 13; duration: 70 }
                NumberAnimation { target: envelope; property: "shakeX"; to: -9; duration: 70 }
                NumberAnimation { target: envelope; property: "shakeX"; to: 5; duration: 70 }
                NumberAnimation { target: envelope; property: "shakeX"; to: 0; duration: 200; easing.type: Easing.OutBack }
            }

            // the letter, tucked inside: slides up and out when it opens
            Sheet {
                id: letter
                x: envelope.width * 0.06
                width: envelope.width * 0.88
                height: envelope.height * 0.9
                y: root.lock.opening ? -envelope.height * 0.75 : envelope.height * 0.06
                fill: Theme.card
                seed: 77
                ruled: true
                ruleTop: 40
                ruleGap: 26
                Behavior on y { SequentialAnimation { PauseAnimation { duration: root.lock.opening ? 220 : 0 } NumberAnimation { duration: 520; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drop } } }
                Hand {
                    x: 26
                    y: 14
                    text: "welcome back."
                    size: 22
                    color: Theme.ink
                }
            }

            // the back of the envelope and its pocket
            Sheet {
                anchors.fill: parent
                fill: Theme.envelope
                seed: 520
                z: -1
            }
            Shape {
                id: pocket
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: Theme.envelope
                    strokeColor: Qt.alpha(Theme.umber, 0.12)
                    strokeWidth: 1
                    PathSvg {
                        path: `M 0 0 L ${envelope.width / 2} ${envelope.height * 0.54} L ${envelope.width} 0 L ${envelope.width} ${envelope.height} L 0 ${envelope.height} Z`
                    }
                }
                // the side folds
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.alpha(Theme.umber, 0.15)
                    strokeWidth: 1
                    PathSvg { path: `M 0 ${envelope.height} L ${envelope.width * 0.42} ${envelope.height * 0.58} M ${envelope.width} ${envelope.height} L ${envelope.width * 0.58} ${envelope.height * 0.58}` }
                }
            }

            // the flap: closed over the letter; it flips up to open
            Item {
                id: flap
                width: envelope.width
                height: envelope.height * 0.58
                z: root.lock.opening ? -0.5 : 1
                property real fold: root.lock.opening ? -1 : 1
                Behavior on fold { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }
                transform: Scale { origin.y: 0; yScale: flap.fold }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: Qt.darker(Theme.envelope, 1.04)
                        strokeColor: Qt.alpha(Theme.umber, 0.17)
                        strokeWidth: 1
                        // a torn edge along the flap's two sides
                        PathSvg {
                            path: P.pencil([[0, 0], [flap.width / 2, flap.height], [flap.width, 0]], 33, 1.4, false) + " Z"
                        }
                    }
                }
                // the wax seal
                Item {
                    x: flap.width / 2 - width / 2
                    y: flap.height - height * 0.7
                    width: 64 * root.k
                    height: width
                    visible: flap.fold > 0
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: Theme.red
                            strokeColor: Qt.darker(Theme.red, 1.3)
                            strokeWidth: 1
                            PathSvg { path: P.crumple(32 * root.k, 32 * root.k, 30 * root.k, 9).outline }
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.62
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.color: Qt.darker(Theme.red, 1.35)
                        border.width: 2
                    }
                    Serif {
                        anchors.centerIn: parent
                        text: "P"
                        size: 24 * root.k
                        weight: 700
                        color: Qt.darker(Theme.red, 1.45)
                    }
                }
            }

            // the typed line, on the envelope's front
            Item {
                id: line
                visible: root.primary
                z: 2
                x: envelope.width * 0.14
                width: envelope.width * 0.72
                y: envelope.height * 0.74
                height: 34 * root.k

                Row {
                    id: typed
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Type {
                        text: root.lock.password.length || root.lock.busy ? "" : "password:"
                        size: 18 * root.k
                        color: Theme.graphite
                        visible: text.length > 0
                    }
                    Repeater {
                        model: Math.min(root.lock.password.length, 28)
                        delegate: Type {
                            required property int index
                            readonly property real seedY: P.between(index * 977 + 13, -1.6, 1.6)
                            text: "•"
                            size: 20 * root.k
                            color: Theme.carbon
                            opacity: P.between(index * 31 + 7, 0.72, 1)
                            transform: Translate { y: seedY }
                        }
                    }
                    // the carriage: a blinking underscore
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: 10 * root.k
                        height: 2
                        color: Theme.carbon
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: true
                            NumberAnimation { to: 0; duration: 0 }
                            PauseAnimation { duration: 500 }
                            NumberAnimation { to: 1; duration: 0 }
                            PauseAnimation { duration: 500 }
                        }
                    }
                }
                // wrong: struck through in red
                Rectangle {
                    visible: root.lock.failed
                    x: -6
                    width: Math.max(80, typed.width + 12)
                    y: parent.height / 2
                    height: 2
                    rotation: -1.5
                    color: Theme.red
                }
                Hand {
                    anchors.top: parent.bottom
                    anchors.topMargin: 4
                    text: root.lock.message
                    size: 15 * root.k
                    color: Theme.red
                }

                // the keys go here; nothing of it is drawn
                TextInput {
                    id: input
                    anchors.fill: parent
                    opacity: 0
                    focus: root.primary
                    echoMode: TextInput.Password
                    enabled: !root.lock.busy && !root.lock.opening
                    text: root.lock.password
                    onTextEdited: {
                        // after a wrong one, the struck-out line goes and typing starts afresh
                        if (root.lock.failed) {
                            const fresh = text.length > root.lock.password.length ? text.slice(root.lock.password.length) : "";
                            root.lock.failed = false;
                            root.lock.message = "";
                            root.lock.password = fresh;
                            text = Qt.binding(() => root.lock.password);
                            return;
                        }
                        root.lock.password = text;
                    }
                    onAccepted: root.lock.submit()
                    Keys.onEscapePressed: root.lock.password = ""
                }
                Component.onCompleted: if (root.primary) input.forceActiveFocus()
            }
        }

        // a quiet footer: battery and what's playing
        Hand {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 34
            visible: root.primary && text.length > 0
            text: [Battery.present ? `batt ${Math.round(Battery.level * 100)}%` : "",
                   Media.playing && Media.player ? `♪ ${Media.player.trackTitle}` : ""].filter(s => s).join("   ·   ")
            size: 17
            color: Theme.deskType
        }
    }
}
