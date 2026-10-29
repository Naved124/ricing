import QtQuick

// A small text button in the panel: "Sync now", "+ Capture", "Open".
Rectangle {
    id: btn

    property string label: ""
    signal clicked()

    implicitWidth: t.implicitWidth + 18
    implicitHeight: t.implicitHeight + 8
    width: implicitWidth
    height: implicitHeight
    radius: DeskTheme.radiusSmall
    color: hover.hovered && enabled ? DeskTheme.accent : DeskTheme.surfaceAlt
    opacity: enabled ? 1 : 0.55
    Behavior on color { ColorAnimation { duration: DeskTheme.reducedMotion ? 0 : 140 } }

    DeskText {
        id: t
        anchors.centerIn: parent
        text: btn.label
        color: hover.hovered && btn.enabled ? DeskTheme.onAccent : DeskTheme.text
        strong: true
        scale: 0.86
    }
    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
