pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.common
import qs.services

// The Apple menu (and the power menu, Super+Escape): About, System
// Settings, App Store's place taken by Apps, then Sleep, Restart, Shut Down,
// Lock Screen and Log Out.
Panel {
    id: root

    readonly property bool power: Shell.open === "power"
    name: power ? "power" : "apple"
    part: "controlcenter"   // glassed like a panel (the bar itself may be clear)
    paneWidth: 240
    paneHeight: col.implicitHeight + 12
    paneX: power ? ((screen ? screen.width : 1920) - paneWidth) / 2 : 8
    paneY: power ? ((screen ? screen.height : 1080) - paneHeight) / 2 : 36
    pane.radius: Theme.radiusPopup

    readonly property var items: [
        { t: qsTr("About This Computer"), go: () => Shell.gg(["settings", "about"]) },
        null,
        { t: qsTr("System Settings…"), go: () => Shell.gg(["settings"]) },
        { t: qsTr("Apps"), go: () => Shell.toggle("apps") },
        null,
        { t: qsTr("Sleep"), go: () => Shell.run(["systemctl", "suspend"]) },
        { t: qsTr("Restart…"), go: () => Shell.run(["systemctl", "reboot"]) },
        { t: qsTr("Shut Down…"), go: () => Shell.run(["systemctl", "poweroff"]) },
        null,
        { t: qsTr("Lock Screen"), go: () => Shell.run(["rice", "lock"]) },
        { t: qsTr("Log Out…"), go: () => Shell.run(["sh", "-c", "command -v hyprshutdown >/dev/null && exec hyprshutdown || exec hyprctl dispatch 'hl.dsp.exit()'"]) },
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
                height: modelData ? 26 : 11
                Rectangle { visible: !row.modelData; anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Theme.separator }
                Rectangle {
                    visible: !!row.modelData
                    anchors.fill: parent
                    radius: 6
                    color: mh.containsMouse ? Theme.accent : "transparent"
                    Label { x: 10; anchors.verticalCenter: parent.verticalCenter; text: row.modelData ? row.modelData.t : ""; color: mh.containsMouse ? Theme.onAccent : Theme.label }
                    MouseArea { id: mh; anchors.fill: parent; hoverEnabled: true; onClicked: { Shell.closeAll(); row.modelData.go(); } }
                }
            }
        }
    }
}
