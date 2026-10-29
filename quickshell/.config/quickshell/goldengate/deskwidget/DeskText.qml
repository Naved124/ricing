import QtQuick

// Every word the Desk widget draws. Notion's text is untrusted, so it is
// always plain text: a title can't become markup or a link. (No other Text
// in deskwidget/: tests/test_desk_widget.py.)
Text {
    property bool strong: false
    property bool muted: false
    property real scale: 1

    textFormat: Text.PlainText
    color: muted ? DeskTheme.textMuted : DeskTheme.text
    font.family: DeskTheme.fontBody
    font.pixelSize: DeskTheme.textSize * scale
    font.weight: strong ? DeskTheme.weightStrong : DeskTheme.weight
    elide: Text.ElideRight
    maximumLineCount: wrapMode === Text.NoWrap ? 1 : 6
    verticalAlignment: Text.AlignVCenter
}
