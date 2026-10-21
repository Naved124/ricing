import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.services

// tests/test_abyss.py: put the desktop through each state the reef throttles
// on, and report the first screen's stats after each.
Item {
    property int step: 0
    readonly property var steps: [
        ["full", () => {}],
        ["fullscreen", () => Hyprland.m0.activeWorkspace = Object.assign({}, Hyprland.ws1, { hasFullscreen: true })],
        ["back", () => Hyprland.m0.activeWorkspace = Hyprland.ws1],
        ["locked", () => Shell.locked = true],
        ["unlocked", () => Shell.locked = false],
        ["covered", () => Hyprland.toplevels.values = [
            { lastIpcObject: { at: [0, 0], size: [960, 1080], workspace: { id: 1 }, mapped: true } },
            { lastIpcObject: { at: [960, 0], size: [960, 1080], workspace: { id: 1 }, mapped: true } }]],
        ["half covered", () => Hyprland.toplevels.values = [
            { lastIpcObject: { at: [0, 0], size: [960, 1080], workspace: { id: 1 }, mapped: true } }]],
        ["low battery", () => { UPower.onBattery = true; UPower.displayDevice.percentage = 0.2; }],
        ["charging", () => { UPower.onBattery = false; UPower.displayDevice.percentage = 0.8; }],
        ["dpms off", () => { Hyprland.m0.lastIpcObject = { dpmsStatus: false }; Hyprland.toplevels.values = []; }],
        ["dpms on", () => { Hyprland.m0.lastIpcObject = { dpmsStatus: true }; Hyprland.toplevels.values = [{ lastIpcObject: {} }]; }],
        ["pointer off", () => Shell.setReefInteractive(false)],
    ]
    Timer {
        interval: 700
        repeat: true
        running: true
        onTriggered: {
            const s = Reefs.stats()["DP-1"];
            if (parent.step > 0)
                console.warn("POKE:" + JSON.stringify({ state: parent.steps[parent.step - 1][0], rate: s.rate,
                    running: s.running, reduced: s.reduced, throttle: s.throttle, plankton: s.plankton,
                    bloom: s.bloom, interactive: s.interactive, coverage: s.coverage }));
            if (parent.step >= parent.steps.length) { running = false; return; }
            parent.steps[parent.step][1]();
            parent.step++;
        }
    }
}
