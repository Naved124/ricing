// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.
import QtQuick
// `anchors { top: true … }` and `WlrLayershell.x:` are renamed to
// panelAnchors / layershell when the smoke test copies a shell.
QtObject {
    id: win

    // a window isn't an Item: its contents hang off one
    property Item contentItem: Item { id: content; width: win.width; height: win.height; visible: win.visible }
    default property alias data: content.data
    property bool visible: true
    property real width: implicitWidth > 0 ? implicitWidth : (screen ? screen.width : 1920)
    property real height: implicitHeight > 0 ? implicitHeight : (screen ? screen.height : 1080)
    property real implicitWidth: 0
    property real implicitHeight: 0
    property var screen: null
    property color color: "white"
    property var mask: null
    property var windowTransform: null
    property bool backingWindowVisible: visible
    property var surfaceFormat: ({})
    signal windowConnected()
    function itemPosition(item) { return Qt.point(0, 0); }
    function itemRect(item) { return Qt.rect(0, 0, 0, 0); }
    function mapFromItem(item, x, y) { return Qt.point(x, y); }
    property Edges panelAnchors: Edges {}
    property Margins margins: Margins {}
    property int exclusionMode: 0
    property int exclusiveZone: 0
    property bool focusable: false
    property bool aboveWindows: true
    property Layershell layershell: Layershell {}
}
