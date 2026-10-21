// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

pragma Singleton
import QtQuick
QtObject {
    property bool onBattery: false
    property QtObject displayDevice: QtObject {
        property bool ready: true
        property bool isLaptopBattery: true
        property real percentage: 0.8
        property int state: 2
        property real timeToFull: 0
        property real timeToEmpty: 7200
        property string iconName: ""
        property real energy: 40
        property real energyCapacity: 50
        property real changeRate: 8
    }
}
