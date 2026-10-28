// The shared rice shell: the chooser and the switch overlay. It runs in
// every rice (`qs -c rice -d`, started by Hyprland) and survives switches,
// which per-rice shells can't. The `rice` script drives it:
//   qs -c rice ipc call rice toggle            open/close the chooser
//   qs -c rice ipc call rice freeze <dir>      pin <dir>/<monitor>.png on every output
//   qs -c rice ipc call rice dissolve <rice> <from> <how>
//                                              reveal the new rice: with the old one's
//                                              way out if it has one (Abyss drains), else
//                                              the new one's transition; how = fade fades
//   qs -c rice ipc call rice reload            re-read the rice list
//   qs -c rice ipc call rice reveal <mode>     reveal the desktop after `rice mode`
//                                              with the rice's mode shader (lamp, orient)
//   qs -c rice ipc call network open|close|toggle
//                                              the network widget (each rice's Wi-Fi tile:
//                                              right-click or double-click)

import QtQuick
import Quickshell
import Quickshell.Io
import qs

ShellRoot {
    id: root

    // how long each transition shader runs, by meta.transition (or transition_out)
    readonly property var durations: ({ ripple: 900, peel: 950, fade: 450, flood: 1100, drain: 1000, leak: 1000 })
    // a mode change in a rice without a mode shader fades the frozen frame away
    readonly property int modeReveal: 600

    Chooser { id: chooser }
    Network { id: network }

    Variants {
        id: frames
        model: Quickshell.screens
        Freeze {}
    }

    IpcHandler {
        target: "network"
        function open(): void { network.open = true; }
        function close(): void { network.open = false; }
        function toggle(): void { network.toggle(); }
    }

    IpcHandler {
        target: "rice"

        function toggle(): void { chooser.toggle(); }
        function ping(): string { return "pong"; }
        function reload(): void { Rices.refresh(); }

        function freeze(dir: string): void {
            chooser.open = false;
            for (const f of frames.instances) f.freeze(dir);
        }

        function dissolve(name: string, from: string, how: string): void {
            const meta = Rices.find(name)?.meta;
            const out = from ? Rices.find(from)?.meta?.transition_out ?? "" : "";
            let shader, ms, curve = null;
            if (how === "fade") {
                // animations off, or a low battery
                shader = Qt.resolvedUrl("shaders/fade.frag.qsb");
                ms = root.durations.fade;
            } else if (out) {
                shader = `file://${Rices.dir}/${from}/${out}.frag.qsb`;
                ms = root.durations[out] ?? 900;
                curve = (Rices.find(from)?.meta?.motion?.bloom ?? null);
            } else {
                const transition = meta?.transition ?? "fade";
                shader = `file://${Rices.dir}/${name}/transition.frag.qsb`;
                ms = root.durations[transition] ?? 700;
                // a rice that floods in rides its own drift curve
                if (transition === "flood") curve = meta?.motion?.bloom ?? null;
            }
            for (const f of frames.instances) f.dissolve(shader, ms, curve ? { curve: curve.concat([1, 1]) } : undefined);
            Rices.refresh();
        }

        // meta.json's mode_transition: { shader, origin, ms, tint: {light, dark}, tint_alpha }
        function reveal(mode: string): void {
            const r = Rices.active;
            const t = r?.meta?.mode_transition;
            for (const f of frames.instances) {
                if (!t) {
                    f.dissolve(Qt.resolvedUrl("shaders/fade.frag.qsb"), root.modeReveal);
                    continue;
                }
                const tint = t.tint?.[mode];
                f.dissolve(`file://${Rices.dir}/${r.name}/${t.shader}.frag.qsb`, t.ms ?? 800, {
                    origin: t.origin,
                    dark: mode === "dark" ? 1 : 0,
                    tint: tint ? Qt.alpha(tint, t.tint_alpha ?? 0.25) : "transparent",
                    stops: (r.meta.modes?.[mode]?.gradient ?? []),
                    curve: (r.meta.motion?.bloom ?? [0.2, 0.9, 0.2, 1.0]).concat([1, 1])
                });
            }
            Rices.refresh();
        }
    }
}
