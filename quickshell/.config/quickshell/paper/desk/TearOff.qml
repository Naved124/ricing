pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.common

// A tear-off desk calendar, 200×232: a red header with two binding holes,
// the month in spaced-out Courier, the day huge in Newsreader and the
// weekday in Kalam. Click to tear the page off: it twists away and falls
// while the next day shows through. It goes back to today 10 s later, or
// at midnight.
Item {
    id: root

    property date shown: today
    readonly property date today: clock.date
    property int tears: 0

    width: 200
    height: 232

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        // a new day: back to it, whatever page was showing
        onDateChanged: if (clock.date.getDate() !== root.shownDay) root.reset()
    }
    property int shownDay: today.getDate()

    function reset() {
        shown = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        shownDay = today.getDate();
        tears = 0;
    }

    function tear() {
        pageComp.createObject(host, { day: root.shown, falling: true });
        tears++;
        shown = new Date(shown.getFullYear(), shown.getMonth(), shown.getDate() + 1);
        back.restart();
    }

    Timer {
        id: back
        interval: 10000
        onTriggered: root.reset()
    }

    Sheet {
        id: sheet
        anchors.fill: parent
        fill: Theme.chalk
        tilt: 1.6
        tiltContent: true
        seed: 1015

        Item {
            id: host
            anchors.fill: parent

            // the header: red card with two binding holes
            Rectangle {
                id: header
                width: parent.width
                height: 34
                color: Theme.red
                Row {
                    anchors.centerIn: parent
                    spacing: 26
                    Repeater {
                        model: 2
                        delegate: Rectangle {
                            width: 9
                            height: 9
                            radius: 4.5
                            color: Theme.binding
                            border.color: Qt.alpha(Theme.soot, 0.135)
                        }
                    }
                }
            }

            // today's page (the falling ones are made from the same component)
            Loader {
                y: header.height
                width: parent.width
                height: parent.height - header.height
                sourceComponent: pageComp
                onLoaded: item.day = Qt.binding(() => root.shown)
            }
        }
    }

    Component {
        id: pageComp

        Rectangle {
            id: page

            property date day: new Date()
            property bool falling: false

            x: 0
            y: falling ? 34 : 0
            width: root.width
            height: root.height - 34
            color: Theme.chalk
            transformOrigin: Item.TopLeft
            antialiasing: true

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 14
                spacing: 0

                Type {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(page.day, "MMMM").toUpperCase()
                    size: 13
                    color: Theme.red
                    font.letterSpacing: 13 * 0.3
                }
                Serif {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.day.getDate()
                    size: 118
                    weight: 600
                    lineHeight: 0.95
                }
                Hand {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(page.day, "dddd")
                    size: 19
                    color: Theme.ink
                }
                Hand {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 4
                    text: page.falling ? "" : root.tears ? "back to today soon" : "tap to tear off"
                    size: 13
                    color: Theme.graphite
                }
            }

            // torn off: a little tug, then it twists away and drops out of sight
            SequentialAnimation {
                running: page.falling
                ParallelAnimation {
                    NumberAnimation { target: page; property: "rotation"; to: -8; duration: 240; easing.type: Easing.OutQuad }
                    NumberAnimation { target: page; property: "y"; to: 34 + 4; duration: 240 }
                }
                ParallelAnimation {
                    NumberAnimation { target: page; property: "rotation"; to: -40; duration: 560; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.5, 0, 0.8, 0.5, 1, 1] }
                    NumberAnimation { target: page; property: "x"; to: -60; duration: 560; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.5, 0, 0.8, 0.5, 1, 1] }
                    NumberAnimation { target: page; property: "y"; to: 34 + 520; duration: 560; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.5, 0, 0.8, 0.5, 1, 1] }
                    NumberAnimation { target: page; property: "opacity"; to: 0; duration: 560; easing.type: Easing.InQuad }
                }
                ScriptAction { script: page.destroy() }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.tear()
    }
}
