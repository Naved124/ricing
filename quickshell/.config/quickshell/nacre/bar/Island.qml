pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.center
import qs.common
import qs.notifs
import qs.services

// The island: a pill of pearl glass over the middle of the bar, on its own
// layer so it can grow. It always starts with the time (hover for the date,
// click it for the calendar) and ends with the notifications waiting in the
// history (a bell and their count, or a single pearl when there are none).
//   · something playing: the cover, the track (scrolling past when it is
//     long) and a small visualizer in between, the pill ringed with the
//     orient and glowing with it like a focused window, the glow breathing
//     with the beat (Beat.level); hover brings out play/pause and next
//   · a notification: the pill grows into its card for 4 s (hover holds
//     it), with its actions, × to dismiss it, or swipe it away
//   · a click: it grows into the drop-down, what's playing on top and the
//     notification history below with "Clear all"; Esc or a click outside
//     shrinks it back
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

    // the bar's pill is 38 tall, 12 from the top; the island sits in it
    readonly property int top: 16
    readonly property int pillHeight: 30
    readonly property var spring: Theme.settle

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nacre-island"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // only the island takes clicks; open, the whole screen does (to close it)
    mask: Region { item: win.open ? catcher : win.shown ? island : null }

    onOpenChanged: {
        if (!open) return;
        Notifs.seen();
        flick.contentY = 0;
        keys.forceActiveFocus();
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
                                        : win.mode === "note" ? 380
                                        : pill.implicitWidth + 16
        readonly property real wantHeight: win.mode === "open" ? Math.min(panel.implicitHeight + 32, win.height - win.top - 60)
                                         : win.mode === "note" ? notes.height
                                         : win.pillHeight
        readonly property real radius: win.mode === "open" ? Theme.radiusPanel + 6
                                     : win.mode === "note" ? Theme.radiusPopup + 6
                                     : win.pillHeight / 2

        x: Math.round((win.width - width) / 2)
        y: win.top
        width: Math.round(wantWidth)
        height: Math.round(wantHeight)
        opacity: win.shown ? 1 : 0
        visible: opacity > 0
        Behavior on width { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: win.spring } }
        Behavior on height { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: win.spring } }
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }

        HoverHandler { id: hover }

        // the glow: the orient, blurred, behind the pill; stronger on the beat
        Item {
            id: glow
            anchors.fill: parent
            anchors.margins: -3
            opacity: win.playing && win.mode === "pill" ? 0.22 + 0.55 * Beat.level : 0
            scale: 1 + 0.035 * Beat.level
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 120 } }
            layer.enabled: visible
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: 28
                autoPaddingEnabled: true
            }
            Iridescent {
                anchors.fill: parent
                radius: island.radius + 3
                period: 9000
                sheen: 0
                spinning: win.playing
            }
        }

        Glass {
            anchors.fill: parent
            radius: island.radius
            fill: win.mode === "pill" && !win.playing ? Theme.glassSoft : Theme.glassStrong
            shadowBlur: 0.7
            Behavior on radius { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: win.spring } }
        }
        // the rim: the orient running round the island, as on a focused window
        Iridescent {
            anchors.fill: parent
            radius: island.radius
            ring: 1.5
            period: 9000
            sheen: 0.25
            opacity: win.mode === "pill" ? (win.playing ? 0.6 + 0.4 * Beat.level : 0) : win.mode === "note" ? 0.55 : 0.3
            visible: opacity > 0.01
            spinning: win.playing || win.mode !== "pill"
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        // ── the pill ────────────────────────────────────────────────────
        // a click on the pill opens the drop-down (its buttons take their own)
        MouseArea {
            anchors.fill: parent
            enabled: win.mode === "pill"
            cursorShape: Qt.PointingHandCursor
            onClicked: Shell.toggleIsland(win.screen?.name)
        }

        Row {
            id: pill
            x: 8
            height: win.pillHeight
            spacing: 10
            opacity: win.mode === "pill" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }

            // the time; hover shows the date, a click the calendar
            Item {
                id: time
                anchors.verticalCenter: parent.verticalCenter
                width: timeRow.implicitWidth + 8
                height: 26
                HoverHandler { id: timeHover }
                Row {
                    id: timeRow
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: timeHover.hovered ? date.implicitWidth : 0
                        height: date.implicitHeight
                        clip: true
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: win.spring } }
                        Label {
                            id: date
                            text: Qt.formatDate(clock.date, "ddd d MMM")
                            color: Theme.inkSoft
                            size: Theme.uiSize + 1
                        }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatTime(clock.date, "HH:mm")
                        size: Theme.uiSize + 3
                        weight: Theme.weightStrong
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Shell.toggleCenter("calendar")
                }
                SystemClock { id: clock; precision: SystemClock.Minutes }
            }

            // something playing: cover, track, the bars; hover adds the controls
            Row {
                id: media
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9
                visible: win.playing

                ClippingRectangle {
                    width: 22; height: 22
                    radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.shell
                    Image {
                        anchors.fill: parent
                        source: win.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(44, 44)
                        asynchronous: true
                    }
                    Rectangle {               // 92% brightness at night
                        anchors.fill: parent
                        color: Theme.imageShade
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
                    width: Math.round(Math.min(contentWidth, win.hovered ? 260 : 220))
                    height: 26
                    delegate: Label {
                        text: track.text
                        size: Theme.uiSize + 1
                        color: Theme.ink
                    }
                }

                Bars {
                    anchors.verticalCenter: parent.verticalCenter
                }

                // hover: play/pause and next
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
                            width: 24; height: 24
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: ctlTap.containsMouse ? Theme.glassSoft : "transparent"
                            }
                            Icon {
                                anchors.centerIn: parent
                                name: ctl.modelData.icon
                                size: 15
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

            // what's waiting: a bell and the count, or a lone pearl
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: win.count > 0 ? bell.implicitWidth : 10
                height: 26
                Row {
                    id: bell
                    anchors.verticalCenter: parent.verticalCenter
                    visible: win.count > 0
                    spacing: 4
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Shell.dnd ? "bell-off" : "bell"
                        size: 14
                        color: Theme.ink
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.count
                        size: Theme.uiSize
                        weight: Theme.weightStrong
                    }
                }
                Pearl {
                    anchors.centerIn: parent
                    visible: win.count === 0
                    width: 8; height: 8
                    gloss: 0.8
                    iri: Shell.dnd ? 0 : 0.4
                }
            }
        }

        // ── a notification ──────────────────────────────────────────────
        Column {
            id: notes
            width: 380
            Repeater {
                model: win.note ? [win.note] : []
                delegate: NotificationCard {
                    required property var modelData
                    notification: modelData
                    width: 380
                    held: hover.hovered
                    opacity: win.mode === "note" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }
                    onExpired: Notifs.done(modelData)
                    onDismissed: Notifs.dismiss(modelData)
                }
            }
        }
        Label {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 16
            anchors.bottomMargin: 8
            visible: win.mode === "note" && Notifs.queue.length > 1
            text: `${Notifs.queue.length - 1} more`
            size: Theme.uiSize - 1
            color: Theme.inkSoft
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
                    spacing: 12
                    MediaCard {
                        width: parent.width
                        artSize: 72
                    }
                    Bars {
                        anchors.horizontalCenter: parent.horizontalCenter
                        count: 24
                        tall: 30
                        thick: (parent.width - 23 * 2) / 24
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.hairline }
                }

                History {
                    width: parent.width
                }
            }
        }
    }

    // a few bars of the music, walking along the gradient
    component Bars: Row {
        id: bars
        property int count: 7
        property real tall: 14
        property real thick: 3
        spacing: 2
        height: tall
        Repeater {
            model: bars.count
            delegate: Rectangle {
                required property int index
                readonly property int band: Math.floor(index * Beat.bars / bars.count)
                readonly property real level: Beat.levels[band] ?? 0
                anchors.bottom: parent.bottom
                width: bars.thick
                height: Math.max(bars.thick, bars.tall * level)
                radius: width / 2
                color: Theme.gradient[Math.floor(index / Math.max(1, bars.count - 1) * (Theme.gradient.length - 1))]
                Behavior on height { NumberAnimation { duration: 60 } }
            }
        }
    }
}
