-- Base layer: everything that stays the same in every rice.
-- Keybinds, input, layout, autostart, and *which* windows are which.
-- How those windows look (opacity, borders, rounding) belongs to the rice:
-- this file only tags windows, and ~/.config/rices/current/build/hypr.lua
-- styles the tags.
--
-- Targets Hyprland 0.56 (Lua config).

local terminal = "kitty"
local files    = "nautilus"
local mod      = "SUPER"

---------------------------------------------------------------------------
-- Monitors (override per machine in local.lua)
---------------------------------------------------------------------------
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

---------------------------------------------------------------------------
-- Autostart
---------------------------------------------------------------------------
hl.on("hyprland.start", function()
    -- systemd user units (the rice auto-mode timer) need the session env
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
    -- shared shell: rice chooser + switch overlay; survives rice switches
    hl.exec_cmd("qs -c rice -d")
    -- start the active rice's shell, wallpaper and themes
    hl.exec_cmd("rice session")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprsunset")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

---------------------------------------------------------------------------
-- Input and layout
---------------------------------------------------------------------------
hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad     = { natural_scroll = true },
    },
    general = {
        layout        = "dwindle",
        allow_tearing = true,   -- only windows tagged "game" actually tear
        resize_on_border = true,
    },
    dwindle = { preserve_split = true },
    master  = { new_status = "master" },
    misc = {
        disable_hyprland_logo   = true,
        force_default_wallpaper = 0,
        focus_on_activate       = true,
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

---------------------------------------------------------------------------
-- Keybinds
---------------------------------------------------------------------------
local function key(k) return mod .. " + " .. k end

hl.bind(key("Return"), hl.dsp.exec_cmd(terminal))
hl.bind(key("E"),      hl.dsp.exec_cmd(files))
hl.bind(key("Q"),      hl.dsp.window.close())
hl.bind(key("F"),      hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(key("SHIFT + F"), hl.dsp.window.float({ action = "toggle" }))
hl.bind(key("P"),      hl.dsp.window.pseudo())
hl.bind(key("G"),      hl.dsp.group.toggle())
hl.bind(key("TAB"),    hl.dsp.group.next())

-- shell surfaces: each rice's Quickshell registers these global shortcuts
hl.bind(key("Space"),  hl.dsp.global("quickshell:launcher"))
hl.bind(key("N"),      hl.dsp.global("quickshell:center"))
hl.bind(key("V"),      hl.dsp.global("quickshell:clipboard"))
hl.bind(key("Escape"), hl.dsp.global("quickshell:power"))
hl.bind(key("CTRL + L"), hl.dsp.exec_cmd("rice lock"))

-- rices
hl.bind(key("T"),         hl.dsp.exec_cmd("rice choose"))
hl.bind(key("SHIFT + T"), hl.dsp.exec_cmd("rice next"))

-- capture
hl.bind("Print",               hl.dsp.exec_cmd("rice-shot region"))
hl.bind("SHIFT + Print",       hl.dsp.exec_cmd("rice-shot screen"))
hl.bind(key("Print"),          hl.dsp.exec_cmd("rice-shot window"))
hl.bind("CTRL + Print",        hl.dsp.exec_cmd("rice-shot edit"))
hl.bind(key("SHIFT + C"),      hl.dsp.exec_cmd("hyprpicker -a"))

-- toggle dwindle ⇄ master
hl.bind(key("M"), function()
    local layout = hl.get("general.layout")
    hl.config({ general = { layout = (layout == "master") and "dwindle" or "master" } })
end)

-- focus and move: Super+HJKL / arrows, + Shift moves the window
local dirs = { h = "left", j = "down", k = "up", l = "right",
               left = "left", down = "down", up = "up", right = "right" }
for k, dir in pairs(dirs) do
    hl.bind(key(k),            hl.dsp.focus({ direction = dir }))
    hl.bind(key("SHIFT + " .. k), hl.dsp.window.move({ direction = dir }))
end

-- workspaces 1–5
for i = 1, 5 do
    hl.bind(key(tostring(i)),             hl.dsp.focus({ workspace = i }))
    hl.bind(key("SHIFT + " .. tostring(i)), hl.dsp.window.move({ workspace = i }))
end
hl.bind(key("mouse_down"), hl.dsp.focus({ workspace = "e+1" }))
hl.bind(key("mouse_up"),   hl.dsp.focus({ workspace = "e-1" }))

-- scratchpad
hl.bind(key("S"),         hl.dsp.workspace.toggle_special("scratch"))
hl.bind(key("SHIFT + S"), hl.dsp.window.move({ workspace = "special:scratch" }))

-- mouse
hl.bind(key("mouse:272"), hl.dsp.window.drag(),   { mouse = true })
hl.bind(key("mouse:273"), hl.dsp.window.resize(), { mouse = true })

-- media keys (the shell's OSD reacts to the change itself)
local held = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), held)
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), held)
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), held)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), held)
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

