pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs

// The rice chooser (Super+Shift+T): every rice as a card, dressed in the active
// rice's colours. Arrows/hjkl move, Enter applies, 1–9 pick directly, `a`
// toggles auto mode (light and dark by the sun), `d` light and dark, Esc or a
// click outside closes. Cards show their rice in the current mode, crossfading
// with it, and a sun or moon in the corner says which mode it opens in; the
// footer's pill is light · dark · auto, with the next switch. A rice with one
// mode (meta.fixed_mode, Abyss) wears it on its card and gets no sun or moon.
// A rice can draw its own card: rices/<name>/card.qml. It receives `rice`,
// `selected` and `active` like GenericCard.qml, plus `base` (GenericCard's
// URL) and `mode` ("light" or "dark") if it declares them. `rice.meta`'s
// colors, roles and gradient are the current mode's, mixed live.
PanelWindow {
    id: win

    property bool open: false
    property string selected: ""
    readonly property var names: Rices.list.map(r => r.name)
    readonly property string fontUi: Rices.active?.meta?.fonts?.ui ?? "sans-serif"
    readonly property string fontDisplay: Rices.active?.meta?.fonts?.display ?? fontUi

    function toggle() {
        if (open) { open = false; return; }
        Rices.refresh();
        selected = Rices.current || names[0] || "";
        open = true;
    }

    // a rice with its meta's colours, roles and gradient mixed between its two
    // modes by Theme.k, so a card follows `rice mode` as the shells do
    function dressed(r) {
        const ms = r?.meta?.modes;
        if (!ms?.light || !ms?.dark) return r;
        const k = Theme.k;
        const mixMap = (a, b) => {
            const out = {};
            for (const key of Object.keys(Object.assign({}, a, b)))
                out[key] = Theme.mode.mix(a[key] ?? b[key], b[key] ?? a[key], k);
            return out;
        };
        const meta = Object.assign({}, r.meta, {
            colors: mixMap(ms.light.colors ?? {}, ms.dark.colors ?? {}),
            roles: mixMap(ms.light.roles ?? {}, ms.dark.roles ?? {}),
            gradient: (ms.light.gradient ?? []).map((c, i) => Theme.mode.mix(c, ms.dark.gradient?.[i] ?? c, k)),
        });
        return Object.assign({}, r, { meta: meta });
    }

    function move(step) {
        if (!names.length) return;
        const i = names.indexOf(selected);
        selected = names[(i + step + names.length) % names.length];
    }

    function apply(name) {
        if (!name) return;
        open = false;
        // let the chooser unmap before `rice` screenshots the screen
        applyTimer.target = name;
        applyTimer.restart();
    }
    Timer {
        id: applyTimer
        property string target: ""
        interval: 180
        onTriggered: Rices.apply(target)
    }

    screen: {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }
    visible: open || veil.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-chooser"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: if (open) keys.forceActiveFocus()

    Rectangle {
        id: veil
        anchors.fill: parent
        color: Qt.alpha(Theme.role("bg"), 0.55)
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.open ? 320 : 220; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked: win.open = false
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Escape || k === Qt.Key_Q) win.open = false;
            else if ([Qt.Key_Left, Qt.Key_Up, Qt.Key_H, Qt.Key_K, Qt.Key_Backtab].includes(k)) win.move(-1);
            else if ([Qt.Key_Right, Qt.Key_Down, Qt.Key_L, Qt.Key_J, Qt.Key_Tab].includes(k)) win.move(1);
            else if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(k)) win.apply(win.selected);
            else if (k === Qt.Key_A) Rices.setAuto(!Rices.auto);
            else if (k === Qt.Key_D) Rices.setMode(Theme.dark ? "light" : "dark");
            else if (k >= Qt.Key_1 && k <= Qt.Key_9 && win.names[k - Qt.Key_1]) win.apply(win.names[k - Qt.Key_1]);
            else return;
            event.accepted = true;
        }
    }

    // clicks between the cards stay inside
    MouseArea {
        x: content.x
        y: content.y
        width: content.width
        height: content.height
        enabled: win.open
    }

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 28
        opacity: veil.opacity
        scale: win.open ? 1 : 0.97
        Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

        Text {
            text: "choose a rice"
            color: Theme.role("fg")
            font.family: win.fontDisplay
            font.weight: Rices.active?.meta?.fonts?.display_weight ?? Font.Normal
            font.pixelSize: 35
        }

        Row {
            spacing: 28

            Repeater {
                model: Rices.list

                delegate: Item {
                    id: slot

                    required property var modelData
                    required property int index
                    readonly property bool isSelected: win.selected === modelData.name

                    width: 300
                    height: 300
                    scale: isSelected ? 1.04 : 1
                    z: isSelected ? 1 : 0
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

                    // rise in one after another
                    opacity: win.open ? 1 : 0
                    property real rise: win.open ? 0 : 20
                    transform: Translate { y: slot.rise }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: win.open ? slot.index * 40 : 0 } NumberAnimation { duration: 280 } } }
                    Behavior on rise { SequentialAnimation { PauseAnimation { duration: win.open ? slot.index * 40 : 0 } NumberAnimation { duration: 380; easing.type: Easing.OutCubic } } }

                    Loader {
                        id: loader
                        anchors.fill: parent
                        source: slot.modelData.card ? `file://${Rices.dir}/${slot.modelData.name}/card.qml` : "GenericCard.qml"
                        // a card.qml that fails to load falls back to the generic one
                        onStatusChanged: if (status === Loader.Error) source = "GenericCard.qml"
                    }
                    Binding { target: loader.item; property: "rice"; value: win.dressed(slot.modelData); when: loader.status === Loader.Ready }
                    Binding { target: loader.item; property: "selected"; value: slot.isSelected; when: loader.status === Loader.Ready }
                    Binding { target: loader.item; property: "active"; value: slot.modelData.name === Rices.current; when: loader.status === Loader.Ready }
                    Binding { target: loader.item; property: "base"; value: Qt.resolvedUrl("GenericCard.qml"); when: loader.status === Loader.Ready && loader.item.hasOwnProperty("base") }
                    Binding { target: loader.item; property: "mode"; value: slot.modelData.meta?.fixed_mode ?? (Theme.dark ? "dark" : "light"); when: loader.status === Loader.Ready && loader.item.hasOwnProperty("mode") }

                    // the mode it opens in: a sun or a moon in the corner
                    // (none for a rice that only has one)
                    Rectangle {
                        visible: !slot.modelData.meta?.fixed_mode
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6
                        width: 28
                        height: 28
                        radius: 14
                        z: 2
                        color: Theme.role("surface")
                        border.color: Theme.role("border")
                        SunMoon {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            moon: Theme.dark
                            color: Theme.role("fg")
                        }
                    }

                    // the number key that picks it
                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.bottom
                        anchors.topMargin: 8
                        text: slot.index < 9 ? String(slot.index + 1) : ""
                        color: Theme.role("muted")
                        font.family: win.fontUi
                        font.weight: Font.DemiBold
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.selected = slot.modelData.name
                        onClicked: win.apply(slot.modelData.name)
                    }
                }
            }
        }

        // auto mode and the key hints
        Item {
            width: parent.width
            height: 40

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                // light · dark · auto, in the active rice's colours
                Rectangle {
                    id: pill
                    readonly property string current: Rices.auto ? "auto" : Theme.dark ? "dark" : "light"
                    anchors.verticalCenter: parent.verticalCenter
                    width: segments.width + 6
                    height: 30
                    radius: 15
                    color: Theme.role("surface")
                    border.color: Theme.role("border")
                    Row {
                        id: segments
                        x: 3
                        anchors.verticalCenter: parent.verticalCenter
                        Repeater {
                            model: ["light", "dark", "auto"]
                            delegate: Rectangle {
                                id: seg
                                required property string modelData
                                readonly property bool on: pill.current === modelData
                                width: label.implicitWidth + 24
                                height: 24
                                radius: 12
                                // the selection role is made to carry fg text
                                color: on ? Theme.role("selection") : "transparent"
                                border.color: on ? Theme.role("accent") : "transparent"
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Text {
                                    id: label
                                    anchors.centerIn: parent
                                    text: seg.modelData
                                    color: Theme.role("fg")
                                    font.family: win.fontUi
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Rices.setMode(seg.modelData)
                                }
                            }
                        }
                    }
                }
                // when it next changes
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text.length > 0
                    text: Rices.next
                    color: Theme.role("muted")
                    font.family: win.fontUi
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "←→ move   ↵ apply   1–9 pick   d dark   a auto   esc close"
                color: Theme.role("muted")
                font.family: win.fontUi
                font.weight: Font.DemiBold
                font.pixelSize: 13
            }
        }
    }
}
