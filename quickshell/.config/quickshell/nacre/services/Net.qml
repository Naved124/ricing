pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// Network state from NetworkManager via Quickshell.Networking.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifi: {
        if (!wifiDevice) return null;
        const nets = wifiDevice.networks.values;
        return nets.find(n => n.connected) ?? null;
    }
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool online: !!wired || !!wifi
    readonly property real strength: wifi ? wifi.signalStrength : 0

    readonly property string label: wired ? "Wired" : wifi ? wifi.name : wifiEnabled ? "Not connected" : "Wi-Fi off"
    readonly property string icon: wired ? "ethernet"
        : wifi ? (strength > 0.45 ? "wifi" : "wifi-low")
        : "wifi-off"

    function setWifi(on) {
        Networking.wifiEnabled = on;
    }
}
