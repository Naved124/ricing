pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.common
import qs.services

// Apps (Launchpad): every app over the dimmed desktop, a search field and
// category chips on top, pages of 7 × 5 with dots below; scroll or the
// arrows turn the page.
Panel {
    id: root

    property string query: ""
    property string category: ""
    property int page: 0
    readonly property int perPage: 35
    readonly property var chips: ["", "Development", "Graphics", "Network", "Office", "AudioVideo", "System", "Utility", "Game"]
    readonly property var list: {
        let l = query ? Apps.search(query, 200) : Apps.entries.slice().sort((a, b) => a.name.localeCompare(b.name));
        if (category) l = l.filter(e => (e.categories || []).includes(category));
        return l.filter(e => !e.noDisplay);
    }
    readonly property int pages: Math.max(1, Math.ceil(list.length / perPage))

    name: "apps"
    part: "launchpad"
    dim: true
    paneWidth: (screen ? screen.width : 1920) - 160
    paneHeight: (screen ? screen.height : 1080) - 140
    paneX: 80
    paneY: 70
    onShownChanged: if (shown) { query = ""; search.text = ""; category = ""; page = 0; search.forceActiveFocus(); }
    onQueryChanged: page = 0

    Item {
        anchors.fill: parent
        focus: true
        Keys.onLeftPressed: root.page = Math.max(0, root.page - 1)
        Keys.onRightPressed: root.page = Math.min(root.pages - 1, root.page + 1)
        WheelHandler { onWheel: e => root.page = Math.max(0, Math.min(root.pages - 1, root.page + (e.angleDelta.y < 0 ? 1 : -1))) }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 22; width: 260; height: 32; radius: 10
            color: Theme.fill
            TextInput {
                id: search
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.label
                font.family: Theme.fontUi
                font.pixelSize: Theme.textSize
                onTextChanged: root.query = text
                Keys.onEscapePressed: Shell.closeAll()
                Keys.onReturnPressed: if (root.list.length) { Shell.closeAll(); Apps.launch(root.list[0]); }
                Label { visible: search.text === ""; text: qsTr("Search"); color: Theme.label3; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 66; spacing: 6
            Repeater {
                model: root.chips
                delegate: Rectangle {
                    required property string modelData
                    width: chip.implicitWidth + 22; height: 26; radius: 13
                    color: root.category === modelData ? Theme.accent : Theme.fill
                    Label { id: chip; anchors.centerIn: parent; font.pixelSize: Theme.smallSize; text: parent.modelData || qsTr("All"); color: root.category === parent.modelData ? Theme.onAccent : Theme.label }
                    MouseArea { anchors.fill: parent; onClicked: root.category = parent.modelData }
                }
            }
        }
        Grid {
            id: grid
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 116 }
            columns: 7
            columnSpacing: (root.paneWidth - 7 * 110) / 8
            rowSpacing: 18
            Repeater {
                model: root.list.slice(root.page * root.perPage, (root.page + 1) * root.perPage)
                delegate: Column {
                    required property var modelData
                    width: 110; spacing: 6
                    AppIcon { anchors.horizontalCenter: parent.horizontalCenter; implicitSize: 72; app: parent.modelData.icon || parent.modelData.id }
                    Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Theme.smallSize; text: parent.modelData.name }
                    TapHandler { onTapped: { Shell.closeAll(); Apps.launch(parent.modelData); } }
                }
            }
        }
        Row {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
            spacing: 8
            visible: root.pages > 1
            Repeater {
                model: root.pages
                delegate: Rectangle {
                    required property int index
                    width: 8; height: 8; radius: 4
                    color: index === root.page ? Theme.label : Theme.label3
                    MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.page = parent.index }
                }
            }
        }
    }
}
