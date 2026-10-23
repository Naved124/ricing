import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.common
import qs.services

// a tray icon, drawn as a symbol in the bar's ink (as the Mac's are),
// or as the app drew it when Settings turns that off
Item {
    id: ti
    property string source
    property color ink: Theme.label
    implicitWidth: 16; implicitHeight: 16
    IconImage {
        id: timg
        anchors.fill: parent
        implicitSize: 16
        source: ti.source
        visible: !Settings.menubar.monoTray
        layer.enabled: Settings.menubar.monoTray
    }
    Rectangle {
        id: fill
        anchors.fill: parent
        visible: false
        color: ti.ink
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        visible: Settings.menubar.monoTray
        source: fill
        maskEnabled: true
        maskSource: timg
        maskThresholdMin: 0.3
        maskSpreadAtMin: 0.3
    }
}
