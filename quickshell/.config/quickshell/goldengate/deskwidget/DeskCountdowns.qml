pragma ComponentBehavior: Bound

import QtQuick

// Countdowns: what's coming, soonest first, with the days left; a week or
// less is lit. A prep note's https link opens only when clicked.
Flickable {
    id: list

    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: col
        width: list.width
        spacing: 4

        DeskText {
            width: parent.width
            visible: DeskState.countdowns.length === 0
            topPadding: 24
            horizontalAlignment: Text.AlignHCenter
            text: DeskState.loaded ? "Nothing counting down" : "Waiting for the first sync"
            muted: true
        }

        Repeater {
            model: DeskState.countdowns
            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property var c: modelData
                width: col.width
                height: Math.max(days.height, info.implicitHeight) + 16
                radius: DeskTheme.radiusSmall
                color: c.soon ? Qt.alpha(DeskTheme.warn, 0.16) : DeskTheme.surfaceAlt
                border.color: c.soon ? DeskTheme.warn : "transparent"

                Column {
                    id: days
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 54
                    DeskText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: row.c.days === 0 ? "today" : String(row.c.days)
                        font.family: DeskTheme.fontMono
                        strong: true
                        scale: row.c.days === 0 ? 1 : 1.5
                        color: row.c.soon ? DeskTheme.warn : DeskTheme.text
                    }
                    DeskText {
                        width: parent.width
                        visible: row.c.days !== 0
                        horizontalAlignment: Text.AlignHCenter
                        text: row.c.days === 1 ? "day" : "days"
                        muted: true
                        scale: 0.8
                    }
                }
                Column {
                    id: info
                    anchors.left: days.right
                    anchors.right: open.visible ? open.left : parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    DeskText {
                        width: parent.width
                        text: row.c.event
                        strong: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }
                    DeskText {
                        width: parent.width
                        text: [row.c.date ? Qt.formatDate(new Date(row.c.date + "T00:00:00"), "ddd d MMM") : "", row.c.type]
                              .filter(s => s).join(" · ")
                        muted: true
                        scale: 0.84
                    }
                    DeskText {
                        width: parent.width
                        visible: text !== ""
                        text: row.c.prep
                        muted: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        scale: 0.84
                    }
                }
                DeskButton {
                    id: open
                    visible: !!row.c.link
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Open"
                    onClicked: DeskState.openLink(row.c.link)
                }
            }
        }
    }
}
