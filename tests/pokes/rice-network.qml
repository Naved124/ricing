import QtQuick
import Quickshell.Io
import qs

// tests/test_rice.py: open the network widget, feed it what nmcli would say
// (a connection, three networks around, two saved), and open each part.
Item {
    property int step: 0
    readonly property string nm: [
        "@radio", "enabled",
        "@dev", "wlan0:wifi:connected:Home", "lo:loopback:connected (externally):lo",
        "@scan", "*:Home:82:WPA2:5180 MHz", " :Cafe\\:Guest:64:--:2437 MHz", " :Neighbour:40:WPA2 WPA3:2412 MHz",
        " :Neighbour:30:WPA2:5200 MHz", " ::50:WPA2:2412 MHz",
        "@saved", "Home:1111-aaaa:802-11-wireless:yes:wlan0", "Office:2222-bbbb:802-11-wireless:no:",
        "Wired connection 1:3333-cccc:802-3-ethernet:yes:",
        "@active", "GENERAL.CONNECTION:Home", "IP4.ADDRESS[1]:192.168.1.23/24", "IP4.GATEWAY:192.168.1.1",
        "IP4.DNS[1]:192.168.1.1", "@end"].join("\n")
    readonly property var steps: [
        () => IpcRegistry.call("network", "open"),
        () => Wifi.parse(nm),
        () => console.warn("POKE:" + JSON.stringify({ tag: "read", radio: Wifi.radio, device: Wifi.device,
                                                       networks: Wifi.networks, saved: Wifi.saved.map(s => s.name),
                                                       active: Wifi.active })),
        () => { Wifi.secrets = { "2222-bbbb": "hunter22" }; },
        () => console.warn("POKE:" + JSON.stringify({ tag: "fields", f: Wifi.fields("a\\:b:c\\\\d:") })),
        () => IpcRegistry.call("network", "close"),
    ]
    Timer {
        interval: 400
        repeat: true
        running: true
        onTriggered: {
            if (parent.step >= parent.steps.length) { running = false; return; }
            parent.steps[parent.step]();
            parent.step++;
        }
    }
}
