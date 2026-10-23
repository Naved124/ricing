pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.services

// Notification Center, from the clock: today's date and the month, then
// every notification kept, grouped by app (newest first), with Clear All.
Panel {
    id: root

    name: "notifications"
    paneWidth: 380
    paneHeight: (screen ? screen.height : 1080) - 46
    paneX: (screen ? screen.width : 1920) - paneWidth - 8
    paneY: 38
    onShownChanged: if (shown) Notifs.seen()

    readonly property var groups: {
        const by = {};
        const order = [];
        for (const n of Notifs.all.slice().reverse()) {
            const k = n.appName || qsTr("Other");
            if (!by[k]) { by[k] = []; order.push(k); }
            by[k].push(n);
        }
        return order.map(k => ({ app: k, items: by[k] }));
    }

    ColumnLayout {
        anchors { fill: parent; margins: 16 }
        spacing: 12

        // the month (a widget, as in Tahoe)
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: month.implicitHeight + 24
            radius: 20
            color: Theme.fill
            Column {
                id: month
                anchors { fill: parent; margins: 12 }
                spacing: 6
                property date today: new Date()
                Label { text: Qt.formatDate(month.today, "MMMM yyyy"); strong: true; color: Theme.red }
                Grid {
                    columns: 7
                    spacing: 4
                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]
                        Label { required property string modelData; width: 44; horizontalAlignment: Text.AlignHCenter; text: modelData; secondary: true; font.pixelSize: Theme.smallSize }
                    }
                    Repeater {
                        model: {
                            const t = month.today;
                            const first = new Date(t.getFullYear(), t.getMonth(), 1);
                            const lead = (first.getDay() + 6) % 7;
                            const days = new Date(t.getFullYear(), t.getMonth() + 1, 0).getDate();
                            const cells = [];
                            for (let i = 0; i < lead; i++) cells.push(0);
                            for (let d = 1; d <= days; d++) cells.push(d);
                            return cells;
                        }
                        delegate: Rectangle {
                            required property int modelData
                            width: 44; height: 26; radius: 13
                            color: modelData === month.today.getDate() ? Theme.red : "transparent"
                            Label {
                                anchors.centerIn: parent
                                text: parent.modelData > 0 ? parent.modelData : ""
                                color: parent.modelData === month.today.getDate() ? Theme.onAccent : Theme.label
                                font.pixelSize: Theme.smallSize + 1
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Label { text: qsTr("Notifications"); strong: true; Layout.fillWidth: true }
            Label {
                visible: Notifs.all.length > 0
                text: qsTr("Clear All"); secondary: true
                MouseArea { anchors.fill: parent; onClicked: Notifs.clearAll() }
            }
        }
        Label { visible: Notifs.all.length === 0; text: qsTr("No Notifications"); secondary: true; Layout.alignment: Qt.AlignHCenter }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: root.groups
            delegate: Column {
                id: group
                required property var modelData
                width: ListView.view.width
                spacing: 6
                Label { text: group.modelData.app; secondary: true; font.pixelSize: Theme.smallSize; strong: true }
                Repeater {
                    model: group.modelData.items
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        width: group.width
                        height: body.implicitHeight + 22
                        radius: 16
                        color: Theme.fill
                        IconImage {
                            id: ic
                            x: 10; y: 11
                            implicitSize: 28
                            source: card.modelData.image || (Quickshell.iconPath(card.modelData.appIcon || "", true))
                        }
                        Column {
                            id: body
                            anchors { left: ic.right; leftMargin: 9; right: x.left; rightMargin: 6; top: parent.top; topMargin: 10 }
                            Label { width: parent.width; text: card.modelData.summary; strong: true; font.pixelSize: Theme.textSize - 1 }
                            Label { width: parent.width; text: card.modelData.body; secondary: true; wrapMode: Text.Wrap; maximumLineCount: 3; font.pixelSize: Theme.textSize - 1 }
                        }
                        Label {
                            id: x
                            anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 8 }
                            text: "×"; secondary: true
                            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: Notifs.dismiss(card.modelData) }
                        }
                    }
                }
            }
        }
    }
}
