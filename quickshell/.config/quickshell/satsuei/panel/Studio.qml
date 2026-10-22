pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.center
import qs.common
import qs.plate
import qs.services
import qs.walls

// The Satsuei panel (the bar's seal): a 340 px drawer of glass down the left
// side, the control centre's twin. Top to bottom:
//   · 撮影 SATSUEI and what the plate and the pass are
//   · the pass's five effects, each with a line on what it does
//   · the time of day: the hour, its name, the day's light as a strip, a
//     slider that holds an hour, and Follow the clock
//   · the wallpaper on now, and Choose wallpaper… (the selector)
//   · the palette taken from it: accent, accent 2, glass and three plate
//     colours with their hex (a click copies)
//   · the light source: Pick on wallpaper (a crosshair; the click is written
//     with satsuei-wall light) and Hold to compare (the raw plate while held)
// Esc or a click outside closes it; Esc also drops the crosshair.
PanelWindow {
    id: win

    readonly property bool open: Shell.studioOpen
    readonly property bool picking: Shell.pickingLight

    screen: Hypr.focusedScreen
    visible: open || picking || drawer.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "satsuei-studio"
    WlrLayershell.keyboardFocus: picking ? WlrKeyboardFocus.Exclusive : open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onOpenChanged: if (open) { flick.contentY = 0; keys.forceActiveFocus(); }
    onPickingChanged: if (picking) keys.forceActiveFocus()

    function copy(hex) {
        Quickshell.execDetached(["wl-copy", hex]);
        Shell.toast("check", `Copied ${hex}`);
    }

    MouseArea {
        anchors.fill: parent
        enabled: !win.picking
        onClicked: Shell.studioOpen = false
    }
    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: {
            if (win.picking) Shell.pickingLight = false;
            else Shell.studioOpen = false;
        }
    }

    // ── picking the light: a crosshair over the plate, the click is it ─────
    Crosshair {
        anchors.fill: parent
        visible: win.picking
    }
    MouseArea {
        anchors.fill: parent
        enabled: win.picking
        visible: enabled
        cursorShape: Qt.CrossCursor
        onClicked: mouse => {
            Plates.pick(win.screen?.name ?? "", mouse.x, mouse.y);
            Shell.pickingLight = false;
        }
    }

    component Heading: Label {
        size: 11
        weight: Style.weightStrong
        spacing: 0.14
        color: Theme.fgDim
    }
    component Button: Btn {
        id: button
        property string text: ""
        property string icon: ""
        width: buttonRow.implicitWidth + 24
        height: 32
        radius: 11
        color: hovered || on ? Theme.at(Theme.fg, 0.16) : Theme.tile
        Row {
            id: buttonRow
            anchors.centerIn: parent
            spacing: 6
            Icon { visible: !!button.icon; anchors.verticalCenter: parent.verticalCenter; name: button.icon || "app"; size: 14 }
            Label { anchors.verticalCenter: parent.verticalCenter; text: button.text; size: 12; weight: Style.weightStrong }
        }
    }

    Item {
        id: drawer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.topMargin: 66                     // 10 + the bar's 46 + 10
        anchors.bottomMargin: 12
        anchors.leftMargin: 10
        width: 340

        opacity: win.open ? 1 : 0
        transform: Translate {
            x: win.open ? 0 : -drawer.width - 30
            Behavior on x {
                NumberAnimation {
                    duration: win.open ? 550 : Style.durPanelOut
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: win.open ? Style.bloom : Style.sink
                }
            }
        }
        Behavior on opacity { NumberAnimation { duration: 350 } }

        MouseArea { anchors.fill: parent }   // clicks inside stay inside

        Glass {
            anchors.fill: parent
            radius: 22

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: 18
                contentHeight: content.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: content
                    width: flick.width
                    spacing: 18

                    // ── what this is ───────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 6
                        Row {
                            spacing: 10
                            Label { display: true; size: 26; spacing: 0.02; text: "撮影" }
                            Label { anchors.baseline: parent.children[0].baseline; text: "SATSUEI"; size: 13; weight: Style.weightStrong; spacing: 0.06; color: Theme.fgDim }
                        }
                        Label {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            lineHeight: 1.3
                            size: 12.5
                            color: Theme.fgDim
                            text: "Your wallpaper is the background plate. These passes sit on top of it, the way an anime compositor adds light to a finished frame."
                        }
                    }

                    // ── the pass ───────────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 2
                        Heading { text: "COMPOSITING PASS"; bottomPadding: 6 }
                        Repeater {
                            model: [
                                { key: "bloom", name: "Diffusion bloom", what: "Highlights soften and glow" },
                                { key: "rays", name: "Light rays", what: "Shafts from the brightest point" },
                                { key: "motes", name: "Dust motes", what: "Specks drifting through the light" },
                                { key: "grain", name: "Film grain", what: "Fine moving texture" },
                                { key: "grade", name: "Time-of-day grade", what: "Colour follows the hour" }
                            ]
                            delegate: Btn {
                                id: fx
                                required property var modelData
                                readonly property bool lit: Settings.fx(modelData.key)
                                width: content.width
                                height: 50
                                radius: 12
                                color: hovered ? Theme.at(Theme.fg, 0.06) : "transparent"
                                onClicked: Settings.setFx(modelData.key, !lit)
                                Column {
                                    x: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 70
                                    Label { text: fx.modelData.name; size: 12.5; weight: Style.weightStrong }
                                    Label { text: fx.modelData.what; size: 11; color: Theme.fgDim }
                                }
                                Switch {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    on: fx.lit
                                    onToggled: Settings.setFx(fx.modelData.key, !fx.lit)
                                }
                            }
                        }
                    }

                    // ── the time of day ────────────────────────────────────
                    Rectangle {
                        width: parent.width
                        height: tod.implicitHeight + 24
                        radius: 14
                        color: Theme.well
                        Column {
                            id: tod
                            x: 12
                            y: 12
                            width: parent.width - 24
                            spacing: 6
                            Item {
                                width: parent.width
                                height: 30
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    display: true
                                    size: 22
                                    text: Theme.grade.fmt(Theme.grade.hour)
                                }
                                Label {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Theme.grade.phase
                                    size: 12.5
                                    weight: Style.weightStrong
                                    color: Theme.accent
                                }
                            }
                            // the day's light, midnight to midnight: the grade's own keys
                            Item {
                                id: day
                                width: parent.width
                                height: 6
                                Repeater {
                                    model: Theme.grade.keys.length - 1
                                    delegate: Rectangle {
                                        id: seg
                                        required property int index
                                        readonly property real a: Theme.grade.keys[index][0]
                                        readonly property real b: Theme.grade.keys[index + 1][0]
                                        x: seg.a / 24 * day.width
                                        width: (seg.b - seg.a) / 24 * day.width + 0.5
                                        height: day.height
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0; color: win.lightAt(seg.a) }
                                            GradientStop { position: 1; color: win.lightAt(seg.b) }
                                        }
                                    }
                                }
                                // now
                                Rectangle {
                                    x: Theme.grade.hour / 24 * parent.width - 1
                                    y: -3
                                    width: 2; height: 12; radius: 1
                                    color: Theme.fg
                                }
                            }
                            Slider {
                                width: parent.width
                                icon: Settings.s.follow ? "sun" : "sunset"
                                from: 0
                                to: 24
                                value: Theme.grade.hour
                                onMoved: v => { Settings.s.follow = false; Settings.s.hour = v; }
                            }
                            Check {
                                x: -8
                                text: "Follow the clock"
                                checked: Settings.s.follow
                                onToggled: Settings.s.follow = !Settings.s.follow
                            }
                        }
                    }

                    // ── the wallpaper ──────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 8
                        Heading { text: "WALLPAPER" }
                        Row {
                            width: parent.width
                            spacing: 12
                            Rectangle {
                                width: 132
                                height: 80
                                radius: 11
                                color: Theme.well
                                clip: true
                                border.width: 2
                                border.color: Theme.accent
                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: win.visible ? Theme.plate : ""
                                    sourceSize.width: 264
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }
                            Column {
                                width: parent.width - 144
                                spacing: 8
                                Label {
                                    width: parent.width
                                    elide: Text.ElideMiddle
                                    text: Theme.plateName || "the seed plate"
                                    size: 12
                                    weight: Style.weightStrong
                                }
                                Label {
                                    text: `${Theme.plateSize.width} × ${Theme.plateSize.height}` + (Theme.animated ? " · animated" : "")
                                    mono: true
                                    size: 10.5
                                    color: Theme.fgDim
                                }
                                Button {
                                    icon: "image"
                                    text: "Choose wallpaper…"
                                    onClicked: Shell.toggleWalls()
                                }
                            }
                        }
                    }

                    // ── the palette ────────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 8
                        Heading { text: "PALETTE FROM WALLPAPER" }
                        Grid {
                            id: pal
                            width: parent.width
                            columns: 3
                            rowSpacing: 10
                            columnSpacing: 8
                            Repeater {
                                model: [
                                    { name: "accent", c: Theme.accent }, { name: "accent 2", c: Theme.accent2 }, { name: "glass", c: Theme.tint },
                                    { name: "plate", c: Theme.swatches[0] ?? Theme.ink }, { name: "plate", c: Theme.swatches[1] ?? Theme.ink },
                                    { name: "plate", c: Theme.swatches[2] ?? Theme.ink }
                                ]
                                delegate: Column {
                                    id: swatch
                                    required property var modelData
                                    readonly property string hex: String(Qt.color(modelData.c)).slice(0, 7)
                                    width: (pal.width - 16) / 3
                                    spacing: 3
                                    Rectangle {
                                        width: parent.width
                                        height: 38
                                        radius: 10
                                        color: swatch.modelData.c
                                        border.width: 1
                                        border.color: Theme.rim
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.copy(swatch.hex)
                                        }
                                    }
                                    Label { text: swatch.modelData.name; size: 11; weight: Style.weightStrong }
                                    Label { text: swatch.hex; mono: true; size: 10; color: Theme.fgDim }
                                }
                            }
                        }
                    }

                    // ── the light source ───────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 8
                        Heading { text: "LIGHT SOURCE" }
                        Label {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            size: 11.5
                            color: Theme.fgDim
                            text: "Found automatically from the brightest area. Pick it yourself if the rays come from the wrong place."
                        }
                        Row {
                            spacing: 8
                            Button {
                                icon: "crosshair"
                                text: "Pick on wallpaper"
                                onClicked: {
                                    Shell.studioOpen = false;
                                    Shell.pickingLight = true;
                                }
                            }
                            Button {
                                icon: "eye"
                                text: "Hold to compare"
                                on: Shell.comparing
                                // held, not clicked: the raw plate while the button is down
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: Shell.comparing = true
                                    onReleased: Shell.comparing = false
                                    onCanceled: Shell.comparing = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // the grade's light at an hour, for the strip
    function lightAt(h) {
        const c = Theme.grade.sample(h).rayCol, m = Theme.grade.sample(h).mul;
        const k = Math.min(1, (m[0] + m[1] + m[2]) / 3);
        return Qt.rgba(c[0] * k, c[1] * k, c[2] * k, 1);
    }
}
