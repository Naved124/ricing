// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6: every IpcHandler by its target, so a poke can
// call what `qs ipc call <target> <function>` would.
pragma Singleton
import QtQuick
QtObject {
    property var handlers: ({})
    function call(target, fn, ...args) {
        const h = handlers[target];
        if (!h) throw new Error(`no IpcHandler for ${target}`);
        return h[fn](...args);
    }
}
