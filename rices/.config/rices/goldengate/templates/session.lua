-- Golden Gate: how the desktop behaves while it's the active rice. Generated
-- by rice-render; hypr.lua loads it on every reload, so a switch to any other
-- rice (a reload) drops all of it and base.lua's binds are back as they were.
--
-- Windows float, centred, as on the Mac (Settings → Desktop & Dock can make
-- them tile: gg set windows.layout '"tiled"'); its own binds, with ⌘ as
-- Super and no global Ctrl grabs, so apps keep Ctrl+arrows, Ctrl+1–9, F4 and
-- F11; the trackpad's gestures; minimize, hide and Show Desktop on special
-- workspaces; and the traffic lights (hyprbars) on windows that draw none.
-- What a bind or the shell asks of a window is a GG.* function, so `gg win`
-- and the Dock call the same ones (hyprctl eval "GG.minimize()").

local state = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/goldengate/"
local ok, S = pcall(dofile, state .. "session-state.lua")   -- written by gg
if not ok or type(S) ~= "table" then S = {} end

GG = {}

---------------------------------------------------------------------------
-- Windows
---------------------------------------------------------------------------
local function sel(w) return "address:" .. w.address end
local function run(d) hl.dispatch(d) end
local function same_app(a, b) return a.class == b.class end
-- windows on ordinary workspaces (not minimized, hidden or put away)
local function regular(w) return w.mapped and w.workspace and not w.workspace.special end

