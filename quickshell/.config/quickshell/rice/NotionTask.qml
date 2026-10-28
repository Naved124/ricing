import QtQuick

// One task: its tick, its icon and title (struck through once ticked), and
// its due date, status and priority. A click on the title opens it in Notion.
Item {
    id: row
    required property var task
    property bool compact: false
    property bool showStatus: !compact
    readonly property bool ticked: Notion.ticked(task)
    implicitHeight: compact ? 30 : 38

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -6
        anchors.rightMargin: -6
        radius: NotionLook.chip
        color: Qt.alpha(NotionLook.role("fg"), area.containsMouse ? 0.06 : 0)
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Notion.open(row.task.url)
    }
    NotionCheck {
        id: tick
        anchors.verticalCenter: parent.verticalCenter
        on: row.ticked
        urgent: row.task.overdue
        onToggled: Notion.setDone(row.task.id, !row.ticked)
    }
    NotionText {
        id: title
        anchors.left: tick.right
        anchors.leftMargin: 10
        anchors.right: chips.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: (row.task.icon ? row.task.icon + "  " : "") + row.task.title
        font.strikeout: row.ticked
        dim: row.ticked
        size: NotionLook.uiSize - (row.compact ? 1 : 0)
    }
    Row {
        id: chips
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        NotionChip {
            visible: !!row.task.priority && !row.compact
            text: row.task.priority ?? ""
            tone: "warning"
        }
        NotionChip {
            visible: row.showStatus && !!row.task.status && Notion.statuses.length > 0
            text: row.task.status ?? ""
            clickable: true
            // a click steps to the next status
            onClicked: {
                const s = Notion.statuses, i = s.indexOf(row.task.status);
                Notion.setStatus(row.task.id, s[(i + 1) % s.length]);
            }
        }
        NotionChip {
            visible: !!row.task.due
            text: Notion.dayName(row.task.due) + (row.task.dueTime ? " " + Notion.timeOf(row.task.due) : "")
            tone: row.task.overdue ? "urgent" : row.task.today ? "accent" : "muted"
        }
    }
}