---------------------------------------------------------------------------
-- Window classes → tags (the rice decides what each tag looks like)
--   opaque  browsers, video, image viewers, games, editors: always 1.0
--   glassy  terminals, file manager, music, system tools
--   dialog  small floating tools, centred at 60%
--   pip     picture-in-picture
--   game    tearing allowed, no animations or blur
---------------------------------------------------------------------------
local function tag(name, match)
    hl.window_rule({ name = "tag-" .. name .. "-" .. (match.class or match.title or match.content or "x"),
                     match = match, tag = "+" .. name })
end

for _, class in ipairs({
    "^(firefox|librewolf|zen|chromium|google-chrome|brave-browser|vivaldi-stable)$",
    "^(mpv|vlc|celluloid|io.github.celluloid_player.Celluloid)$",
    "^(imv|swayimg|org.gnome.Loupe|feh|gimp|org.inkscape.Inkscape|krita)$",
    "^(code|code-oss|Code|codium|VSCodium|jetbrains-.*|dev.zed.Zed|neovide)$",
    "^(org.pwmt.zathura|org.gnome.Papers|evince|libreoffice-.*)$",
}) do tag("opaque", { class = class }) end
tag("opaque", { content = "video" })
tag("opaque", { content = "photo" })

for _, class in ipairs({
    "^(kitty|foot|Alacritty|com.mitchellh.ghostty|org.wezfurlong.wezterm)$",
    "^(org.gnome.Nautilus|thunar|Thunar|pcmanfm|yazi)$",
    "^(spotify|Spotify|tidal-hifi|io.bassi.Amberol|org.gnome.Music|feishin)$",
    "^(btop|htop|org.gnome.SystemMonitor|org.gnome.Settings|nwg-look|qt6ct|kvantummanager)$",
}) do tag("glassy", { class = class }) end

for _, class in ipairs({
    "^(org.pulseaudio.pavucontrol|pavucontrol|com.saivert.pwvucontrol)$",
    "^(blueman-manager|.blueman-manager-wrapped|nm-connection-editor)$",
    "^(hyprpolkitagent|polkit-gnome-authentication-agent-1|org.kde.polkit-kde-authentication-agent-1)$",
    "^(xdg-desktop-portal-gtk|xdg-desktop-portal-gnome|org.freedesktop.impl.portal.desktop.kde)$",
}) do tag("dialog", { class = class }) end
tag("dialog", { title = "^(Open File|Open Files|Save File|Save As|Select a File|File Upload).*" })

tag("pip", { title = "^(Picture-in-Picture|Picture in picture)$" })

for _, class in ipairs({
    "^(steam_app_.*|gamescope|Minecraft.*|org.prismlauncher.PrismLauncher|.*\\.exe)$",
}) do tag("game", { class = class }) end
tag("game", { content = "game" })

-- behaviour of tagged windows (placement, not looks)
hl.window_rule({
    name = "dialog-float", match = { tag = "dialog" },
    float = true, center = true, size = { "monitor_w*0.6", "monitor_h*0.6" },
})
hl.window_rule({
    name = "pip-float", match = { tag = "pip" },
    float = true, pin = true, keep_aspect_ratio = true,
    size = { "monitor_w*0.25", "monitor_h*0.25" },
    move = { "monitor_w-window_w-24", "monitor_h-window_h-24" },
})
hl.window_rule({
    name = "game-tear", match = { tag = "game" },
    immediate = true, idle_inhibit = "fullscreen",
})
hl.window_rule({ name = "fullscreen-inhibit", match = { fullscreen = true }, idle_inhibit = "fullscreen" })
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })

---------------------------------------------------------------------------
-- Shared shell surfaces (rice chooser and switch overlay)
---------------------------------------------------------------------------
hl.layer_rule({ name = "rice-chooser", match = { namespace = "^rice-chooser$" }, blur = true, ignore_alpha = 0.3, no_anim = true })
hl.layer_rule({ name = "rice-freeze",  match = { namespace = "^rice-freeze$" },  no_anim = true })