local function app_windows(class)
    local out = {}
    for _, w in ipairs(hl.get_windows()) do
        if w.class == class then out[#out + 1] = w end
    end
    table.sort(out, function(a, b) return a.stable_id < b.stable_id end)
    return out
end

-- apps that draw their own title bar and buttons (GTK and libadwaita with
-- MacTahoe's, browsers, Electron apps): no hyprbars on them
local own_bar = { "nautilus", "firefox", "zen", "librewolf", "chromium", "google-chrome", "brave-browser",
                  "code", "Code", "code-oss", "com.anthropic.Claude", "vesktop", "discord", "obsidian",
                  "com.mitchellh.ghostty", "xdg-desktop-portal-gtk" }
local own_bar_prefix = { "org.gnome.", "gnome-" }
local function has_bar(w)
    if not hl.plugin.hyprbars then return false end
    for _, t in ipairs(w.tags or {}) do
        if t:match("^dialog") or t:match("^pip") then return false end
    end
    for _, c in ipairs(own_bar) do if w.class == c then return false end end
    for _, p in ipairs(own_bar_prefix) do if w.class:sub(1, #p) == p then return false end end
    return true
end
local bar_height = 30

-- where a minimized or hidden window came from (until the next reload)
GG.from = {}

local function put_away(w, where)
    if w.workspace and not w.workspace.special then GG.from[w.address] = w.workspace.id end
    run(hl.dsp.window.move({ workspace = "special:" .. where, follow = false, window = sel(w) }))
end
local function bring_back(w)
    local ws = hl.get_active_workspace()
    run(hl.dsp.window.move({ workspace = ws.id, follow = false, window = sel(w) }))
    GG.from[w.address] = nil
end

function GG.close() run(hl.dsp.window.close()) end

-- ⌘Q: every window of the app (each can still ask about unsaved work)
function GG.quit()
    local a = hl.get_active_window()
    if not a then return end
    for _, w in ipairs(app_windows(a.class)) do run(hl.dsp.window.close({ window = sel(w) })) end
end

-- the window switcher's choice: focused and on top of the floating ones
function GG.raise(address)
    local w = hl.get_window("address:" .. address)
    if not w then return end
    run(hl.dsp.focus({ window = sel(w) }))
    run(hl.dsp.window.bring_to_top({ window = sel(w) }))
end

-- the Dock's Quit: every window of one app, wherever they are
function GG.quit_app(class)
    for _, w in ipairs(app_windows(class)) do run(hl.dsp.window.close({ window = sel(w) })) end
end

-- ⌘M: into special:minimized (the Dock shows it and brings it back)
function GG.minimize(address)
    local w = address and hl.get_window("address:" .. address) or hl.get_active_window()
    if w and regular(w) then put_away(w, "minimized") end
end

-- a minimized or hidden window, back on the workspace in front, focused
function GG.restore(address)
    local w = hl.get_window("address:" .. address)
    if not w then return end
    bring_back(w)
    run(hl.dsp.focus({ window = sel(w) }))
end

-- ⌘H: every window of the app into special:hidden; ⌥⌘H: every other app's
function GG.hide(class)
    local a = hl.get_active_window()
    class = class or (a and a.class)
    if not class then return end
    for _, w in ipairs(app_windows(class)) do
        if regular(w) then put_away(w, "hidden") end
    end
end
function GG.hide_others()
    local a = hl.get_active_window()
    if not a then return end
    local ws = hl.get_active_workspace()
    for _, w in ipairs(hl.get_windows()) do
        if regular(w) and not same_app(w, a) and w.workspace.id == ws.id then put_away(w, "hidden") end
    end
end
-- the app's hidden windows back (a click on its Dock icon)
function GG.unhide(class)
    for _, w in ipairs(app_windows(class)) do
        if w.workspace and w.workspace.name == "special:hidden" then bring_back(w) end
    end
end
-- Show All: everything hidden or minimized comes back
function GG.show_all()
    for _, w in ipairs(hl.get_windows()) do
        local n = w.workspace and w.workspace.name
        if n == "special:hidden" or n == "special:minimized" then bring_back(w) end
    end
end

-- Show Desktop: the workspace's windows step aside, and come back together
GG.desk = nil
function GG.desktop()
    if GG.desk then
        for _, a in ipairs(GG.desk.windows) do
            local w = hl.get_window("address:" .. a)
            if w and w.workspace and w.workspace.name == "special:desktop" then
                run(hl.dsp.window.move({ workspace = GG.desk.workspace, follow = false, window = sel(w) }))
            end
        end
        GG.desk = nil
        return
    end
    local ws = hl.get_active_workspace()
    local moved = {}
    for _, w in ipairs(hl.get_windows()) do
        if regular(w) and w.workspace.id == ws.id then
            moved[#moved + 1] = w.address
            run(hl.dsp.window.move({ workspace = "special:desktop", follow = false, window = sel(w) }))
        end
    end
    if #moved > 0 then GG.desk = { workspace = ws.id, windows = moved } end
end

-- ⌘`: the next window of the same app
function GG.cycle()
    local a = hl.get_active_window()
    if not a then return end
    local list = {}
    for _, w in ipairs(app_windows(a.class)) do if regular(w) then list[#list + 1] = w end end
    for i, w in ipairs(list) do
        if w.address == a.address then
            run(hl.dsp.focus({ window = sel(list[i % #list + 1]) }))
            return
        end
    end
end

---------------------------------------------------------------------------
-- Tiling a floating window: halves, then quarters (press a second arrow),
-- Fill and Center, inside the screen less the bars and the outer gap
---------------------------------------------------------------------------
GG.tiled = {}
local gap = {{ shape.gaps_out }}

local function area(w)
    local m = w.monitor
    local r = m.reserved
    return m.x + r.left + gap, m.y + r.top + gap,
           m.width - r.left - r.right - 2 * gap, m.height - r.top - r.bottom - 2 * gap
end

-- x, y, width, height of the whole window, its title bar included
local function place(w, x, y, width, height)
    if has_bar(w) then y = y + bar_height; height = height - bar_height end
    if not w.floating then run(hl.dsp.window.float({ action = "enable", window = sel(w) })) end
    run(hl.dsp.window.resize({ x = math.floor(width), y = math.floor(height), window = sel(w) }))
    run(hl.dsp.window.move({ x = math.floor(x), y = math.floor(y), window = sel(w) }))
end

-- a half, or the quarter where two halves meet
local corner = {
    left  = { up = "topleft", down = "bottomleft" },
    right = { up = "topright", down = "bottomright" },
    up    = { left = "topleft", right = "topright" },
    down  = { left = "bottomleft", right = "bottomright" },
}
local shapes = {   -- x, y, w, h as fractions of the area
    left = { 0, 0, 0.5, 1 }, right = { 0.5, 0, 0.5, 1 }, up = { 0, 0, 1, 0.5 }, down = { 0, 0.5, 1, 0.5 },
    topleft = { 0, 0, 0.5, 0.5 }, topright = { 0.5, 0, 0.5, 0.5 },
    bottomleft = { 0, 0.5, 0.5, 0.5 }, bottomright = { 0.5, 0.5, 0.5, 0.5 },
    fill = { 0, 0, 1, 1 },
}

function GG.tile(dir)
    local w = hl.get_active_window()
    if not w or w.fullscreen ~= 0 then return end
    local was = GG.tiled[w.address]
    local to = (was and corner[was] and corner[was][dir]) or dir
    local s = shapes[to]
    if not s then return end
    -- edges inside the area give up half a gap each: one gap between tiles
    local ax, ay, aw, ah = area(w)
    local half = gap / 2
    local x0, x1 = ax + s[1] * aw, ax + (s[1] + s[3]) * aw
    local y0, y1 = ay + s[2] * ah, ay + (s[2] + s[4]) * ah
    if s[1] > 0 then x0 = x0 + half end
    if s[1] + s[3] < 1 then x1 = x1 - half end
    if s[2] > 0 then y0 = y0 + half end
    if s[2] + s[4] < 1 then y1 = y1 - half end
    local x, y, width, height = x0, y0, x1 - x0, y1 - y0
    place(w, x, y, width, height)
    GG.tiled[w.address] = to
end
function GG.fill() GG.tile("fill") end
function GG.center()
    local w = hl.get_active_window()
    if not w then return end
    if not w.floating then run(hl.dsp.window.float({ action = "enable", window = sel(w) })) end
    run(hl.dsp.window.center({ window = sel(w) }))
    GG.tiled[w.address] = nil
end
-- the green light: full screen, and back
function GG.zoom() run(hl.dsp.window.fullscreen({ action = "toggle" })) end

---------------------------------------------------------------------------
-- Layout: floating first, centred, as on the Mac
---------------------------------------------------------------------------
if (S.layout or "floating") == "floating" then
    hl.window_rule({ name = "goldengate-float", match = { class = ".*" }, float = true, center = true })
    -- a window asking for more than the screen (a remembered size, a
    -- maximised one) opens at a Mac's size instead, title bar and all
    hl.on("window.open", function(w)
        if not (w and w.floating) or w.fullscreen ~= 0 then return end
        for _, t in ipairs(w.tags or {}) do
            if t:match("^dialog") or t:match("^pip") or t:match("^game") then return end
        end
        local _, _, aw, ah = area(w)
        if has_bar(w) then ah = ah - bar_height end
        if w.size.x <= aw and w.size.y <= ah then return end
        run(hl.dsp.window.resize({ x = math.floor(math.min(w.size.x, aw * 0.72)),
                                   y = math.floor(math.min(w.size.y, ah * 0.8)), window = sel(w) }))
        run(hl.dsp.window.center({ window = sel(w) }))
    end)
end

---------------------------------------------------------------------------
-- Binds: base.lua's that the Mac uses for something else go first
---------------------------------------------------------------------------
local function key(k) return "SUPER + " .. k end
local function bind(keys, action, desc, flags)
    flags = flags or {}
    flags.description = desc
    pcall(hl.unbind, keys)
    hl.bind(keys, action, flags)
end
local function gg(args) return hl.dsp.exec_cmd("gg " .. args) end
-- ⌘3–5 are screenshots here: base sends windows to workspaces 3–5 with them
for _, k in ipairs({ "SHIFT + 3", "SHIFT + 4", "SHIFT + 5" }) do pcall(hl.unbind, key(k)) end

-- apps and windows
bind(key("Q"),           GG.quit,        "Windows · Quit the app")
bind(key("W"),           GG.close,       "Windows · Close the window")
bind(key("H"),           function() GG.hide() end, "Windows · Hide the app")
bind(key("ALT + H"),     GG.hide_others, "Windows · Hide the others")
bind(key("M"),           function() GG.minimize() end, "Windows · Minimize")
bind(key("SHIFT + M"),   GG.show_all,    "Windows · Show all (hidden and minimized)")
bind(key("CTRL + F"),    GG.zoom,        "Windows · Full screen")
bind(key("grave"),       GG.cycle,       "Windows · Next window of the app")
for _, d in ipairs({ { "left", "left" }, { "right", "right" }, { "up", "up" }, { "down", "down" } }) do
    bind(key("CTRL + " .. d[1]), function() GG.tile(d[2]) end, "Windows · Tile " .. d[2] .. " (again: a quarter)")
end
bind(key("CTRL + Return"), GG.fill,   "Windows · Fill")
bind(key("CTRL + C"),      GG.center, "Windows · Center")
-- until the app switcher (the shell's), ⌘Tab steps through windows
bind(key("TAB"),         hl.dsp.window.cycle_next(),                    "Windows · Next app")
bind(key("SHIFT + TAB"), hl.dsp.window.cycle_next({ next = false }),    "Windows · Previous app")
-- ⌥Tab: the shell's window switcher, this Space's windows, most recent first
bind("ALT + TAB",         hl.dsp.global("quickshell:switcher"),      "Windows · Switch windows (this Space)")
bind("ALT + SHIFT + TAB", hl.dsp.global("quickshell:switcher-back"), "Windows · Switch windows, backwards")

-- Spaces, Mission Control, Desktop
bind(key("ALT + left"),  hl.dsp.focus({ workspace = "m-1" }), "Spaces · Previous")
bind(key("ALT + right"), hl.dsp.focus({ workspace = "m+1" }), "Spaces · Next")
for i = 1, 9 do
    bind(key("ALT + " .. i),         hl.dsp.focus({ workspace = i }),       "Spaces · Go to space")
    bind(key("ALT + SHIFT + " .. i), hl.dsp.window.move({ workspace = i }), "Spaces · Send the window there")
end
bind(key("ALT + up"),   gg("mission"), "Spaces · Mission Control")
bind(key("ALT + down"), gg("expose"),  "Spaces · App Exposé")
bind(key("F4"),         gg("apps"),    "Spaces · Apps")
bind(key("F11"),        GG.desktop,    "Spaces · Show Desktop")

-- the shell
bind(key("N"),          gg("nc"),         "Shell · Notification Center")
bind(key("comma"),      gg("settings"),   "Shell · System Settings")
bind(key("CTRL + Q"),   gg("lock"),       "Shell · Lock Screen")
bind(key("ALT + G"),    gg("glass next"), "Shell · Glass: Liquid, Frosted, Solid")

-- capture, as on the Mac
bind(key("SHIFT + 3"), gg("screenshot screen"),    "Capture · Screenshot the screen")
bind(key("SHIFT + 4"), gg("screenshot selection"), "Capture · Screenshot a selection")
bind(key("SHIFT + 5"), gg("screenshot toolbar"),   "Capture · Screenshot and recording toolbar")

---------------------------------------------------------------------------
-- Gestures: three fingers sideways for Spaces, four up and down for Mission
-- Control and App Exposé, a pinch for Apps, a spread for the desktop
---------------------------------------------------------------------------
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
local function later(args) return function() run(gg(args)) end end
hl.gesture({ fingers = 4, direction = "up",       action = later("mission") })
hl.gesture({ fingers = 4, direction = "down",     action = later("expose") })
hl.gesture({ fingers = 4, direction = "pinchin",  action = later("apps") })
hl.gesture({ fingers = 4, direction = "pinchout", action = GG.desktop })

---------------------------------------------------------------------------
-- The traffic lights: hyprbars (loaded by gg) on windows that draw none.
-- GTK and libadwaita apps (MacTahoe's buttons), browsers and Electron apps
-- with their own title bars, dialogs and picture-in-picture go without.
-- Its colours by the light are in hypr-mode.lua.
---------------------------------------------------------------------------
-- once per reload: loading hyprbars reloads the config itself, and gg asks
-- again after loading it
function GG.bars()
    if not hl.plugin.hyprbars or GG.barred then return end
    GG.barred = true
    hl.config({ plugin = { hyprbars = {
        enabled                    = true,
        bar_height                 = bar_height,
        bar_part_of_window         = true,
        bar_precedence_over_border = true,
        bar_title_enabled          = true,
        bar_text_font              = "{{ fonts.ui }}",
        bar_text_size              = 13,
        bar_text_align             = "center",
        bar_buttons_alignment      = "left",
        bar_padding                = 12,
        bar_button_padding         = 8,
        icon_on_hover              = true,
        on_double_click            = "gg win fill",
    } } })
    -- left to right (the first added is the outermost): close, minimize, zoom
    for _, b in ipairs({
        { "{{ colors.close | hypr(ff) }}",    "×", "gg win close" },
        { "{{ colors.minimize | hypr(ff) }}", "−", "gg win minimize" },
        { "{{ colors.zoom | hypr(ff) }}",     "+", "gg win zoom" },
    }) do
        hl.plugin.hyprbars.add_button({ bg_color = b[1], fg_color = "{{ colors.shadow | hypr(0.5) }}", size = 13, icon = b[2], action = b[3] })
    end
    local function rx(t, suffix)
        local out = {}
        for _, c in ipairs(t) do out[#out + 1] = c:gsub("[%.%-]", "\\%0") .. (suffix or "") end
        return out
    end
    local names = rx(own_bar)
    for _, p in ipairs(rx(own_bar_prefix, ".*")) do names[#names + 1] = p end
    hl.window_rule({
        name = "goldengate-own-bar",
        match = { class = "^(" .. table.concat(names, "|") .. ")$" },
        ["hyprbars:no_bar"] = true,
    })
    for _, t in ipairs({ "dialog", "pip" }) do
        hl.window_rule({ name = "goldengate-nobar-" .. t, match = { tag = t }, ["hyprbars:no_bar"] = true })
    end
end
GG.bars()
