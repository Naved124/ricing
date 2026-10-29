pragma ComponentBehavior: Bound

import QtQuick

// Jobs: applications grouped by status (closed ones last), each with its
// next step. The job's https link opens only when clicked.
Flickable {
    id: list

    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: col
        width: list.width
        spacing: 10

        DeskText {
            width: parent.width
            visible: DeskState.jobs.length === 0
            topPadding: 24
            horizontalAlignment: Text.AlignHCenter
            text: DeskState.loaded ? "No applications yet" : "Waiting for the first sync"
            muted: true
        }

        Repeater {
            model: DeskState.jobs
            delegate: Column {
                id: group
                required property var modelData
                width: col.width
                spacing: 4

                DeskText {
                    leftPadding: 6
                    text: `${group.modelData.status}  ·  ${group.modelData.items.length}`
                    strong: true
                    muted: true
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.8
                    scale: 0.78
                }

                Repeater {
                    model: group.modelData.items
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property var j: modelData
                        width: group.width
                        height: info.implicitHeight + 14
                        radius: DeskTheme.radiusSmall
                        color: DeskTheme.surfaceAlt

                        Column {
                            id: info
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: open.visible ? open.left : parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            DeskText {
                                width: parent.width
                                text: row.j.company ? `${row.j.role} — ${row.j.company}` : row.j.role
                                strong: true
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                            }
                            DeskText {
                                width: parent.width
                                visible: text !== ""
                                text: row.j.next ? "Next: " + row.j.next : ""
                                color: DeskTheme.accent
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                scale: 0.88
                            }
                            DeskText {
                                width: parent.width
                                visible: text !== ""
                                text: [row.j.track, row.j.location, row.j.referral ? "referral" : "",
                                       row.j.applied ? "applied " + Qt.formatDate(new Date(row.j.applied + "T00:00:00"), "d MMM") : ""]
                                      .filter(s => s).join(" · ")
                                muted: true
                                scale: 0.82
                            }
                        }
                        DeskButton {
                            id: open
                            visible: !!row.j.link
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            label: "Open"
                            onClicked: DeskState.openLink(row.j.link)
                        }
                    }
                }
            }
        }
    }
}
