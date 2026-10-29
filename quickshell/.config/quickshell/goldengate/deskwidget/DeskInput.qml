import QtQuick

// A text box in the full view: one line, or several (`multi`). It sends its
// text up with `accepted` when Enter is pressed (Ctrl+Enter when multi) or it
// loses focus, and only if it changed; then it shows `text` again, which is
// the edit if DeskState took it and what was there if not. While it has the
// focus a sync doesn't overwrite what's being typed. Plain text only, both
// ways (TextInput is; the TextEdit is set to PlainText).
Rectangle {
    id: box

    property string text: ""
    property string placeholder: ""
    property bool multi: false
    property bool mono: false
    property int maxLength: 2000
    readonly property bool editing: line.activeFocus || area.activeFocus
    readonly property string typed: multi ? area.text : line.text
    signal accepted(string text)

    implicitHeight: multi ? Math.max(area.implicitHeight + 14, DeskTheme.textSize * 4.6) : line.implicitHeight + 14
    radius: DeskTheme.radiusSmall
    color: editing ? DeskTheme.surface : DeskTheme.surfaceAlt
    border.color: editing ? DeskTheme.accent : "transparent"
    border.width: 1.5

    function show() {
        if (multi) area.text = box.text;
        else line.text = box.text;
    }
    function done() {
        const t = box.typed;
        if (t !== box.text) box.accepted(t);
        Qt.callLater(box.show);
    }
    function focusIn() {
        if (multi) area.forceActiveFocus();
        else line.forceActiveFocus();
    }

    onTextChanged: if (!editing) show()
    Component.onCompleted: show()

    TextInput {
        id: line
        visible: !box.multi
        enabled: !box.multi
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        color: DeskTheme.text
        selectionColor: DeskTheme.accent
        selectedTextColor: DeskTheme.onAccent
        font.family: box.mono ? DeskTheme.fontMono : DeskTheme.fontBody
        font.pixelSize: DeskTheme.textSize
        font.weight: DeskTheme.weight
        maximumLength: box.maxLength
        clip: true
        selectByMouse: true
        onActiveFocusChanged: if (!activeFocus) box.done()
        Keys.onReturnPressed: { box.done(); focus = false; }
        Keys.onEnterPressed: { box.done(); focus = false; }
        Keys.onEscapePressed: { box.show(); focus = false; }
    }
    TextEdit {
        id: area
        visible: box.multi
        enabled: box.multi
        anchors.fill: parent
        anchors.margins: 7
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        textFormat: TextEdit.PlainText
        wrapMode: TextEdit.Wrap
        color: DeskTheme.text
        selectionColor: DeskTheme.accent
        selectedTextColor: DeskTheme.onAccent
        font.family: box.mono ? DeskTheme.fontMono : DeskTheme.fontBody
        font.pixelSize: DeskTheme.textSize
        font.weight: DeskTheme.weight
        selectByMouse: true
        onActiveFocusChanged: if (!activeFocus) box.done()
        Keys.onPressed: event => {
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                box.done();
                focus = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                box.show();
                focus = false;
                event.accepted = true;
            }
        }
    }
    DeskText {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: box.multi ? undefined : parent.verticalCenter
        y: box.multi ? 7 : 0
        visible: box.typed === "" && !box.editing
        text: box.placeholder
        muted: true
    }
    MouseArea {
        anchors.fill: parent
        visible: !box.editing
        cursorShape: Qt.IBeamCursor
        onClicked: box.focusIn()
    }
}
