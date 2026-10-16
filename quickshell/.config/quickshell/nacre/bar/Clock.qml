import QtQuick
import Quickshell
import qs
import qs.common
import qs.services

// The clock pill. Hover shows the date; click opens the calendar.
Item {
    id: root

    implicitHeight: 28
    implicitWidth: row.implicitWidth + 24

    Behavior on implicitWidth { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.glassSoft
        border.color: Theme.hairline
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Item {
            width: hover.hovered ? date.implicitWidth : 0
            height: date.implicitHeight
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

            Label {
                id: date
                text: Qt.formatDate(clock.date, "ddd d MMM")
                color: Theme.inkSoft
                size: Theme.uiSize + 1
                opacity: hover.hovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatTime(clock.date, "HH:mm")
            size: Theme.uiSize + 3
            weight: Theme.weightStrong
        }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Shell.toggleCenter("calendar")
    }
}
