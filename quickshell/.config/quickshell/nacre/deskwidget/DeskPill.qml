import QtQuick

// The bar's Desk pill: Notion's mark, the open to-dos and the nearest
// countdown ("3 · 4d · Placement"). A dot when the sync is stale. A click
// opens the panel on this screen.
Item {
    id: pill

    property string screenName: ""
    property bool showNext: true     // a narrow bar can leave the countdown out

    implicitHeight: DeskTheme.textSize + 14
    implicitWidth: row.implicitWidth + 16

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: hover.hovered || DeskState.panelOpen ? DeskTheme.surfaceAlt : "transparent"
        Behavior on color { ColorAnimation { duration: DeskTheme.reducedMotion ? 0 : 160 } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        DeskGlyph {
            anchors.verticalCenter: parent.verticalCenter
            size: DeskTheme.textSize + 1
            color: DeskState.overdue > 0 ? DeskTheme.danger : DeskTheme.text
        }
        DeskText {
            anchors.verticalCenter: parent.verticalCenter
            text: DeskState.loaded ? String(DeskState.open) : "–"
            strong: true
            font.family: DeskTheme.fontMono
        }
        DeskText {
            anchors.verticalCenter: parent.verticalCenter
            visible: pill.showNext && DeskState.nextLabel !== ""
            text: "· " + DeskState.nextLabel
            width: Math.min(implicitWidth, 160)
            color: DeskState.next && DeskState.next.days <= 7 ? DeskTheme.warn : DeskTheme.textMuted
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: DeskState.stale
            width: 6
            height: 6
            radius: 3
            color: DeskState.offline ? DeskTheme.danger : DeskTheme.warn
        }
    }

    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) DeskState.openCapture(pill.screenName);
            else DeskState.togglePanel(pill.screenName);
        }
    }
}
