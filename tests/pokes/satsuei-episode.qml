import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.common

// tests/test_satsuei.py: switch DP-1 to episode 2 so the eyecatch shows.
Item {
    Timer { interval: 300; running: true; onTriggered: Hyprland.m0.activeWorkspace = Hyprland.ws2 }
}
