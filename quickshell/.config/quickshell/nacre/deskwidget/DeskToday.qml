pragma ComponentBehavior: Bound

import QtQuick

// Today: open tasks first (overdue, due today, high priority, the rest), then
// the ones done today, dimmed. A click on a row ticks it in Notion.
Flickable {
    id: list

    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    function dueLabel(t) {
        if (t.done) return "";
        if (t.state === "overdue") return "overdue · " + day(t.due);
        if (t.state === "today") return "today";
        return t.due ? day(t.due) : "";
    }
    function day(iso) {
        const d = new Date(iso + "T00:00:00");
        return isNaN(d) ? iso : Qt.formatDate(d, "d MMM");
    }

    Column {
        id: col
        width: list.width
        spacing: 2

        DeskText {
            width: parent.width
            visible: DeskState.today.length === 0
            topPadding: 24
            horizontalAlignment: Text.AlignHCenter
            text: DeskState.loaded ? "Nothing on today" : "Waiting for the first sync"
            muted: true
        }

        Repeater {
            model: DeskState.today
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property var task: modelData
                width: col.width
                height: rowCol.implicitHeight + 14
                radius: DeskTheme.radiusSmall
                color: hover.hovered ? DeskTheme.surfaceAlt : "transparent"
                opacity: task.done ? 0.55 : 1

                DeskCheck {
                    id: check
                    x: 8
                    y: 9
                    checked: row.task.done
                    busy: row.task.pending === true
                }
                Column {
                    id: rowCol
                    anchors.left: check.right
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    y: 7
                    spacing: 2

                    DeskText {
                        width: parent.width
                        text: row.task.title
                        font.strikeout: row.task.done
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }
                    Row {
                        spacing: 8
                        visible: meta.text !== "" || prio.visible || area.text !== ""
                        DeskText {
                            id: meta
                            text: list.dueLabel(row.task)
                            visible: text !== ""
                            color: row.task.state === "overdue" ? DeskTheme.danger
                                 : row.task.state === "today" ? DeskTheme.warn : DeskTheme.textMuted
                            strong: row.task.state === "overdue"
                            scale: 0.84
                        }
                        DeskText {
                            id: area
                            text: row.task.area
                            visible: text !== ""
                            muted: true
                            scale: 0.84
                        }
                        DeskText {
                            id: prio
                            visible: !row.task.done && row.task.state === "high"
                                     || (row.task.priority || "").toLowerCase() === "high" && !row.task.done
                            text: "high"
                            color: DeskTheme.accent
                            strong: true
                            scale: 0.84
                        }
                    }
                    DeskText {
                        width: parent.width
                        visible: text !== "" && !row.task.done
                        text: row.task.notes
                        muted: true
                        scale: 0.84
                    }
                }

                HoverHandler { id: hover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DeskState.toggle(row.task.id)
                }
            }
        }
    }
}
