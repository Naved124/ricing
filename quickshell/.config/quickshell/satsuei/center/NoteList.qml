pragma ComponentBehavior: Bound

import QtQuick
import qs.common
import qs.services

// The last four notifications, newest first: a dot in the accent (urgent's
// colour for a critical one), the app in bold, the body, and the time. A
// click runs its default action; the × dismisses it. Quiet keeps them here
// with no subtitle.
Column {
    id: root
    spacing: 6

    readonly property var last: Notifs.all.slice(-4).reverse()

    Label {
        visible: root.last.length === 0
        width: parent.width
        text: "Nothing new."
        color: Theme.fgDim
        size: 12
    }
    Repeater {
        model: root.last
        delegate: Rectangle {
            id: note
            required property var modelData
            width: root.width
            height: body.implicitHeight + 20
            radius: 13
            color: hover.containsMouse ? Theme.at(Theme.fg, 0.1) : Theme.at(Theme.fg, 0.06)
            Rectangle {
                x: 12; y: 15
                width: 8; height: 8; radius: 4
                color: note.modelData.urgency === 2 ? Theme.urgent : Theme.accent
            }
            Column {
                id: body
                x: 30; y: 10
                width: parent.width - 30 - when.width - 24
                spacing: 2
                Label {
                    width: parent.width
                    text: note.modelData.appName || note.modelData.summary || "Notification"
                    size: 12
                    weight: Style.weightStrong
                    elide: Text.ElideRight
                }
                Label {
                    width: parent.width
                    text: [note.modelData.appName ? note.modelData.summary : "", note.modelData.body]
                          .filter(s => !!s).join(" · ")
                    size: 12
                    color: Theme.fgDim
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    lineHeight: 1.2
                    textFormat: Text.PlainText
                }
            }
            Label {
                id: when
                anchors.right: parent.right
                anchors.rightMargin: 12
                y: 12
                text: Qt.formatTime(Notifs.timeOf(note.modelData), "HH:mm")
                mono: true
                size: 10
                color: Theme.fgDim
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    const n = note.modelData;
                    if (mouse.button === Qt.MiddleButton) { Notifs.dismiss(n); return; }
                    const act = (n.actions ?? []).find(a => a.identifier === "default") ?? (n.actions ?? [])[0];
                    if (act) act.invoke();
                    Notifs.dismiss(n);
                }
            }
        }
    }
}
