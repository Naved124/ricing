pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// Quick capture (Super+Shift+N): one line under the bar. Enter adds it to
// Today, or to the Idea inbox when it starts with "idea:"; Esc cancels.
// desk-sync cleans and checks the text again (allow.py); this only keeps it
// to one line of 200 characters. One per screen; the focused one opens.
PanelWindow {
    id: win

    required property var modelData
    readonly property bool open: DeskState.captureOpen
                                 && (DeskState.captureScreen === "" || DeskState.captureScreen === modelData.name)
    readonly property bool idea: /^\s*idea:/i.test(field.text)

    screen: modelData
    visible: open || box.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: DeskTheme.namespace
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        if (!open) return;
        field.text = "";
        field.forceActiveFocus();
    }

    function submit() {
        if (DeskState.capture(field.text)) DeskState.captureOpen = false;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: DeskState.captureOpen = false
    }

    Item {
        id: box
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(DeskTheme.barHeight + DeskTheme.gap * 2, win.height * 0.22)
        width: Math.min(620, win.width - DeskTheme.gap * 2)
        height: col.implicitHeight + 28

        readonly property int dur: win.open ? DeskTheme.durIn : DeskTheme.durOut
        readonly property var curve: win.open ? DeskTheme.curveIn : DeskTheme.curveOut
        opacity: win.open ? 1 : 0
        scale: win.open || DeskTheme.reducedMotion ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: box.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: box.curve } }
        Behavior on scale { NumberAnimation { duration: box.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: box.curve } }

        MouseArea { anchors.fill: parent }

        Loader {
            anchors.fill: parent
            sourceComponent: DeskTheme.backdrop ?? solid
            // a pane that bends what's behind it (Golden Gate's) wants to know where it is
            onLoaded: {
                if ("screen" in item) item.screen = Qt.binding(() => win.screen);
                if ("windowOrigin" in item) item.windowOrigin = Qt.binding(() => Qt.point(box.x, box.y));
                if ("opened" in item) item.opened = Qt.binding(() => win.open);
            }
        }
        Component {
            id: solid
            Rectangle {
                radius: DeskTheme.radius
                color: DeskTheme.surface
                border.color: DeskTheme.line
            }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 8

            Row {
                width: parent.width
                spacing: 12

                DeskGlyph { anchors.verticalCenter: parent.verticalCenter; size: DeskTheme.textSize + 8 }

                Item {
                    width: parent.width - x
                    height: field.implicitHeight + 10
                    anchors.verticalCenter: parent.verticalCenter

                    TextInput {
                        id: field
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: DeskTheme.text
                        selectionColor: DeskTheme.accent
                        selectedTextColor: DeskTheme.onAccent
                        font.family: DeskTheme.fontBody
                        font.pixelSize: DeskTheme.textSize * 1.35
                        font.weight: DeskTheme.weight
                        maximumLength: 200
                        clip: true
                        focus: win.open
                        Keys.onReturnPressed: win.submit()
                        Keys.onEnterPressed: win.submit()
                        Keys.onEscapePressed: DeskState.captureOpen = false
                    }
                    DeskText {
                        anchors.fill: field
                        visible: field.text === ""
                        text: "Add to Today, or idea: …"
                        muted: true
                        scale: 1.35
                    }
                }
            }
            Row {
                spacing: 10
                DeskText {
                    text: win.idea ? "→ Idea inbox" : "→ Today"
                    color: DeskTheme.accent
                    strong: true
                    scale: 0.85
                }
                DeskText {
                    text: "Enter to add · Esc to cancel" + (field.text.length > 160 ? `  ·  ${200 - field.text.length} left` : "")
                    muted: true
                    scale: 0.85
                }
            }
        }
    }
}
