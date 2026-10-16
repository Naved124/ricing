import QtQuick
import Quickshell
import qs.common
import qs.services

// The time in red Kalam, "11:55 pm", with figures that don't shift as they
// change. Click it for the calendar card.
Item {
    id: root

    implicitWidth: text.implicitWidth
    implicitHeight: text.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Hand {
        id: text
        text: Qt.formatTime(clock.date, "h:mm ap")
        size: 21
        color: Theme.red
        font.features: { "tnum": 1 }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const open = !Shell.calendarPeek;
            Shell.closeAll();
            Shell.calendarPeek = open;
        }
    }
}
