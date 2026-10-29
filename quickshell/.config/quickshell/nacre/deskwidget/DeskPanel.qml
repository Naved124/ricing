pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// The Desk panel, under the bar on the right of one screen: Today, Brief,
// Countdowns and Jobs, and a footer that says how fresh it is. Esc, a click
// outside or the pill again closes it. One per screen (a Variants in shell.qml);
// only the one DeskState.panelScreen names opens.
PanelWindow {
    id: win

    required property var modelData
    readonly property bool open: DeskState.panelOpen
                                 && (DeskState.panelScreen === "" || DeskState.panelScreen === modelData.name)

    screen: modelData
    visible: open || panel.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: DeskTheme.namespace
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onOpenChanged: if (open) keys.forceActiveFocus()

    MouseArea {
        anchors.fill: parent
        onClicked: DeskState.panelOpen = false
    }

    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: DeskState.panelOpen = false
        Keys.onPressed: event => {
            const i = DeskState.tabs.indexOf(DeskState.tab);
            if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) DeskState.setTab(DeskState.tabs[(i + 1) % 4]);
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) DeskState.setTab(DeskState.tabs[(i + 3) % 4]);
            else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) DeskState.setTab(DeskState.tabs[event.key - Qt.Key_1]);
            else return;
            event.accepted = true;
        }
    }

    Item {
        id: panel
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: DeskTheme.barHeight + DeskTheme.gap / 2
        anchors.rightMargin: DeskTheme.gap
        width: 420
        height: Math.min(560, win.height - anchors.topMargin - DeskTheme.gap)

        readonly property int dur: win.open ? DeskTheme.durIn : DeskTheme.durOut
        readonly property var curve: win.open ? DeskTheme.curveIn : DeskTheme.curveOut
        opacity: win.open ? 1 : 0
        transform: Translate {
            y: win.open || DeskTheme.reducedMotion ? 0 : -10
            Behavior on y { NumberAnimation { duration: panel.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: panel.curve } }
        }
        Behavior on opacity { NumberAnimation { duration: panel.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: panel.curve } }

        MouseArea { anchors.fill: parent }   // clicks inside stay inside

        Loader {
            anchors.fill: parent
            sourceComponent: DeskTheme.backdrop ?? solid
            // a pane that bends what's behind it (Golden Gate's) wants to know where it is
            onLoaded: {
                if ("screen" in item) item.screen = Qt.binding(() => win.screen);
                if ("windowOrigin" in item) item.windowOrigin = Qt.binding(() => Qt.point(panel.x, panel.y));
                if ("opened" in item) item.opened = Qt.binding(() => win.open);
            }
        }
        Component {
            id: solid
            Rectangle {
                radius: DeskTheme.radius
                color: DeskTheme.surface
                border.color: DeskTheme.line
            }
        }

        Column {
            id: head
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 18
            spacing: 12

            Item {
                width: parent.width
                height: title.implicitHeight

                Row {
                    spacing: 9
                    anchors.verticalCenter: parent.verticalCenter
                    DeskGlyph { anchors.verticalCenter: parent.verticalCenter; size: DeskTheme.textSize + 6 }
                    DeskText {
                        id: title
                        text: "Desk"
                        font.family: DeskTheme.fontDisplay
                        scale: 1.6
                    }
                }
                DeskButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    label: "+ Capture"
                    onClicked: DeskState.openCapture(win.modelData.name)
                }
            }

            // the four tabs
            Rectangle {
                width: parent.width
                height: DeskTheme.textSize + 18
                radius: DeskTheme.radiusSmall
                color: DeskTheme.surfaceAlt

                Row {
                    anchors.fill: parent
                    anchors.margins: 3
                    Repeater {
                        model: [["today", "Today"], ["brief", "Brief"], ["countdowns", "Countdowns"], ["jobs", "Jobs"]]
                        delegate: Rectangle {
                            id: tabChip
                            required property var modelData
                            readonly property bool on: DeskState.tab === modelData[0]
                            width: (parent.width) / 4
                            height: parent.height
                            radius: DeskTheme.radiusSmall - 2
                            color: on ? DeskTheme.accent : "transparent"
                            Behavior on color { ColorAnimation { duration: DeskTheme.reducedMotion ? 0 : 140 } }
                            DeskText {
                                anchors.centerIn: parent
                                text: tabChip.modelData[1] + (tabChip.modelData[0] === "today" && DeskState.open ? `  ${DeskState.open}` : "")
                                color: tabChip.on ? DeskTheme.onAccent : DeskTheme.textMuted
                                strong: tabChip.on
                                scale: 0.93
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DeskState.setTab(tabChip.modelData[0])
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: body
            anchors.top: head.bottom
            anchors.bottom: foot.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 10
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            clip: true

            DeskToday { anchors.fill: parent; visible: DeskState.tab === "today" }
            DeskBrief { anchors.fill: parent; visible: DeskState.tab === "brief" }
            DeskCountdowns { anchors.fill: parent; visible: DeskState.tab === "countdowns" }
            DeskJobs { anchors.fill: parent; visible: DeskState.tab === "jobs" }
        }

        // how fresh it is, and the way to make it fresher
        Item {
            id: foot
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            height: footCol.implicitHeight

            Column {
                id: footCol
                width: parent.width
                spacing: 4

                DeskText {
                    width: parent.width
                    visible: DeskState.error !== ""
                    text: DeskState.error
                    color: DeskTheme.danger
                    scale: 0.9
                }
                Item {
                    width: parent.width
                    height: syncBtn.height

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        DeskText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: DeskState.syncing ? "Syncing…" : DeskState.syncedLabel
                            muted: true
                            scale: 0.9
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: DeskState.badge !== ""
                            width: badgeText.implicitWidth + 12
                            height: badgeText.implicitHeight + 4
                            radius: height / 2
                            color: DeskState.offline ? DeskTheme.danger : DeskTheme.warn
                            DeskText {
                                id: badgeText
                                anchors.centerIn: parent
                                text: DeskState.badge
                                color: DeskTheme.onAccent
                                strong: true
                                scale: 0.8
                            }
                        }
                    }
                    DeskButton {
                        id: syncBtn
                        anchors.right: parent.right
                        label: "Sync now"
                        enabled: !DeskState.syncing
                        onClicked: DeskState.syncNow()
                    }
                }
                DeskText {
                    width: parent.width
                    visible: DeskState.stale && DeskState.reason !== ""
                    text: DeskState.reason
                    muted: true
                    scale: 0.82
                }
            }
        }
    }
}
