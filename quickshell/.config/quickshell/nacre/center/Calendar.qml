pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.common

// A month at a glance. Today is a small iridescent pearl; the arrows (or
// the scroll wheel) page through months, and the title goes back to today.
Item {
    id: root

    property date today: clock.date
    property int year: today.getFullYear()
    property int month: today.getMonth()
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7   // 0 = Sunday

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

    // 6 rows × 7 days, starting on the locale's first weekday
    readonly property var days: {
        const first = new Date(year, month, 1);
        const offset = (first.getDay() - firstDay + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(year, month, 1 - offset + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === month,
                today: d.toDateString() === today.toDateString(),
                weekend: d.getDay() === 0 || d.getDay() === 6,
            });
        }
        return out;
    }

    Column {
        id: column
        width: parent.width
        spacing: 8

        Item {
            width: parent.width
            height: 30

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.locale().standaloneMonthName(root.month) + (root.year !== root.today.getFullYear() ? ` ${root.year}` : "")
                font.family: Theme.fontDisplay
                size: 25
                weight: Theme.weightDisplay
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
                        width: 26
                        height: 26
                        radius: 13
                        color: arrowMouse.containsMouse ? Theme.pearl : "transparent"
                        border.color: arrowMouse.containsMouse ? Theme.hairline : "transparent"
                        Icon {
                            anchors.centerIn: parent
                            name: "chevron-right"
                            rotation: arrow.modelData < 0 ? 180 : 0
                            size: 14
                            color: Theme.inkSoft
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

            // weekday initials in small caps
            Repeater {
                model: 7
                delegate: Label {
                    required property int index
                    width: grid.cell
                    height: 22
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName((root.firstDay + index) % 7, Locale.ShortFormat).slice(0, 2)
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: 0.8
                    size: Theme.uiSize
                    color: Theme.inkSoft
                }
            }

            Repeater {
                model: root.days
                delegate: Item {
                    id: cellItem
                    required property var modelData
                    width: grid.cell
                    height: 34

                    Iridescent {
                        anchors.centerIn: parent
                        visible: cellItem.modelData.today
                        width: 30
                        height: 30
                        sheen: 0.5
                        period: 10000
                    }
                    Label {
                        anchors.centerIn: parent
                        text: cellItem.modelData.day
                        size: Theme.uiSize + 1
                        weight: cellItem.modelData.today ? Theme.weightStrong : Theme.weight
                        color: cellItem.modelData.inMonth ? (cellItem.modelData.weekend ? Theme.inkSoft : Theme.ink) : Theme.lilac
                    }
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => root.page(event.angleDelta.y > 0 ? -1 : 1)
    }
}
