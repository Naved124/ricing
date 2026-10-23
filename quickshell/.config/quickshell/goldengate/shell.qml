//@ pragma UseQApplication

// Golden Gate — macOS 27 on Hyprland, in behaviour as well as looks.
// Run with `qs -c goldengate` (the `rice` script does this when Golden Gate
// is active); `gg` drives it over IPC.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.apps
import qs.common
import qs.controlcenter
import qs.desk
import qs.dock
import qs.hotcorners
import qs.keys
import qs.lock
import qs.menubar
import qs.mission
import qs.notifications
import qs.osd
import qs.services
import qs.settings
import qs.spotlight
import qs.wallpaper

ShellRoot {
    id: shell

    // per screen: the desktop picture under everything, the menu bar with
    // the island, the Dock, the system card, the corners and every panel
    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: perScreen
            required property var modelData
            Wallpaper { modelData: perScreen.modelData }
            MenuBar { screen: perScreen.modelData; at: perScreen.modelData.name }
            Dock { screen: perScreen.modelData; at: perScreen.modelData.name }
            Stats { screen: perScreen.modelData; at: perScreen.modelData.name }
            HotCorners { screen: perScreen.modelData }
            ControlCenter { screen: perScreen.modelData; at: perScreen.modelData.name }
            Center { screen: perScreen.modelData; at: perScreen.modelData.name }
            Spotlight { screen: perScreen.modelData; at: perScreen.modelData.name }
            Launchpad { screen: perScreen.modelData; at: perScreen.modelData.name }
            Mission { screen: perScreen.modelData; at: perScreen.modelData.name }
            AppleMenu { screen: perScreen.modelData; at: perScreen.modelData.name }
            Keys { screen: perScreen.modelData; at: perScreen.modelData.name }
        }
    }

    // banners and the OSD on the first screen
    Banners { screen: Quickshell.screens[0] }
    Banner {
        id: banner
        screen: Quickshell.screens[0]
    }
    Osd { screen: Quickshell.screens[0] }
    Lock {}
    SettingsApp { id: settingsApp }

    Connections {
        target: Glass
        function onFell(reason) {
            banner.show(qsTr("Liquid Glass is unavailable"), qsTr("Using Frosted glass instead: %1.").arg(reason));
        }
    }

    // caffeine: an idle inhibitor on a window that is always there
    PanelWindow {
        id: keepAwake
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "goldengate:desktop"
        mask: Region {}
        IdleInhibitor { window: keepAwake; enabled: Shell.caffeine }
    }

    // base.lua's shell binds
    GlobalShortcut { name: "launcher"; description: "Spotlight"; onPressed: Shell.toggle("spotlight") }
    GlobalShortcut { name: "launcher-tap"; description: "Spotlight (Super on its own)"; onPressed: Shell.toggle("spotlight") }
    GlobalShortcut { name: "clipboard"; description: "Clipboard history"; onPressed: Shell.toggle("clipboard") }
    GlobalShortcut { name: "center"; description: "Control Center"; onPressed: Shell.toggle("controlcenter") }
    GlobalShortcut { name: "keybinds"; description: "The key sheet"; onPressed: Shell.toggle("keys") }
    GlobalShortcut { name: "power"; description: "The power menu"; onPressed: Shell.toggle("power") }

    // gg's surfaces: qs -c goldengate ipc call <target> <function>
    IpcHandler { target: "spotlight"; function toggle(): void { Shell.toggle("spotlight"); } }
    IpcHandler { target: "controlcenter"; function toggle(): void { Shell.toggle("controlcenter"); } }
    IpcHandler { target: "notifications"; function toggle(): void { Shell.toggle("notifications"); } }
    IpcHandler { target: "apps"; function toggle(): void { Shell.toggle("apps"); } }
    IpcHandler {
        target: "mission"
        function toggle(): void { Shell.toggle("mission"); }
        function expose(): void { Shell.toggle("expose"); }
    }
    IpcHandler { target: "dock"; function toggle(): void { Shell.gg(["set", "dock.autohide", Settings.dock.autohide ? "false" : "true"]); } }
    IpcHandler {
        target: "settings"
        function open(pane: string): void { settingsApp.open(pane); }
    }
    IpcHandler {
        target: "island"
        function test(activity: string): void { Shell.islandTest = activity || "recording"; }
        function commandDone(cmd: string, secs: string): void { Shell.islandTest = qsTr("Done: %1 (%2 s)").arg(cmd).arg(secs); }
    }

    // qs -c goldengate ipc call shell <function> [args]
    IpcHandler {
        target: "shell"
        function ping(): string { return "pong"; }
        // the accent and glass the shell is wearing, for gg and the tests
        function look(): string {
            return JSON.stringify({ mode: Theme.dark ? "dark" : "light", k: Theme.k, accent: Theme.accentName,
                                    accentColor: String(Theme.accent), glass: Theme.glassMode, clarity: Theme.clarity,
                                    backend: Glass.backend, font: Theme.fontUi });
        }
        // a banner, as the system shows one (gg uses it; so do the tests)
        function banner(title: string, body: string): void { banner.show(title, body); }
        function recording(on: bool): void { Shell.recording = on; }
        function dnd(on: bool): void { Shell.setDnd(on); }
        function open(name: string): void { Shell.toggle(name); }
        function opened(): string { return Shell.open; }
        // what Mission Control would lay out, for gg and the tests
        function windows(): string {
            return JSON.stringify(Windows.onWorkspace(Windows.activeWorkspace).map(w => ({ cls: w.class, title: w.title, ws: w.workspace.id, size: w.size })));
        }
        function caffeine(): void { Shell.caffeine = !Shell.caffeine; }
        // Spotlight with text already typed, e.g. "12*7" or "firefox"
        function search(text: string): void { Shell.searchText = text; Shell.open = "spotlight"; }
    }
}
