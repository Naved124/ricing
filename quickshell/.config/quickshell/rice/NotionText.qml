import QtQuick

// Text in the Notion widget.
Text {
    property real size: NotionLook.uiSize
    property bool bold: false
    property bool dim: false
    color: dim ? NotionLook.role("muted") : NotionLook.role("fg")
    font.family: NotionLook.fontUi
    font.pixelSize: size
    font.weight: bold ? NotionLook.strong : NotionLook.weight
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
