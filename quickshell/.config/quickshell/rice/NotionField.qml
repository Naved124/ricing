import QtQuick
import QtQuick.Controls

// A one-line entry: Return sends it, Escape lets go.
Rectangle {
    id: fld
    property alias text: input.text
    property alias placeholder: input.placeholderText
    property alias input: input
    signal accepted()
    signal escaped()
    function focusIn() { input.forceActiveFocus(); }
    implicitHeight: 32
    radius: NotionLook.chip
    color: Qt.alpha(NotionLook.role("fg"), 0.06)
    border.width: 1
    border.color: input.activeFocus ? NotionLook.role("accent") : Qt.alpha(NotionLook.role("fg"), 0.12)
    Behavior on border.color { ColorAnimation { duration: 160 } }
    TextField {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        background: null
        verticalAlignment: Text.AlignVCenter
        color: NotionLook.role("fg")
        placeholderTextColor: NotionLook.role("muted")
        selectionColor: Qt.alpha(NotionLook.role("accent"), 0.35)
        selectedTextColor: NotionLook.role("fg")
        font.family: NotionLook.fontUi
        font.pixelSize: NotionLook.uiSize - 1
        onAccepted: fld.accepted()
        Keys.onEscapePressed: { input.focus = false; fld.escaped(); }
    }
}
