pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    readonly property var device: UPower.displayDevice
    readonly property bool present: !!(device && device.ready && device.isLaptopBattery)
    readonly property real level: present ? device.percentage : 1   // 0..1
    readonly property bool charging: present && (device.state === UPowerDeviceState.Charging
        || device.state === UPowerDeviceState.FullyCharged
        || device.state === UPowerDeviceState.PendingCharge)
    readonly property bool low: present && !charging && level < 0.2
    readonly property bool onBattery: UPower.onBattery

    readonly property string timeLeft: {
        if (!present) return "";
        const secs = charging ? device.timeToFull : device.timeToEmpty;
        if (!secs || secs <= 0) return "";
        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60);
        return h > 0 ? `${h} h ${m} min` : `${m} min`;
    }
}
