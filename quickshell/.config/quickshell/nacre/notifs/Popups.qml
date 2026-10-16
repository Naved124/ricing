pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.common
import qs.services

// Notification popups: top-right under the bar on the focused monitor,
// 360 wide, at most three stacked before collapsing into "+N more".
PanelWindow {
    id: win

    readonly property int pad: 20
    readonly property var shown: Notifs.popups.slice(0, Notifs.maxVisible)
    readonly property int hidden: Math.max(0, Notifs.popups.length - Notifs.maxVisible)

    screen: Hypr.focusedScreen

    anchors { top: true; right: true }
    margins { top: 12 + 38 + 6; right: Theme.gapsOut - win.pad + 4 }
    implicitWidth: 360 + pad * 2
    implicitHeight: Math.max(1, list.contentHeight + more.height + pad * 2)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nacre-notifs"

    mask: Region { item: column }

    Column {
        id: column
        x: win.pad
        y: win.pad / 2
        width: 360
        spacing: 10

        ListView {
            id: list
            width: parent.width
            height: contentHeight
            spacing: 10
            interactive: false
            model: ScriptModel { values: win.shown }

            delegate: NotificationCard {
                required property var modelData
                notification: modelData
                width: ListView.view.width
                onExpired: Notifs.hidePopup(modelData)
                onDismissed: Notifs.dismiss(modelData)
            }

            // slide in 24 px from the right with a fade
            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; from: 24; to: 0; duration: Theme.durOpen; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bloom }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durOpen; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bloom }
                }
            }
            // ...and sink away
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: Theme.durClose; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sink }
                    NumberAnimation { property: "scale"; to: 0.96; duration: Theme.durClose; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sink }
                }
            }
            // an interrupted add must still finish fully opaque
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: Theme.durMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle }
                NumberAnimation { property: "opacity"; to: 1; duration: Theme.durMove }
                NumberAnimation { property: "scale"; to: 1; duration: Theme.durMove }
            }
        }

        // "+N more" pill
        Item {
            id: more
            width: parent.width
            height: win.hidden > 0 ? 30 : 0
            opacity: win.hidden > 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }

            Glass {
                anchors.right: parent.right
                width: moreLabel.implicitWidth + 28
                height: 28
                radius: 14
                shadow: false
                fill: Theme.glassStrong

                Label {
                    id: moreLabel
                    anchors.centerIn: parent
                    text: `+${win.hidden} more`
                    size: Theme.uiSize
                    color: Theme.inkSoft
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Shell.toggleCenter()
                }
            }
        }
    }
}
