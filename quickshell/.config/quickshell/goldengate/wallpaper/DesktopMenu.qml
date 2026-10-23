pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.common
import qs.services

// The desktop's menu (a right-click on the wallpaper), as the Finder has it:
// Change Wallpaper…, the widgets, System Settings.
Panel {
    id: root

    name: "desktopmenu"
    part: "controlcenter"
    paneWidth: 220
    paneHeight: col.implicitHeight + 12
    readonly property point where: Shell.desktopMenuAt
    paneX: Math.max(8, Math.min((screen ? screen.width : 1920) - paneWidth - 8, where.x))
    paneY: Math.max(8, Math.min((screen ? screen.height : 1080) - paneHeight - 8, where.y))
    pane.radius: Theme.radiusPopup

    readonly property var items: [
        { t: qsTr("Change Wallpaper…"), go: () => Shell.toggle("wallpaper") },
        null,
        { t: Shell.weatherShown ? qsTr("Hide Weather") : qsTr("Show Weather"), go: () => { Shell.closeAll(); Shell.setWeatherShown(!Shell.weatherShown); } },
        { t: Shell.statsShown ? qsTr("Hide System") : qsTr("Show System"), go: () => { Shell.closeAll(); Shell.setStatsShown(!Shell.statsShown); } },
        null,
        { t: qsTr("System Settings…"), go: () => { Shell.closeAll(); Shell.gg(["settings", "desktop"]); } },
    ]

    Column {
        id: col
        anchors { fill: parent; margins: 6 }
        Repeater {
            model: root.items
            delegate: Item {
                id: row
                required property var modelData
                width: col.width
                height: modelData ? 26 : 9
                Rectangle {
                    visible: !row.modelData
                    anchors.centerIn: parent
                    width: parent.width - 12; height: 1
                    color: Theme.separator
                }
                Rectangle {
                    visible: !!row.modelData
                    anchors.fill: parent
                    radius: 6
                    color: m.containsMouse ? Theme.accent : "transparent"
                    Label {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData ? row.modelData.t : ""
                        color: m.containsMouse ? Theme.onAccent : Theme.label
                    }
                    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; onClicked: row.modelData.go() }
                }
            }
        }
    }
}
