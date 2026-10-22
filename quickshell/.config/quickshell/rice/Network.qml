pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs

// The network widget, the same in every rice and dressed in the active one
// (its roles, fonts and panel corners, mixed by the mode like the chooser):
// opened from a rice's control centre (right-click or double-click its Wi-Fi
// tile) or `qs -c rice ipc call network open`. Top to bottom:
//   · Wi-Fi on or off, and rescan
//   · what you're on: its address and gateway, Disconnect, and its DNS
//     (the network's own, or servers of your choosing: Cloudflare, Google,
//     Quad9 or any list)
//   · the networks around, strongest first: a click joins a saved or open
//     one, or asks for the password (shown on request) and keeps it
//   · a hidden network by name
//   · saved networks: join automatically or not, show the password, forget
// Esc or a click outside closes it. The work is Wifi.qml's (nmcli).
PanelWindow {
    id: win

    property bool open: false
    property string asking: ""             // the network whose password is being typed
    property bool showDetails: false
    property bool showSaved: false
    property bool showHidden: false

    function toggle() { open = !open; }

    readonly property var meta: Rices.active?.meta ?? ({})
    readonly property string fontUi: meta.fonts?.ui ?? "sans-serif"
    readonly property string fontDisplay: meta.fonts?.display ?? fontUi
    readonly property string fontMono: meta.fonts?.mono ?? "monospace"
    readonly property real uiSize: meta.fonts?.ui_size ?? 14
    readonly property int strong: meta.fonts?.weight_strong ?? 700
    readonly property real radius: meta.shape?.panel ?? 14
    readonly property real chip: meta.shape?.chip ?? 8
    function role(n) { return Theme.role(n); }
    // text on a fill: fg, or bg where fg would be too faint on it
    function on(fill) {
        const l = c => { const x = Qt.color(c); return 0.2126 * x.r + 0.7152 * x.g + 0.0722 * x.b; };
        const f = role("fg"), b = role("bg"), y = l(fill);
        return Math.abs(l(f) - y) >= Math.abs(l(b) - y) ? f : b;
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
    WlrLayershell.namespace: "rice-network"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        Wifi.watching = open;
        if (open) { asking = ""; Rices.refresh(); keys.forceActiveFocus(); }
    }

    Rectangle {
        id: veil
        anchors.fill: parent
        color: Qt.alpha(win.role("bg"), 0.45)
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.open ? 280 : 200; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: win.open = false }
    }
    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: {
            if (win.asking) win.asking = "";
            else win.open = false;
        }
    }

    // ── small parts ─────────────────────────────────────────────────────────
    component T: Text {
        property real size: win.uiSize
        property bool bold: false
        property bool dim: false
        color: dim ? win.role("muted") : win.role("fg")
        font.family: win.fontUi
        font.pixelSize: size
        font.weight: bold ? win.strong : (win.meta.fonts?.weight ?? 500)
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
    component Button: Rectangle {
        id: b
        property string text: ""
        property bool primary: false
        property bool danger: false
        property bool lit: false
        signal clicked()
        implicitWidth: bt.implicitWidth + 24
        implicitHeight: 30
        radius: win.chip
        color: primary ? win.role("accent") : lit ? win.role("selection")
             : bm.containsMouse ? Qt.alpha(win.role("fg"), 0.12) : Qt.alpha(win.role("fg"), 0.06)
        border.width: primary ? 0 : 1
        border.color: danger && bm.containsMouse ? win.role("urgent") : Qt.alpha(win.role("fg"), 0.12)
        T {
            id: bt
            anchors.centerIn: parent
            text: b.text
            size: win.uiSize - 1.5
            bold: true
            color: b.primary ? win.on(win.role("accent")) : b.danger && bm.containsMouse ? win.role("urgent") : win.role("fg")
        }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }
    component Switch: Rectangle {
        id: sw
        property bool on: false
        signal toggled()
        implicitWidth: 40
        implicitHeight: 22
        radius: 11
        color: on ? win.role("accent") : Qt.alpha(win.role("fg"), 0.18)
        Behavior on color { ColorAnimation { duration: 200 } }
        Rectangle {
            x: sw.on ? sw.width - width - 3 : 3
            y: 3
            width: 16; height: 16; radius: 8
            color: sw.on ? win.on(win.role("accent")) : win.role("fg")
            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
    }
    component Bars: Row {
        id: bars
        property real signal: 0          // 0–100
        property color ink: win.role("fg")
        spacing: 2
        height: 14
        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                y: bars.height - height
                width: 3
                height: 4 + index * 3.3
                radius: 1
                color: bars.signal > index * 25 ? bars.ink : Qt.alpha(bars.ink, 0.22)
            }
        }
    }
    component Field: Rectangle {
        id: fld
        property alias text: input.text
        property alias placeholder: input.placeholderText
        property bool secret: false
        property bool mono: false
        signal accepted()
        function focusIn() { input.forceActiveFocus(); }
        implicitHeight: 34
        radius: win.chip
        color: Qt.alpha(win.role("fg"), 0.06)
        border.width: 1
        border.color: input.activeFocus ? win.role("accent") : Qt.alpha(win.role("fg"), 0.14)
        TextField {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: fld.secret ? 52 : 10
            background: null
            verticalAlignment: Text.AlignVCenter
            echoMode: fld.secret && !peek.on ? TextInput.Password : TextInput.Normal
            color: win.role("fg")
            placeholderTextColor: win.role("muted")
            selectionColor: Qt.alpha(win.role("accent"), 0.35)
            selectedTextColor: win.role("fg")
            font.family: fld.mono ? win.fontMono : win.fontUi
            font.pixelSize: win.uiSize - 1
            onAccepted: fld.accepted()
            Keys.onEscapePressed: { if (win.asking) win.asking = ""; else win.open = false; }
        }
        T {
            id: peek
            property bool on: false
            visible: fld.secret
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: on ? "hide" : "show"
            size: win.uiSize - 3
            dim: true
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: peek.on = !peek.on }
        }
    }
    component Heading: T {
        size: win.uiSize - 3
        bold: true
        dim: true
        font.letterSpacing: 1.4
        font.capitalization: Font.AllUppercase
    }

    // ── the sheet ───────────────────────────────────────────────────────────
    Rectangle {
        id: sheet
        anchors.centerIn: parent
        width: 460
        height: Math.min(parent.height - 120, body.implicitHeight + 40)
        radius: win.radius
        color: win.role("surface")
        border.width: 1
        border.color: win.role("border")
        opacity: veil.opacity
        scale: win.open ? 1 : 0.97
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 20
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: flick.width
                spacing: 16

                // ── header ────────────────────────────────────────────────
                Item {
                    width: parent.width
                    height: 34
                    T {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Network"
                        font.family: win.fontDisplay
                        size: win.uiSize + 8
                        bold: true
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Button {
                            visible: Wifi.radio
                            text: Wifi.scanning ? "Scanning…" : "Rescan"
                            onClicked: Wifi.rescan()
                        }
                        T { height: 30; text: "Wi-Fi"; dim: true; size: win.uiSize - 1 }
                        Switch {
                            y: 4
                            on: Wifi.radio
                            onToggled: Wifi.setRadio(!Wifi.radio)
                        }
                    }
                }

                // what's going on, and what went wrong
                T {
                    visible: !!Wifi.busy || !!Wifi.error
                    width: parent.width
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    text: Wifi.busy ? Wifi.busy + "…" : Wifi.error
                    color: Wifi.busy ? win.role("accent") : win.role("urgent")
                    size: win.uiSize - 1.5
                }
                T {
                    visible: !!Wifi.wired
                    text: `Ethernet · ${Wifi.wired}`
                    dim: true
                    size: win.uiSize - 1.5
                }
                T {
                    visible: !Wifi.device && !Wifi.busy
                    text: "No Wi-Fi device (is NetworkManager running?)"
                    dim: true
                }

                // ── what you're on ────────────────────────────────────────
                Rectangle {
                    visible: !!Wifi.active
                    width: parent.width
                    height: now.implicitHeight + 24
                    radius: win.chip + 4
                    color: Qt.alpha(win.role("accent"), 0.12)
                    border.width: 1
                    border.color: Qt.alpha(win.role("accent"), 0.4)
                    Column {
                        id: now
                        x: 14; y: 12
                        width: parent.width - 28
                        spacing: 8
                        Item {
                            width: parent.width
                            height: 22
                            Bars {
                                anchors.verticalCenter: parent.verticalCenter
                                signal: Wifi.networks.find(n => n.inUse)?.signal ?? 0
                            }
                            T {
                                x: 26
                                width: parent.width - 26 - nowButtons.width - 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: Wifi.active?.name ?? ""
                                bold: true
                            }
                            Row {
                                id: nowButtons
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Button { text: win.showDetails ? "Less" : "Details"; lit: win.showDetails; onClicked: win.showDetails = !win.showDetails }
                                Button { text: "Disconnect"; danger: true; onClicked: Wifi.down(Wifi.active.uuid) }
                            }
                        }
                        T {
                            text: `Connected · ${(Wifi.active?.ip ?? "").split("/")[0] || "getting an address"}`
                            dim: true
                            size: win.uiSize - 1.5
                        }
                        // details and DNS
                        Column {
                            visible: win.showDetails
                            width: parent.width
                            spacing: 8
                            Grid {
                                columns: 2
                                columnSpacing: 14
                                rowSpacing: 4
                                T { text: "Address"; dim: true; size: win.uiSize - 2 }
                                T { text: Wifi.active?.ip ?? ""; font.family: win.fontMono; size: win.uiSize - 2 }
                                T { text: "Gateway"; dim: true; size: win.uiSize - 2 }
                                T { text: Wifi.active?.gateway || "—"; font.family: win.fontMono; size: win.uiSize - 2 }
                                T { text: "DNS"; dim: true; size: win.uiSize - 2 }
                                T { text: (Wifi.active?.dns ?? []).join("  ") || "—"; font.family: win.fontMono; size: win.uiSize - 2 }
                                T { text: "Device"; dim: true; size: win.uiSize - 2 }
                                T { text: Wifi.device; font.family: win.fontMono; size: win.uiSize - 2 }
                            }
                            Heading { text: "DNS servers"; topPadding: 4 }
                            Flow {
                                id: presets
                                width: parent.width
                                spacing: 6
                                readonly property var list: [
                                    { name: "Automatic", servers: "" },
                                    { name: "Cloudflare", servers: "1.1.1.1 1.0.0.1" },
                                    { name: "Google", servers: "8.8.8.8 8.8.4.4" },
                                    { name: "Quad9", servers: "9.9.9.9 149.112.112.112" }
                                ]
                                Repeater {
                                    model: presets.list
                                    delegate: Button {
                                        required property var modelData
                                        text: modelData.name
                                        lit: Wifi.active && (modelData.servers ? Wifi.active.manualDns === modelData.servers
                                                                               : Wifi.active.dnsAuto)
                                        onClicked: { dns.text = modelData.servers; Wifi.setDns(Wifi.active.uuid, modelData.servers); }
                                    }
                                }
                            }
                            Row {
                                width: parent.width
                                spacing: 6
                                Field {
                                    id: dns
                                    width: parent.width - dnsApply.width - 6
                                    mono: true
                                    placeholder: "servers, e.g. 1.1.1.1 9.9.9.9 (empty: automatic)"
                                    text: Wifi.active?.manualDns ?? ""
                                    onAccepted: Wifi.setDns(Wifi.active.uuid, text)
                                }
                                Button { id: dnsApply; implicitHeight: 34; text: "Apply"; primary: true; onClicked: Wifi.setDns(Wifi.active.uuid, dns.text) }
                            }
                        }
                    }
                }

                // ── around you ────────────────────────────────────────────
                Column {
                    visible: Wifi.radio && !!Wifi.device
                    width: parent.width
                    spacing: 4
                    Heading { text: "Networks"; bottomPadding: 4 }
                    T {
                        visible: !Wifi.networks.filter(n => !n.inUse).length
                        text: Wifi.scanning ? "Looking…" : "Nothing else in range"
                        dim: true
                        size: win.uiSize - 1.5
                    }
                    Repeater {
                        model: Wifi.networks.filter(n => !n.inUse)
                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            readonly property bool asking: win.asking === modelData.ssid
                            width: body.width
                            height: asking ? 92 : 40
                            radius: win.chip
                            color: rowMouse.containsMouse || asking ? Qt.alpha(win.role("fg"), 0.07) : "transparent"
                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            clip: true

                            MouseArea {
                                id: rowMouse
                                width: parent.width
                                height: 40
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const n = row.modelData;
                                    if (n.saved || !n.security) { Wifi.connect(n.ssid, ""); return; }
                                    win.asking = row.asking ? "" : n.ssid;
                                    if (win.asking) Qt.callLater(() => pass.focusIn());
                                }
                            }
                            Bars { x: 10; y: 13; signal: row.modelData.signal }
                            T {
                                x: 36
                                y: 0
                                height: 40
                                width: parent.width - 36 - tags.width - 16
                                text: row.modelData.ssid
                            }
                            Row {
                                id: tags
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                y: 0
                                height: 40
                                spacing: 8
                                T { visible: row.modelData.saved; text: "saved"; size: win.uiSize - 3; color: win.role("accent"); height: 40 }
                                T { text: row.modelData.security ? row.modelData.security.split(" ")[0] : "open"; size: win.uiSize - 3; dim: true; height: 40 }
                                T { text: Number(row.modelData.freq.split(" ")[0]) > 4000 ? "5G" : "2.4G"; size: win.uiSize - 3; dim: true; height: 40 }
                            }
                            // its password
                            Row {
                                visible: row.asking
                                x: 10
                                y: 46
                                width: parent.width - 20
                                spacing: 6
                                Field {
                                    id: pass
                                    width: parent.width - join.width - 6
                                    secret: true
                                    placeholder: "Password"
                                    onAccepted: { Wifi.connect(row.modelData.ssid, text); text = ""; win.asking = ""; }
                                }
                                Button {
                                    id: join
                                    implicitHeight: 34
                                    text: "Join"
                                    primary: true
                                    onClicked: { Wifi.connect(row.modelData.ssid, pass.text); pass.text = ""; win.asking = ""; }
                                }
                            }
                        }
                    }

                    // a hidden network
                    T {
                        topPadding: 6
                        text: win.showHidden ? "Hidden network" : "+ Hidden network…"
                        dim: !win.showHidden
                        bold: win.showHidden
                        size: win.uiSize - 1.5
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.showHidden = !win.showHidden }
                    }
                    Column {
                        visible: win.showHidden
                        width: parent.width
                        spacing: 6
                        Field { id: hiddenName; width: parent.width; placeholder: "Network name (SSID)" }
                        Row {
                            width: parent.width
                            spacing: 6
                            Field {
                                id: hiddenPass
                                width: parent.width - hiddenJoin.width - 6
                                secret: true
                                placeholder: "Password (empty for an open one)"
                                onAccepted: hiddenJoin.clicked()
                            }
                            Button {
                                id: hiddenJoin
                                implicitHeight: 34
                                text: "Join"
                                primary: true
                                onClicked: {
                                    if (!hiddenName.text) return;
                                    Wifi.connect(hiddenName.text, hiddenPass.text, true);
                                    hiddenPass.text = "";
                                    win.showHidden = false;
                                }
                            }
                        }
                    }
                }

                // ── saved ─────────────────────────────────────────────────
                Column {
                    visible: Wifi.saved.length > 0
                    width: parent.width
                    spacing: 4
                    T {
                        text: `${win.showSaved ? "▾" : "▸"}  Saved networks (${Wifi.saved.length})`
                        bold: true
                        dim: !win.showSaved
                        size: win.uiSize - 1.5
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.showSaved = !win.showSaved }
                    }
                    Repeater {
                        model: win.showSaved ? Wifi.saved : []
                        delegate: Rectangle {
                            id: s
                            required property var modelData
                            readonly property string secret: Wifi.secrets[modelData.uuid] ?? ""
                            width: body.width
                            height: secret ? 70 : 44
                            radius: win.chip
                            color: Qt.alpha(win.role("fg"), 0.04)
                            T {
                                x: 12
                                y: 0
                                height: 44
                                width: parent.width - 12 - savedButtons.width - 16
                                text: s.modelData.name + (s.modelData.active ? "  ·  on now" : "")
                            }
                            Row {
                                id: savedButtons
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                y: 7
                                spacing: 6
                                T { height: 30; text: "auto"; dim: true; size: win.uiSize - 3 }
                                Switch {
                                    y: 4
                                    on: s.modelData.autoconnect
                                    onToggled: Wifi.autoconnect(s.modelData.uuid, !s.modelData.autoconnect)
                                }
                                Button {
                                    text: s.secret ? "Hide" : "Password"
                                    onClicked: s.secret ? Wifi.hide(s.modelData.uuid) : Wifi.reveal(s.modelData.uuid)
                                }
                                Button { text: "Forget"; danger: true; onClicked: Wifi.forget(s.modelData.uuid) }
                            }
                            T {
                                visible: !!s.secret
                                x: 12
                                y: 42
                                width: parent.width - 24
                                text: s.secret
                                font.family: win.fontMono
                                size: win.uiSize - 1.5
                                color: win.role("accent")
                            }
                        }
                    }
                }

                // the rest (enterprise Wi-Fi, VPNs, static addresses): nmtui
                T {
                    text: "More settings in nmtui →"
                    dim: true
                    size: win.uiSize - 2.5
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { win.open = false; Quickshell.execDetached(["kitty", "-e", "nmtui"]); }
                    }
                }
            }
        }
    }
}
