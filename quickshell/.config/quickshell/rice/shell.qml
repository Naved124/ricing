// The shared rice shell: the chooser and the switch overlay. It runs in
// every rice (`qs -c rice -d`, started by Hyprland) and survives switches,
// which per-rice shells can't. The `rice` script drives it:
//   qs -c rice ipc call rice toggle            open/close the chooser
//   qs -c rice ipc call rice freeze <dir>      pin <dir>/<monitor>.png on every output
//   qs -c rice ipc call rice dissolve <rice>   reveal the new rice with its transition
//   qs -c rice ipc call rice reload            re-read the rice list

import QtQuick
import Quickshell
import Quickshell.Io
import qs

ShellRoot {
    id: root

    // how long each transition shader runs, by meta.transition
    readonly property var durations: ({ ripple: 900, peel: 950, fade: 450 })

    Chooser { id: chooser }

    Variants {
        id: frames
        model: Quickshell.screens
        Freeze {}
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

        function dissolve(name: string): void {
            const meta = Rices.find(name)?.meta;
            const transition = meta?.transition ?? "fade";
            const own = `file://${Rices.dir}/${name}/transition.frag.qsb`;
            const ms = root.durations[transition] ?? 700;
            for (const f of frames.instances) f.dissolve(own, ms);
            Rices.refresh();
        }
    }
}
