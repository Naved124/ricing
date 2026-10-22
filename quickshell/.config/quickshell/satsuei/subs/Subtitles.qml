pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Notifications as an anime's subtitles: bottom centre of the focused
// screen, one at a time from Notifs.queue. The app's name small, spaced and
// in capitals in the accent; the body 18 px bold in the light text colour,
// outlined dark so it reads over anything, on a faint glass pill. It rises
// in (0.45 s), stays 5.2 s and fades; a critical one stays until it's
// clicked. A click runs its default action and lets it go. Quiet keeps them
// out of the queue (they're still in the control centre's list).
PanelWindow {
    id: win

    readonly property var note: Notifs.current
    property var shown: null             // what's on screen (stays while fading out)
    property bool up: false

    screen: Hypr.focusedScreen
    visible: up || box.opacity > 0
    anchors { bottom: true }
    margins.bottom: 46
    implicitWidth: Math.min(760, (screen?.width ?? 1920) - 40)
    implicitHeight: box.height + 20
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "satsuei-subs"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: up ? box : null }

    onNoteChanged: {
        if (!note) { up = false; return; }
        shown = note;
        up = true;
        if (Notifs.critical(note)) life.stop(); else life.restart();
    }
    Timer {
        id: life
        interval: Notifs.lifetime
        onTriggered: {
            win.up = false;
            gone.restart();
        }
    }
    // the next one waits for this one to fade
    Timer {
        id: gone
        interval: 380
        onTriggered: if (win.shown) Notifs.done(win.shown)
    }

    Item {
        id: box
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: win.up ? 0 : -14
        width: Math.min(parent.width, Math.max(app.implicitWidth, line.implicitWidth) + 44)
        height: col.implicitHeight + 20
        opacity: win.up ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 350 } }
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        Glass {
            anchors.fill: parent
            radius: 14
            fill: Theme.at(Theme.tint, 0.32)
            shadow: false
        }
        Column {
            id: col
            anchors.centerIn: parent
            width: parent.width - 44
            spacing: 2
            Label {
                id: app
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: (win.shown?.appName || win.shown?.summary || "").toUpperCase()
                size: 10.5
                weight: 800
                spacing: 0.2
                color: Notifs.critical(win.shown) ? Theme.urgent : Theme.accent
            }
            Label {
                id: line
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: {
                    const n = win.shown;
                    if (!n) return "";
                    const head = n.appName && n.summary ? n.summary : "";
                    return [head, n.body].filter(s => !!s).join(" — ") || n.summary || "";
                }
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                size: 18
                weight: Style.weightStrong
                lineHeight: 1.25
                // the subtitle's outline: a hair of dark all round, then a soft shadow
                style: Text.Outline
                styleColor: Theme.at(Theme.ink, 0.85)
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.at(Theme.ink, 0.9)
                    shadowBlur: 0.5
                    shadowVerticalOffset: 1
                    shadowHorizontalOffset: 0
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const n = win.shown;
                const act = (n?.actions ?? []).find(a => a.identifier === "default");
                if (act) act.invoke();
                life.stop();
                win.up = false;
                gone.restart();
            }
        }
    }
}
