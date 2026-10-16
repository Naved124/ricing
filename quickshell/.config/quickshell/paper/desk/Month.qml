pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// The month on an index card, dropped under the clock when it's clicked:
// the days pencilled in a grid, today looped in red pen. ‹ › turn months;
// a click outside or Esc puts it away.
PanelWindow {
    id: win

    readonly property bool open: Shell.calendarPeek
    property date month: new Date()
    readonly property date today: clock.date

    screen: Hypr.focusedScreen
    visible: open || card.opacity > 0

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "paper-month"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onOpenChanged: if (open) { month = new Date(today.getFullYear(), today.getMonth(), 1); keys.forceActiveFocus(); }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // the days of the grid: Monday-first weeks covering the month
    readonly property var cells: {
        const first = new Date(month.getFullYear(), month.getMonth(), 1);
        const lead = (first.getDay() + 6) % 7;
        const days = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < lead; i++) out.push(0);
        for (let d = 1; d <= days; d++) out.push(d);
        while (out.length % 7) out.push(0);
        return out;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Shell.calendarPeek = false
    }

    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: Shell.calendarPeek = false
        Keys.onLeftPressed: win.month = new Date(win.month.getFullYear(), win.month.getMonth() - 1, 1)
        Keys.onRightPressed: win.month = new Date(win.month.getFullYear(), win.month.getMonth() + 1, 1)
    }

    Sheet {
        id: card

        // under the clock, at the right end of the bar
        x: Math.round(win.width * 0.875) - width
        width: 320
        height: grid.y + grid.height + 22
        seed: 31
        tilt: -0.8
        ruled: true
        ruleTop: 58
        ruleGap: 30

        // drops in from under the bar; tossed away
        property real drop: win.open ? 0 : -30
        y: 10 + 44 + 14 + drop
        opacity: win.open ? 1 : 0
        Behavior on drop { NumberAnimation { duration: win.open ? Theme.durPanelIn : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.open ? Theme.drop : Theme.toss } }
        Behavior on opacity { NumberAnimation { duration: win.open ? Theme.durPanelIn / 2 : Theme.durPanelOut } }

        MouseArea { anchors.fill: parent }   // clicks on the card stay on it

        Hand {
            x: 20
            y: 12
            text: "‹"
            size: 24
            color: Theme.ink
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: win.month = new Date(win.month.getFullYear(), win.month.getMonth() - 1, 1)
            }
        }
        Type {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 20
            text: Qt.formatDate(win.month, "MMMM yyyy").toUpperCase()
            size: 13
            color: Theme.red
            font.letterSpacing: 4
        }
        Hand {
            anchors.right: parent.right
            anchors.rightMargin: 20
            y: 12
            text: "›"
            size: 24
            color: Theme.ink
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: win.month = new Date(win.month.getFullYear(), win.month.getMonth() + 1, 1)
            }
        }

        Grid {
            id: grid
            x: 20
            y: 34
            columns: 7
            columnSpacing: 0
            rowSpacing: 0

            Repeater {
                model: ["m", "t", "w", "t", "f", "s", "s"]
                delegate: Hand {
                    required property string modelData
                    width: 40
                    height: 24
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    size: 14
                    color: Theme.graphite
                }
            }

            Repeater {
                model: win.cells
                delegate: Item {
                    id: day

                    required property int modelData
                    required property int index
                    readonly property bool isToday: modelData > 0
                        && win.month.getFullYear() === win.today.getFullYear()
                        && win.month.getMonth() === win.today.getMonth()
                        && modelData === win.today.getDate()

                    width: 40
                    height: 30

                    Hand {
                        anchors.centerIn: parent
                        visible: day.modelData > 0
                        text: day.modelData
                        size: 17
                        color: day.isToday ? Theme.ink : day.index % 7 > 4 ? Theme.red : Theme.pencil
                        font.features: { "tnum": 1 }
                    }
                    Scribble {
                        anchors.centerIn: parent
                        width: 34
                        height: 28
                        seed: day.modelData
                        drawn: day.isToday && win.open
                    }
                }
            }
        }
    }
}
