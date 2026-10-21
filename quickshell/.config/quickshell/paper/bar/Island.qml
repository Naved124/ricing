pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Widgets
import qs.center
import qs.common
import qs.notes
import qs.services

// The island: a small tab of paper laid over the middle of the bar, on its
// own layer so it can unfold. It always starts with the time in red Kalam
// (hover for the date, click it for the month card) and ends with the notes
// waiting in the history, pencilled ("3 notes", or a dot when there are
// none).
//   · something playing: the cover pinned on like a photo, the track typed
//     (sliding past when it is long), the artist pencilled and a few ink
//     strokes dancing to the sound; under the tab the desk lamp's warmth
//     (the highlighter's yellow by day, the lamp's straw at night,
//     Theme.warmth) swells with the beat (Beat.level); hover slides it wider
//     for ⏸ and ⏭
//   · a notification: the tab unfolds into a sticky note for 4 s (hover
//     holds it; a pencil line runs down the time): yellow, mint when low,
//     pink when critical, black card with a coloured strip at night. "peel"
//     or a swipe dismisses it; a click runs its default action
//   · a click: it unfolds into an index card, what's playing on top and the
//     notes that came in below, with "clear desk"; Esc or a click outside
//     folds it back
// Notes show on the focused monitor; while a window is fullscreen only
// they do.
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

    // the note's colour: by urgency, and black card with a strip at night
    readonly property bool critical: note?.urgency === NotificationUrgency.Critical
    readonly property bool low: note?.urgency === NotificationUrgency.Low
    readonly property color noteColour: critical ? Theme.pink : low ? Theme.mint : Theme.sticky
    readonly property color noteBody: Theme.mode.mix(noteColour, Theme.card)

    // the strip is 44 tall from y 10, its rule 10 above the bottom; the tab
    // sits in the space above the rule
    readonly property int top: 13
    readonly property int pillHeight: 32

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "paper-island"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // only the tab takes clicks; open, the whole screen does (to close it)
    mask: Region { item: win.open ? catcher : win.shown ? tab : null }

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
        id: tab

        readonly property real wantWidth: win.mode === "open" ? 420
                                        : win.mode === "note" ? 340
                                        : pill.implicitWidth + 28
        readonly property real wantHeight: win.mode === "open" ? Math.min(panel.implicitHeight + 36, win.height - win.top - 60)
                                         : win.mode === "note" ? noteBox.implicitHeight + 40
                                         : win.pillHeight

        x: Math.round((win.width - width) / 2)
        y: win.top
        width: Math.round(wantWidth)
        height: Math.round(wantHeight)
        opacity: win.shown ? 1 : 0
        visible: opacity > 0
        Behavior on width { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drop } }
        Behavior on height { NumberAnimation { duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drop } }
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }

        HoverHandler { id: hover }

        // the lamp's warmth under the tab, swelling with the beat
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: 14
            color: Theme.warmth
            opacity: win.playing && win.mode === "pill" ? Theme.mode.blend(0.35, 0.25) + Theme.mode.blend(0.65, 0.5) * Beat.level : 0
            scale: 1 + 0.05 * Beat.level
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 120 } }
            layer.enabled: visible
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: 24
                autoPaddingEnabled: true
            }
        }

        Sheet {
            id: sheet
            anchors.fill: parent
            fill: win.mode === "note" ? win.noteBody : win.mode === "open" ? Theme.card : Theme.paper
            seed: 31
            tilt: win.mode === "note" ? 0 : win.mode === "open" ? 0.3 : win.hovered ? 0 : 0.6
            lifted: win.mode !== "pill" || win.hovered
            Behavior on tilt { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drop } }
            Behavior on fill { ColorAnimation { duration: Theme.durFocus } }
        }

        // ── the tab ─────────────────────────────────────────────────────
        // a click on the tab opens the card (its words take their own)
        MouseArea {
            anchors.fill: parent
            enabled: win.mode === "pill"
            cursorShape: Qt.PointingHandCursor
            onClicked: Shell.toggleIsland(win.screen?.name)
        }

        Row {
            id: pill
            x: 14
            height: win.pillHeight
            spacing: 12
            opacity: win.mode === "pill" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }

            // the time in red; hover pencils in the date, a click the month
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: timeRow.implicitWidth
                height: win.pillHeight
                HoverHandler { id: timeHover }
                Row {
                    id: timeRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: timeHover.hovered ? date.implicitWidth : 0
                        height: date.implicitHeight
                        clip: true
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drop } }
                        Hand {
                            id: date
                            text: Qt.formatDate(clock.date, "ddd d MMM")
                            size: 17
                            color: Theme.pencil
                        }
                    }
                    Hand {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatTime(clock.date, "h:mm ap")
                        size: 21
                        color: Theme.red
                        font.features: { "tnum": 1 }
                    }
                }
                SystemClock { id: clock; precision: SystemClock.Minutes }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const peek = !Shell.calendarPeek;
                        Shell.closeAll();
                        Shell.calendarPeek = peek;
                    }
                }
            }

            // something playing
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9
                visible: win.playing

                // the cover, as a small photo in a card border
                Rectangle {
                    width: 24; height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.card
                    border.color: Theme.rule
                    rotation: -3
                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        color: Theme.kraft
                        Image {
                            anchors.fill: parent
                            source: win.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(40, 40)
                            asynchronous: true
                        }
                        Rectangle {           // 92% brightness under the lamp
                            anchors.fill: parent
                            color: Theme.imageShade
                        }
                    }
                }

                Marquee {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(Math.min(contentWidth, win.hovered ? 240 : 190))
                    height: 26
                    delegate: Type {
                        text: win.player?.trackTitle ?? ""
                        size: 13
                        weight: 700
                    }
                }
                Hand {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text.length > 0
                    width: Math.min(implicitWidth, 120)
                    text: win.player?.trackArtist ?? ""
                    size: 15
                    elide: Text.ElideRight
                }

                // ink strokes dancing to the sound
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 16
                    spacing: 2
                    Repeater {
                        model: 7
                        delegate: Rectangle {
                            required property int index
                            readonly property real level: Beat.levels[Math.floor(index * Beat.bars / 7)] ?? 0
                            anchors.bottom: parent.bottom
                            width: 2.5
                            height: Math.max(2.5, 16 * level)
                            radius: 1.25
                            color: index === 0 ? Theme.red : Theme.ink
                            Behavior on height { NumberAnimation { duration: 60 } }
                        }
                    }
                }

                // hover: ⏸ and ⏭, written in Kalam
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    width: win.hovered ? implicitWidth : 0
                    clip: true
                    opacity: win.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }
                    Repeater {
                        model: [
                            { t: Media.playing ? "⏸" : "▶", run: () => win.player?.togglePlaying() },
                            { t: "⏭", run: () => win.player?.next() }
                        ]
                        delegate: Hand {
                            id: ctl
                            required property var modelData
                            text: modelData.t
                            size: 18
                            weight: 700
                            color: ctlTap.containsMouse ? Theme.red : Theme.ink
                            MouseArea {
                                id: ctlTap
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ctl.modelData.run()
                            }
                        }
                    }
                }
            }

            // the notes waiting, pencilled, or a dot
            Hand {
                anchors.verticalCenter: parent.verticalCenter
                text: win.count > 0 ? `${win.count} note${win.count === 1 ? "" : "s"}` : "·"
                size: win.count > 0 ? 16 : 22
                color: Shell.dnd ? Theme.graphite : Theme.pencil
            }
        }

        // ── a notification, as a sticky note ────────────────────────────
        Item {
            id: noteView
            anchors.fill: parent
            opacity: win.mode === "note" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }

            // the adhesive band: a faint shade by day, the note's colour at night
            Rectangle {
                width: parent.width
                height: 14
                color: Theme.mode.mix(Qt.alpha(Theme.soot, 0.05), win.noteColour)
            }

            Column {
                id: noteBox
                x: 18 + swipe.translation.x
                y: 22
                width: parent.width - 36
                spacing: 4
                opacity: 1 - Math.min(1, Math.abs(swipe.translation.x) / 200)

                Item {
                    width: parent.width
                    height: summary.implicitHeight
                    Hand {
                        id: summary
                        width: parent.width - peel.width - 8
                        text: win.note?.summary || win.note?.appName || ""
                        size: 17
                        weight: 700
                        color: Theme.mode.mix(Theme.felt, Theme.ink)    // gel-blue at night
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    Hand {
                        id: peel
                        anchors.right: parent.right
                        text: "peel ×"
                        size: 15
                        color: Theme.red
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.dismiss(win.note)
                        }
                    }
                }
                Hand {
                    width: parent.width
                    visible: text.length > 0
                    text: win.note?.body ?? ""
                    size: 16
                    color: Theme.felt
                    lineHeight: 0.95
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }
                // actions: underlined words
                Flow {
                    width: parent.width
                    spacing: 12
                    visible: actions.count > 0
                    Repeater {
                        id: actions
                        model: (win.note?.actions ?? []).filter(a => a.identifier !== "default" || a.text)
                        delegate: Hand {
                            required property var modelData
                            text: modelData.text || "open"
                            size: 15
                            color: Theme.ink
                            font.underline: true
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -3
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { parent.modelData.invoke(); Notifs.dismiss(win.note); }
                            }
                        }
                    }
                }
                Hand {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    text: (win.note?.appName ?? "") + (Notifs.queue.length > 1 ? `  ·  ${Notifs.queue.length - 1} more` : "")
                    size: 13
                    color: Theme.felt
                    opacity: 0.55
                }
            }

            // its time on the note: a pencil line that runs down, held on hover
            Rectangle {
                id: drain
                property real remaining: 1
                x: 18
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                width: (parent.width - 36) * remaining
                height: 1.5
                radius: 1
                color: Theme.graphite
            }
            NumberAnimation {
                id: time
                target: drain
                property: "remaining"
                from: 1
                to: 0
                duration: Notifs.lifetime
                paused: running && (hover.hovered || swipe.active)
                onFinished: if (win.note) Notifs.done(win.note)
            }

            // a click on the note: its default action, then it's done
            TapHandler {
                onTapped: {
                    const n = win.note;
                    const def = (n?.actions ?? []).find(a => a.identifier === "default");
                    if (def) def.invoke();
                    if (n) Notifs.dismiss(n);
                }
            }
            // swipe it off sideways
            DragHandler {
                id: swipe
                target: null
                yAxis.enabled: false
                onActiveChanged: if (!active && Math.abs(translation.x) > 110 && win.note) Notifs.dismiss(win.note)
            }
        }
        // a new note: its time starts over
        Connections {
            target: win
            function onNoteChanged() {
                time.stop();
                drain.remaining = 1;
                if (win.note) time.start();
            }
        }

        // ── the index card ──────────────────────────────────────────────
        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 18
            contentHeight: panel.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            opacity: win.mode === "open" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }

            Column {
                id: panel
                width: 420 - 36
                spacing: 12

                NowPlaying {
                    width: parent.width - 6
                    x: 3
                    visible: !!Media.player
                    active: win.open
                }

                // the notes that came in, smaller
                Item {
                    width: parent.width
                    height: 26
                    Hand {
                        text: win.count ? `${win.count} note${win.count === 1 ? "" : "s"}` : "no notes, a clear desk"
                        size: 17
                        color: Theme.pencil
                    }
                    Hand {
                        anchors.right: parent.right
                        visible: win.count > 0
                        text: "clear desk"
                        size: 16
                        color: Theme.red
                        font.underline: true
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.clearAll()
                        }
                    }
                }
                Flow {
                    width: parent.width
                    spacing: 12
                    Repeater {
                        model: Notifs.all.slice().reverse().slice(0, 12)
                        delegate: Item {
                            id: small
                            required property var modelData
                            width: 180
                            height: sticky.height * 0.96
                            Sticky {
                                id: sticky
                                notification: small.modelData
                                width: 186
                                scale: 0.96
                                transformOrigin: Item.TopLeft
                            }
                        }
                    }
                }
            }
        }
    }
}
