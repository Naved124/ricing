import QtQuick

// One option of a select, status or multi-select (and the view's small
// switches): lit with the accent when it's the value. Notion's option colours
// aren't used: every colour is the rice's.
Rectangle {
    id: chip

    property string label: ""
    property bool on: false
    property bool small: false
    signal clicked()

    implicitWidth: t.implicitWidth + (small ? 14 : 20)
    implicitHeight: t.implicitHeight + (small ? 6 : 9)
    width: implicitWidth
    height: implicitHeight
    radius: height / 2
    color: on ? DeskTheme.accent : hover.hovered && enabled ? Qt.alpha(DeskTheme.accent, 0.16) : DeskTheme.surfaceAlt
    border.color: on ? DeskTheme.accent : DeskTheme.line
    border.width: 1
    opacity: enabled ? 1 : 0.5
    Behavior on color { ColorAnimation { duration: DeskTheme.reducedMotion ? 0 : 140 } }

    DeskText {
        id: t
        anchors.centerIn: parent
        text: chip.label
        color: chip.on ? DeskTheme.onAccent : DeskTheme.text
        strong: chip.on
        scale: chip.small ? 0.8 : 0.88
    }
    HoverHandler { id: hover; cursorShape: chip.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler { enabled: chip.enabled; onTapped: chip.clicked() }
}
