import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Desk's ways in, once per shell: Super+Shift+N (base.lua's
// quickshell:desk-capture) and `qs -c <shell> ipc call desk view|card|resize|capture|sync`.
Item {
    id: root

    function focused() { return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""; }

    GlobalShortcut {
        name: "desk-capture"
        description: "Quick capture to Notion's Desk"
        onPressed: {
            if (DeskState.captureOpen) DeskState.captureOpen = false;
            else DeskState.openCapture(root.focused());
        }
    }

    IpcHandler {
        target: "desk"
        function view(): void { DeskState.toggleView(root.focused()); }
        function card(): void { DeskState.setCardShown(!DeskState.cardShown); }
        function resize(): void { DeskState.cardResizing = !DeskState.cardResizing; }
        function capture(): void { DeskState.openCapture(root.focused()); }
        function sync(): void { DeskState.syncNow(); }
    }
}
