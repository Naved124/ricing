pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.common
import qs.notifs
import qs.services

// The island: a pill of glass in the middle of the bar, on its own layer so
// it can grow. It always starts with the time, the mock's clock (Jura, 15,
// spaced .12 em, a teal glow; hover for the date, click for the month) and
// ends with what's waiting in the history (a jelly bell and the count, or a
// lone plankton dot when there's nothing).
//   · something playing: the cover, the track (drifting past when long) and
//     the music as a few plankton dots; the pill's halo breathes with the
//     beat (Beat.level); hover brings out play/pause and next
//   · a notification: the island grows into its card, which rises in, and
//     the water under it is touched; after 4 s (hover holds it), or
//     dismissed, the card sinks and the island shrinks back
//   · a click: the drop-down, what's playing on top and the history below;
//     Esc or a click outside closes it
// Notifications show on the focused monitor; while a window is fullscreen
// only they do.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property bool fullscreen: Hypr.fullscreenOn(monitor)
    readonly property bool focused: Hypr.focusedScreen?.name === screen?.name
    readonly property bool open: Shell.islandOpen && Shell.islandScreen === screen?.name
    readonly property var note: focused && !open ? Notifs.current : null
    readonly property string mode: open ? "open" : note ? "note" : "pill"
    readonly property bool shown: mode !== "pill" || !fullscreen

    readonly property bool playing: Media.playing
    readonly property var player: Media.player
    readonly property bool hovered: hover.hovered && mode === "pill"
    readonly property int count: Notifs.all.length

    // the bar is 34 tall, 10 from the top; the island sits 3 in from its edge
    readonly property int top: 13
    readonly property int pillHeight: 28

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "abyss-island"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // only the island takes the pointer; open, the whole screen does (to close it)
    mask: Region { item: win.open ? catcher : win.shown ? island : null }

    onOpenChanged: {
        if (!open) return;
        Notifs.seen();
        flick.contentY = 0;
        keys.forceActiveFocus();
    }

    // a notification arriving: the reef's nearest jelly flares under it
    Connections {
        target: Notifs
        function onArrived(n) {
            if (win.focused) Reefs.notify(win.screen, win.width / 2, win.top + 20);
        }
    }
    // the card landing touches the water just under it
    onNoteChanged: if (note) landTimer.restart()
    Timer {
        id: landTimer
        interval: Theme.durOpen * 0.6
        onTriggered: Reefs.disturb(win.screen, win.width / 2, win.top + island.height + 6, 0.6)
    }

    MouseArea {
        id: catcher
        anchors.fill: parent
        enabled: win.open
        onClicked: Shell.islandOpen = false
    }
    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: Shell.islandOpen = false
    }

    Item {
        id: island

        readonly property real wantWidth: win.mode === "open" ? 400
                                        : win.mode === "note" ? 340
                                        : pill.implicitWidth + 22
        readonly property real wantHeight: win.mode === "open" ? Math.min(panel.implicitHeight + 32, win.height - win.top - 60)
                                         : win.mode === "note" ? Math.max(win.pillHeight, notes.height)
                                         : win.pillHeight
        readonly property real radius: win.mode === "pill" ? win.pillHeight / 2 : Theme.radiusPanel

        x: Math.round((win.width - width) / 2)
        y: win.top
        width: Math.round(wantWidth)
        height: Math.round(wantHeight)
        opacity: win.shown ? 1 : 0
        visible: opacity > 0
        Behavior on width { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
        Behavior on height { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }

        HoverHandler { id: hover }

        Glass {
            anchors.fill: parent
            radius: island.radius
            fill: win.mode === "pill" ? Theme.glass : Theme.glassStrong
            line: win.note?.urgency === 2 && win.mode === "note" ? Theme.pinkAt(0.35) : win.mode === "note" ? Theme.glow2At(0.35) : Theme.line
            // playing, the halo breathes with the beat
            halo: win.playing && win.mode === "pill" ? 0.06 + 0.22 * Beat.level : win.mode === "note" ? 0.08 : 0.05
            Behavior on radius { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
        }

        // ── the pill ────────────────────────────────────────────────────
        MouseArea {
            anchors.fill: parent
            enabled: win.mode === "pill"
            cursorShape: Qt.PointingHandCursor
            onClicked: Shell.toggleIsland(win.screen?.name)
        }

        Row {
            id: pill
            x: 11
            height: win.pillHeight
            spacing: 10
            opacity: win.mode === "pill" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }

            // the time; hover shows the date, a click the month
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: timeRow.implicitWidth
                height: 24
                HoverHandler { id: timeHover }
                Row {
                    id: timeRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: timeHover.hovered ? date.implicitWidth : 0
                        height: date.implicitHeight
                        clip: true
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
                        Label {
                            id: date
                            text: Qt.formatDate(clock.date, "ddd d MMM")
                            color: Theme.inkDim
                            size: 12
                            spacing: 0.08
                        }
                    }
                    Label {
                        id: time
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatTime(clock.date, "HH:mm")
                        font.family: Theme.fontDisplay
                        size: 15
                        weight: Theme.weightDisplay
                        spacing: 0.12
                        font.features: { "tnum": 1 }
                        // the mock's text-shadow: 0 0 12px teal at 35%
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Theme.glowAt(0.35)
                            shadowBlur: 0.6
                            shadowVerticalOffset: 0
                            shadowHorizontalOffset: 0
                            autoPaddingEnabled: true
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Shell.toggleCenter("calendar")
                }
                SystemClock { id: clock; precision: SystemClock.Minutes }
            }

            // something playing: cover, track, the music; hover adds controls
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: win.playing

                ClippingRectangle {
                    width: 20; height: 20
                    radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.shoal
                    Image {
                        anchors.fill: parent
                        source: win.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(40, 40)
                        asynchronous: true
                    }
                    Rectangle {               // 92% brightness
                        anchors.fill: parent
                        color: Qt.alpha(Theme.abyss, 0.08)
                    }
                }
                Marquee {
                    id: track
                    readonly property string text: {
                        const p = win.player;
                        if (!p) return "";
                        return p.trackArtist ? `${p.trackTitle} · ${p.trackArtist}` : (p.trackTitle ?? "");
                    }
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(Math.min(contentWidth, win.hovered ? 170 : 140))
                    height: 24
                    speed: 30
                    delegate: Label {
                        text: track.text
                        size: 12
                        color: Theme.ink
                        spacing: 0.06
                    }
                }
                // the music: a few plankton dots, lifted by Beat.levels
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Repeater {
                        model: 5
                        delegate: Item {
                            id: d
                            required property int index
                            readonly property real level: Beat.levels[Math.floor(index * Beat.bars / 5)] ?? 0
                            width: 3; height: 14
                            Glow {
                                anchors.centerIn: dotHead
                                width: 12 + 8 * d.level; height: width
                                color: Theme.glow
                                opacity: 0.3 + 0.6 * d.level
                            }
                            Rectangle {
                                id: dotHead
                                y: (14 - 3) * (1 - d.level)
                                width: 3; height: 3; radius: 1.5
                                color: Theme.ink
                                Behavior on y { NumberAnimation { duration: 80 } }
                            }
                        }
                    }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    width: win.hovered ? implicitWidth : 0
                    clip: true
                    opacity: win.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }
                    Repeater {
                        model: [
                            { icon: Media.playing ? "pause" : "play", run: () => win.player?.togglePlaying() },
                            { icon: "next", run: () => win.player?.next() }
                        ]
                        delegate: Item {
                            id: ctl
                            required property var modelData
                            width: 22; height: 22
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: ctlTap.containsMouse ? Theme.washOn : "transparent"
                            }
                            Icon {
                                anchors.centerIn: parent
                                name: ctl.modelData.icon
                                size: 13
                                color: Theme.ink
                            }
                            MouseArea {
                                id: ctlTap
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ctl.modelData.run()
                            }
                        }
                    }
                }
            }

            // what's waiting: a jelly bell and the count, or a lone dot
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: win.count > 0 ? waiting.implicitWidth : 8
                height: 24
                Row {
                    id: waiting
                    anchors.verticalCenter: parent.verticalCenter
                    visible: win.count > 0
                    spacing: 5
                    Bell {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 11; height: 8
                        color: Shell.dnd ? Theme.glow2 : Theme.glow
                        glow: 0.7
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.count
                        size: 12
                        weight: Theme.weightStrong
                        font.features: { "tnum": 1 }
                    }
                }
                Item {
                    anchors.centerIn: parent
                    visible: win.count === 0
                    width: 4; height: 4
                    Glow { anchors.centerIn: parent; width: 14; height: 14; color: Shell.dnd ? Theme.glow2 : Theme.glow; opacity: 0.6 }
                    Rectangle { anchors.fill: parent; radius: 2; color: Theme.ink; opacity: 0.8 }
                }
            }
        }

        // ── a notification ──────────────────────────────────────────────
        Column {
            id: notes
            width: 340
            Repeater {
                model: win.note ? [win.note] : []
                delegate: NotificationCard {
                    id: card
                    required property var modelData
                    property string leaving: ""
                    notification: modelData
                    width: 340
                    held: hover.hovered
                    onExpired: { leaving = "done"; sink(); }
                    onDismissed: { leaving = "dismiss"; sink(); }
                    onSunk: leaving === "dismiss" ? Notifs.dismiss(modelData) : Notifs.done(modelData)
                }
            }
        }
        Label {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 16
            anchors.bottomMargin: 7
            visible: win.mode === "note" && Notifs.queue.length > 1
            text: `${Notifs.queue.length - 1} more`
            size: 11
            color: Theme.inkDim
        }

        // ── the drop-down ───────────────────────────────────────────────
        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 16
            contentHeight: panel.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            opacity: win.mode === "open" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }

            Column {
                id: panel
                width: 400 - 32
                spacing: 16

                Column {
                    width: parent.width
                    visible: !!Media.player
                    spacing: 14
                    MediaCard { width: parent.width }
                    Rectangle { width: parent.width; height: 1; color: Theme.line }
                }
                History { width: parent.width }
            }
        }
    }
}
