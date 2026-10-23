import QtQuick
import qs.common
import qs.services

// tests/test_goldengate.py: the glass gg reports, and what the shell wears for it.
Item {
    property int step: 0
    readonly property var steps: [
        ["liquid", () => Glass.state = { want: "liquid", mode: "liquid", backend: "hyprglass", reason: "" }],
        ["fell back", () => Glass.state = { want: "liquid", mode: "frosted", backend: "hyprland", reason: "hyprglass is paused" }],
        ["shader", () => Glass.state = { want: "liquid", mode: "liquid", backend: "shader", reason: "" }],
        ["solid", () => Glass.state = { want: "solid", mode: "solid", backend: "hyprland", reason: "" }],
    ]
    Timer {
        interval: 300
        repeat: true
        running: true
        onTriggered: {
            if (parent.step > 0)
                console.warn("POKE:" + JSON.stringify({ state: parent.steps[parent.step - 1][0], glass: Theme.glassMode,
                    plugin: Theme.liquidPlugin, shader: Theme.shaderGlass, fellBack: Glass.fellBack, shadow: Theme.glassShadow.a,
                    tint: Theme.glass.a }));
            if (parent.step >= parent.steps.length) { running = false; return; }
            parent.steps[parent.step][1]();
            parent.step++;
        }
    }
}
