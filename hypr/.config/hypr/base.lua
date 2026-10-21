-- Base layer: everything that stays the same in every rice.
-- Keybinds, input, layout, autostart, and *which* windows are which.
-- How those windows look (opacity, borders, rounding) belongs to the rice:
-- this file only tags windows, and ~/.local/share/rice/active/hypr.lua
-- styles the tags.
--
-- Targets Hyprland 0.56 (Lua config).

local terminal = "kitty"
local files    = "nautilus"
-- your default browser (xdg-settings), else the first one installed
local browser  = [[sh -c 'd=$(xdg-settings get default-web-browser 2>/dev/null); ]]
              .. [[[ -n "$d" ] && gtk-launch "$d" 2>/dev/null && exit; ]]
              .. [[for b in firefox zen-browser brave chromium google-chrome-stable librewolf; do ]]
              .. [[command -v "$b" >/dev/null && exec "$b"; done']]
local mod      = "SUPER"

---------------------------------------------------------------------------
-- Environment
---------------------------------------------------------------------------
-- rice, rice-shot and rice-render live in ~/.local/bin, which a display
-- manager's session often leaves off PATH; without this every rice bind
-- (screenshots, lock, chooser) and `rice session` silently does nothing.
local localbin = os.getenv("HOME") .. "/.local/bin"
local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin:/bin"
if not (":" .. path .. ":"):find(":" .. localbin .. ":", 1, true) then
    hl.env("PATH", localbin .. ":" .. path)
end

-- Qt apps take their colours from qt6ct, which the installer points at the
-- rice's palette (drawn by the Fusion style)
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

---------------------------------------------------------------------------
-- Monitors (override per machine in local.lua)
---------------------------------------------------------------------------
-- any screen: its preferred mode at scale 1 (Hyprland's "auto" enlarges a
-- 1080p laptop panel); the laptop's own panel at 1080p and 60 Hz
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "0x0", scale = 1 })

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

-- four fingers sideways switches workspace (three are left to apps)
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

---------------------------------------------------------------------------
-- Keybinds
---------------------------------------------------------------------------
local function key(k) return mod .. " + " .. k end

-- Every bind is described as "Group · what it does". The shell's key sheet
-- (Super+/) reads these back from `hyprctl binds -j`, so this file is the
-- only list to keep up to date; binds in local.lua show up there too.
local function bind(keys, action, desc, flags)
    flags = flags or {}
    flags.description = desc
    hl.bind(keys, action, flags)
end

-- apps
bind(key("T"),      hl.dsp.exec_cmd(terminal), "Apps · Terminal")
bind(key("Return"), hl.dsp.exec_cmd(terminal), "Apps · Terminal")
bind(key("W"),      hl.dsp.exec_cmd(browser),  "Apps · Browser")
bind(key("E"),      hl.dsp.exec_cmd(files),    "Apps · Files")

-- shell surfaces: each rice's Quickshell registers these global shortcuts.
-- Super on its own fires on release, and only when no other key joined in,
-- so Super+anything still works as usual.
bind("SUPER + Super_L", hl.dsp.global("quickshell:launcher-tap"), "Shell · Launcher", { release = true })
bind(key("Space"),  hl.dsp.global("quickshell:launcher"),  "Shell · Launcher")
bind(key("V"),      hl.dsp.global("quickshell:clipboard"), "Shell · Clipboard history")
bind(key("N"),      hl.dsp.global("quickshell:center"),    "Shell · Control centre")
bind(key("slash"),  hl.dsp.global("quickshell:keybinds"),  "Shell · This key sheet")
bind(key("Escape"), hl.dsp.global("quickshell:power"),     "Shell · Power menu")
bind(key("L"),      hl.dsp.exec_cmd("rice lock"),         "Shell · Lock")

-- windows
bind(key("Q"),         hl.dsp.window.close(),                         "Windows · Close")
bind(key("F"),         hl.dsp.window.fullscreen({ action = "toggle" }), "Windows · Fullscreen")
bind(key("SHIFT + F"), hl.dsp.window.float({ action = "toggle" }),      "Windows · Float")
bind(key("P"),         hl.dsp.window.pseudo(),                        "Windows · Pseudo-tile")
bind(key("G"),         hl.dsp.group.toggle(),                         "Windows · Group")
bind(key("TAB"),       hl.dsp.group.next(),                           "Windows · Next in group")
bind(key("M"), function()
    local layout = hl.get("general.layout")
    hl.config({ general = { layout = (layout == "master") and "dwindle" or "master" } })
end, "Windows · Dwindle ⇄ master")

-- focus and move: Super+HJK / arrows, + Shift moves the window. Super+L
-- locks, so focusing right is the arrow alone (Super+Shift+L still moves).
local dirs = { { "h", "left" }, { "left", "left" }, { "j", "down" }, { "down", "down" },
               { "k", "up" }, { "up", "up" }, { "l", "right" }, { "right", "right" } }
for _, d in ipairs(dirs) do
    local k, dir = d[1], d[2]
    if k ~= "l" then
        bind(key(k), hl.dsp.focus({ direction = dir }), "Windows · Focus " .. dir)
    end
    bind(key("SHIFT + " .. k), hl.dsp.window.move({ direction = dir }), "Windows · Move " .. dir)
end

-- workspaces 1–5
for i = 1, 5 do
    bind(key(tostring(i)),               hl.dsp.focus({ workspace = i }),       "Workspaces · Go to workspace")
    bind(key("SHIFT + " .. tostring(i)), hl.dsp.window.move({ workspace = i }), "Workspaces · Send window to it")
end
bind(key("mouse_down"), hl.dsp.focus({ workspace = "e+1" }), "Workspaces · Next")
bind(key("mouse_up"),   hl.dsp.focus({ workspace = "e-1" }), "Workspaces · Previous")
bind(key("S"),         hl.dsp.workspace.toggle_special("scratch"),          "Workspaces · Scratchpad")
bind(key("SHIFT + S"), hl.dsp.window.move({ workspace = "special:scratch" }), "Workspaces · Send to scratchpad")

-- capture
bind("Print",          hl.dsp.exec_cmd("rice-shot region"), "Capture · Screenshot a region")
bind("SHIFT + Print",  hl.dsp.exec_cmd("rice-shot screen"), "Capture · Screenshot the screen")
bind(key("Print"),     hl.dsp.exec_cmd("rice-shot window"), "Capture · Screenshot the window")
bind("CTRL + Print",   hl.dsp.exec_cmd("rice-shot edit"),   "Capture · Screenshot and edit")
bind(key("SHIFT + C"), hl.dsp.exec_cmd("hyprpicker -a"),    "Capture · Pick a colour")
bind(key("SHIFT + R"), hl.dsp.exec_cmd("rice-rec toggle screen"), "Capture · Record the screen (again to stop)")
bind(key("ALT + R"),   hl.dsp.exec_cmd("rice-rec toggle region"), "Capture · Record a region (again to stop)")

-- rices
bind(key("SHIFT + T"), hl.dsp.exec_cmd("rice choose"), "Rice · Rice chooser")
bind(key("CTRL + T"),  hl.dsp.exec_cmd("rice next"),   "Rice · Next rice")
-- the rice's screen shader (Paper's grain) blocks direct scanout; games and
-- video may want it off. Off is remembered; rices without one ignore it.
bind(key("SHIFT + G"), hl.dsp.exec_cmd("rice grain toggle"), "Rice · Paper grain on/off")
-- light and dark: the same everywhere (Paper's lamp, Nacre's black pearl)
bind(key("ALT + D"),         hl.dsp.exec_cmd("rice mode toggle"), "Rice · Light/dark")
bind(key("ALT + SHIFT + D"), hl.dsp.exec_cmd("rice mode auto"),   "Rice · Light and dark by the sun (auto)")

-- mouse
bind(key("mouse:272"), hl.dsp.window.drag(),   "Mouse · Move window",   { mouse = true })
bind(key("mouse:273"), hl.dsp.window.resize(), "Mouse · Resize window", { mouse = true })

-- media keys (the shell's OSD reacts to the change itself)
local function held() return { locked = true, repeating = true } end
local function locked() return { locked = true } end
bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), "Media · Volume up", held())
bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      "Media · Volume down", held())
bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     "Media · Mute", locked())
bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   "Media · Mute the mic", locked())
bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), "Media · Brightness up", held())
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), "Media · Brightness down", held())
bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), "Media · Play / pause", locked())
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), "Media · Play / pause", locked())
bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       "Media · Next track", locked())
bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   "Media · Previous track", locked())

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
hl.layer_rule({ name = "rice-chooser", match = { namespace = "^rice-chooser$" }, blur = true, ignore_alpha = 0.2, no_anim = true })
hl.layer_rule({ name = "rice-freeze",  match = { namespace = "^rice-freeze$" },  no_anim = true })
