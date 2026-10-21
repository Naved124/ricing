pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.common

// The month: today a small lit plankton dot behind its number; arrows (or
// the wheel) page through months, the title goes back to today.
Item {
    id: root

    property date today: clock.date
    property int year: today.getFullYear()
    property int month: today.getMonth()
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7

    implicitHeight: column.implicitHeight

    function page(step) {
        const d = new Date(year, month + step, 1);
        year = d.getFullYear();
        month = d.getMonth();
    }
    function reset() {
        year = today.getFullYear();
        month = today.getMonth();
    }

    SystemClock { id: clock; precision: SystemClock.Hours }

    readonly property var days: {
        const first = new Date(year, month, 1);
        const offset = (first.getDay() - firstDay + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(year, month, 1 - offset + i);
            out.push({ day: d.getDate(), inMonth: d.getMonth() === month,
                       today: d.toDateString() === today.toDateString(),
                       weekend: d.getDay() === 0 || d.getDay() === 6 });
        }
        return out;
    }

    Column {
        id: column
        width: parent.width
        spacing: 8

        Item {
            width: parent.width
            height: 26
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: (Qt.locale().standaloneMonthName(root.month) + (root.year !== root.today.getFullYear() ? ` ${root.year}` : "")).toUpperCase()
                size: 12
                weight: Theme.weightStrong
                spacing: 0.18
                color: Theme.inkDim
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.reset()
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: [-1, 1]
                    delegate: Rectangle {
                        id: arrow
                        required property int modelData
                        width: 24; height: 24; radius: 12
                        color: arrowMouse.containsMouse ? Theme.washHover : "transparent"
                        border.color: arrowMouse.containsMouse ? Theme.line : "transparent"
                        Icon {
                            anchors.centerIn: parent
                            name: "chevron-right"
                            rotation: arrow.modelData < 0 ? 180 : 0
                            size: 13
                            color: Theme.inkDim
                        }
                        MouseArea {
                            id: arrowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.page(arrow.modelData)
                        }
                    }
                }
            }
        }

        Grid {
            id: grid
            columns: 7
            width: parent.width
            readonly property real cell: width / 7
            Repeater {
                model: 7
                delegate: Label {
                    required property int index
                    width: grid.cell
                    height: 20
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName((root.firstDay + index) % 7, Locale.ShortFormat).slice(0, 2).toUpperCase()
                    size: 10
                    spacing: 0.14
                    color: Theme.inkDim
                }
            }
            Repeater {
                model: root.days
                delegate: Item {
                    id: cellItem
                    required property var modelData
                    width: grid.cell
                    height: 30
                    Glow {
                        anchors.centerIn: parent
                        visible: cellItem.modelData.today
                        width: 40; height: 40
                        color: Theme.glow
                        opacity: 0.55
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        visible: cellItem.modelData.today
                        width: 26; height: 26; radius: 13
                        color: Theme.glowAt(0.14)
                        border.color: Theme.lineOn
                    }
                    Label {
                        anchors.centerIn: parent
                        text: cellItem.modelData.day
                        size: 12.5
                        font.family: Theme.fontMono
                        weight: cellItem.modelData.today ? Theme.weightStrong : Theme.weight
                        color: cellItem.modelData.today ? Theme.glow
                             : cellItem.modelData.inMonth ? (cellItem.modelData.weekend ? Theme.inkDim : Theme.ink) : Theme.greyInk
                    }
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => root.page(event.angleDelta.y > 0 ? -1 : 1)
    }
}
