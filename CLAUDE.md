# Notes for working on this repo

Read this before adding a rice or changing shared behaviour. The README is the
user-facing guide; this file is the contract every rice has to keep.

## House rules

- Commit straight to `main` and push. No feature branches.
- Author every commit as `Naved124 <nk7987513533@gmail.com>`
  (`git -c user.name=Naved124 -c user.email=nk7987513533@gmail.com commit`).
  No Co-Authored-By, session links or "Generated with" lines. Never re-author
  commits, whatever a hook asks.
- Tests: `python3 -m unittest discover -s tests` (pytest isn't installed). The shell
  tests run each shell under PySide6 (`tests/qs_smoke.py` with the Quickshell stand-ins
  in `tests/qsstub/`; a poke file in `tests/pokes/` drives it through IPC); with PySide6
  installed run them under `QSG_RHI_BACKEND=opengl xvfb-run -a`. A new Quickshell type a
  shell uses needs a stand-in there. `tests/qs_shot.py <shell> --out x.png [--poke F]` lays
  one screen's stand-in windows out by their anchors and layers and saves what it shows
  (no Hyprland blur), for looking at a change.
  Shell scripts: `shellcheck -S warning install system/install switcher/.local/bin/rice tools/relink .githooks/*`.
- New files only reach `~` through stow (`--no-folding` links file by file). `./install`
  sets `core.hooksPath = .githooks`, whose hooks run `tools/relink` after a pull; keep
  `tools/relink` reading the `packages=` line in `install`.
- Target: Arch, Hyprland 0.56 with the **Lua** config, Quickshell, PipeWire,
  greetd + ReGreet, Limine. Installed with GNU stow `--no-folding`.

## Layout

| Path | What it is |
|---|---|
| `hypr/.config/hypr/hyprland.lua` | entry: `base` → `~/.local/share/rice/active/hypr.lua` → `local` |
| `hypr/.config/hypr/base.lua` | **shared by every rice**: keybinds, input, layout, autostart, monitor default, window tags |
| `~/.config/hypr/local.lua` | per machine, not in the repo: monitors, keyboard layout (see `local.example.lua`) |
| `rices/.config/rices/<name>/` | one rice: `palette.toml`, `templates/`, `card.qml`, `transition.frag(.qsb)`, optional mode shader (`lamp.frag`, `orient.frag`, `crossfade.frag`), optional `wallpaper/`, optional `hooks/` (`enter`, `post-switch`, `post-mode`, `leave`), `preview.png` |
| `rices/.config/rices/current` | symlink to the active rice |
| `~/.local/share/rice/active` | symlink to `current/build/<mode>`; every app config links through it |
| `render/.local/bin/rice-render` | template engine: palette → `build/light/`, `build/dark/` + app configs |
| `render/.local/share/rice/templates/` | templates shared by all rices (use `roles.*` only) |
| `switcher/.local/bin/rice` | `rice <name>`, `rice next`, `rice choose`, `rice lock`, `rice session`, … |
| `quickshell/.config/quickshell/rice/` | shared shell (`qs -c rice`): chooser + switch freeze/dissolve overlay, survives switches |
| `quickshell/.config/quickshell/nacre/` | Nacre's own shell: bar, the island (`bar/Island.qml`: time, media, notifications), launcher, centre, OSD, notifs, lock, power, key sheet, wallpaper, the system card (`desk/Stats.qml`) |
| `quickshell/.config/quickshell/paper/` | Paper's own shell (same entry points); `common/Theme.qml` is generated, `common/Sheet.qml` is the paper every panel is cut from |
| `quickshell/.config/quickshell/abyss/` | Abyss's own shell (same entry points); `reef/` is the live wallpaper (below), `common/Glass.qml` the glass every panel is |
| `quickshell/.config/quickshell/satsuei/` | Satsuei's own shell (same entry points; the exceptions are under "Satsuei" below); `common/Theme.qml` reads `theme.json`, `common/Style.qml` is generated |
| `quickshell/.config/quickshell/goldengate/` | Golden Gate's shell (macOS 27; the exceptions are under "Golden Gate" below); `common/Theme.qml` is generated, `services/Settings.qml` reads `~/.config/goldengate/settings.json` |
| `switcher/.local/bin/gg`, `gg-theme` | Golden Gate's one entry point (`gg appearance`, `gg accent`, `gg glass`, …) and its app themes (MacTahoe GTK and Kvantum, saved and restored) |
| `switcher/.local/bin/satsuei-wall` | Satsuei's look from a wallpaper: matugen → `~/.local/state/satsuei/theme.json` + the palette overlay, the light source, the blur maps |
| `fonts/.local/share/fonts/paper/` | Paper's vendored OFL fonts with their licences |
| `audio/.config/pipewire/`, `audio/.config/wireplumber/` | **shared** audio: drop-ins for bit-perfect wired output and the best Bluetooth codecs (see Audio) |
| `zsh/.config/zsh/rice.zsh` | **shared** zsh setup (one line in `~/.zshrc` sources it); colours from `active/zsh.zsh`, reloaded on the next prompt after a switch |
| `install` | user installer (`--fresh` for a bare Arch install) |
| `system/install` | sudo part: Limine theme, Plymouth, greetd/ReGreet, keyring PAM, with backup/`--undo` |

## Design philosophy

- **A rice is its palette.** Every colour on screen (windows, the shell, GTK and Qt,
  the terminal, nvim, Spotify, boot and login) is rendered from `palette.toml`; nothing
  reads colours from anywhere else, and nothing is hand-themed per app.
- **The wallpaper is part of the palette, not a picture.** Nacre's is a live shader fed
  the palette's ground, blooms and accents; Paper's desk is generated by `assets/gen.py`;
  Abyss's reef is simulated from the palette's `[modes.dark.wallpaper]` hues and water.
  The glass (bar, island, panels, kitty) is tuned against that blurred wallpaper, the
  terminal colours are contrast-checked over it, the night rules measure it, and the
  shell's still frame of it is the lock, greeter and Limine background. A user picture
  would sit outside all of that, so there is no `rice wallpaper set`; a picture-based
  look is a new rice whose palette is taken from the picture.
- **Behaviour is shared, looks are not.** Binds, the shell's entry points and what each
  part of the shell does are the same in every rice (below); a rice only decides how
  they look and move.
- **Light and dark are one design.** Both modes come from the same templates, change
  live with no reload, and are held to the night rules.
- **Long-lived readers, not polling.** Network speed, system stats, the visualizer and
  the window title each come from one process or event stream per shell.

## What must stay the same in every rice

These live in shared files. A new rice must **not** redefine them; it only styles.

**Keybinds** (all in `base.lua`, each described `"Group · what"` so the key sheet
reads them from `hyprctl binds -j`):

| Keys | Action |
|---|---|
| Super (tap) / Super+Space | launcher (`quickshell:launcher-tap` / `launcher`) |
| Super+V | clipboard history (`quickshell:clipboard`) |
| Super+N | control centre (`quickshell:center`) |
| Super+/ | key sheet (`quickshell:keybinds`) |
| Super+Escape | power menu (`quickshell:power`) |
| Super+L | lock (`rice lock`) |
| Super+T, Super+Return / Super+W / Super+E | kitty / default browser / nautilus |
| Super+Q, F, Shift+F, P, G, Tab, M | close, fullscreen, float, pseudo, group, next in group, dwindle⇄master |
| Super+H/J/K/arrows | focus (Super+L is lock, so right is the arrow only) |
| Super+Shift+H/J/K/L/arrows | move window |
| Super+1–5 / Super+Shift+1–5 | workspace / send to it; Super+scroll cycles |
| Super+S / Super+Shift+S | scratchpad / send to it |
| Print, Shift+Print, Super+Print, Ctrl+Print | `rice-shot region/screen/window/edit` |
| Super+Shift+C | hyprpicker |
| Super+Shift+R / Super+Alt+R | `rice-rec toggle screen` / `region`: record to `~/Videos`, again to stop |
| Super+Shift+T / Super+Ctrl+T | rice chooser / next rice |
| Super+Shift+G | `rice grain toggle`: the rice's screen shader (Paper's grain) on/off |
| Super+Alt+D / Super+Alt+Shift+D | `rice mode toggle` / `rice mode auto` (light and dark by the sun) |
| Super+Ctrl+R / Super+Ctrl+Shift+R | Abyss's reef: touch on/off (`quickshell:reef-interactive`, with a toast) / stats overlay (`quickshell:reef-stats`); only Abyss's shell registers them |
| Media keys | `wpctl` (volume up to **150%**: `-l 1.5`), `brightnessctl`, `playerctl`; work while locked |

**Monitor and scale**: `base.lua` has the fallback
`hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })` (never
`scale = "auto"`: it enlarges a 1080p panel) and the user's laptop,
`hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "0x0", scale = 1 })`.
Other machines' values go in `~/.config/hypr/local.lua`, which is loaded last.
Never put monitor or scale settings in a rice.

**Window tags** (`base.lua`): `opaque`, `glassy`, `dialog`, `pip`, `game`. Base sets
placement and behaviour (dialogs float, pip floats, games tear). The rice's
`templates/hypr.lua` decides how each tag looks (opacity, borders, blur).

**Environment**: `~/.local/bin` is put on PATH; `QT_QPA_PLATFORMTHEME=qt6ct`.

**Shell**: zsh + Starship, the same in every rice (`rice.zsh`). A rice only changes
colours: `build/zsh.zsh` (from the shared template, ANSI colours only, since roles like
mint vanish on light glass) and `starship.toml`. Prompt glyphs are Nerd Font codepoints:
write them with `chr(0xf09b)`-style escapes, because private-use glyphs typed directly
get lost.

**Autostart**: `qs -c rice -d`, `rice session`, hypridle, hyprsunset, cliphist.

**Terminal and editor**: kitty's `background_opacity` only shows through cells whose
background is exactly kitty's own, so the shared nvim scheme (`templates/nvim/rice.lua`)
leaves `Normal`, `NormalNC`, `SignColumn`, `EndOfBuffer` and `TabLineFill` at
`bg = "NONE"` with `term_fg` text; floats, the cursor line and the statusline keep
`surface`. A rice with its own nvim pair (Paper's `rice@light.lua`/`@dark.lua`) must
keep the editor's background equal to `term_bg`. When `~/.config/nvim/lua/config/lazy.lua`
mentions LazyVim, `rice-render --link` also links `lua/plugins/rice.lua`
(`templates/nvim/lazyvim.lua`, `colorscheme = "rice"`), or LazyVim starts in tokyonight;
its lualine (`theme = "auto"`) picks up `lualine/themes/rice.lua`.

## How every shell behaves

What each part does is the same in every rice with a shell; only its look and motion
differ. The pieces are listed in the checklist below.

- **Bar**: one per monitor across the top, reserving its space and stepping aside for
  fullscreen. The workspaces and the active window's title on the left (Nacre puts its
  orb first: launcher on click, light ⇄ dark on right-click), the status on the right
  (network speed, volume, battery, tray; recording; caffeine as an idle inhibitor).
  The middle belongs to the island. The bar has **no clock**.
- **Workspaces**: only this monitor's. Nacre shows at least five pearls and grows to the
  highest workspace in use (a window on it, or being on it), shrinking back to five once
  those are empty (Abyss's dots do the same); Paper lists the workspaces that exist plus
  the active one. Click to go, scroll to step.
- **Window title**: on the focused monitor's bar only, from Hyprland's own events
  (`activewindow`, `activewindowv2`, `windowtitlev2` in `services/Hypr.qml`, read once
  from `hyprctl activewindow -j` at start), never `Hyprland.activeToplevel`, which can
  stay on the previous window. A long title scrolls in a `Marquee`.
- **Island**: the time (hover: the date; click: the month), the playing track and the
  notification count; it is the only notification popup. Details in the checklist.
- **Notifications**: the shell is the daemon. Each new one is a card in the island for
  4 s (hover holds it), with its actions, dismiss and swipe; all are kept in the history
  (grouped by app, newest first, "Clear all") until dismissed. Do Not Disturb keeps them
  out of the queue but still counts them; critical ones break through.
- **Calendar**: the month opens from the island's clock (Nacre and Abyss: the calendar
  in the control centre; Paper: the month card under the clock). Paper also keeps a tear-off
  calendar on the desk.
- **Control centre** (Super+N): toggles (Wi-Fi, Bluetooth, Do Not Disturb, night
  light, microphone, power profile, caffeine, screenshot, light/dark/auto (not in a
  dark-only rice), screen recording, the system card, plus the rice's own, such as
  Paper's grain), volume to 150% and brightness. Every shell has all of them
  (`test_every_control_centre_has_the_shared_controls`). Media and
  notification history live in the island, not here. The Wi-Fi tile's right-click and
  double-click (`doubleOpens`) open the shared shell's network widget
  (`rice/Network.qml` + `Wifi.qml`, nmcli; `qs -c rice ipc call network open`), dressed
  in the active rice; the trays leave network applets out, so the bar has one network
  mark. `system/install --network` puts NetworkManager on iwd.
- **Desk**: the system card on the bottom layer, draggable, its place and visibility
  remembered; it hides while that monitor has a fullscreen window.
- **Mode**: every shell colour crossfades with `Theme.k`; nothing in a shell is fixed
  to light or dark (see Light and dark).

## palette.toml: the one file a rice is made of

Copy an existing one; every section below is read by shared code. Schema v2: what
belongs to the rice is shared at the top level, what changes with the light is under
`[modes.<mode>.*]`. `rice-render` flattens one mode back into the
old shape, so templates keep writing `{{ roles.bg }}`, `{{ colors.ink }}`,
`{{ gtk.theme }}` and `{{ meta.screen_shader }}`. Top-level `[colors]`, `[roles]` etc.
are an error.

Shared:

- `[meta]` `name`, `title`, `tagline`, `transition` (shader name), optionally
  `transition_out` (the shader that plays when switching *away* from it, Abyss's
  `drain`; the chooser's `dissolve` gets the rice it left), and who does what:
  - `shell = "<qs config>"` or `""` for none
  - `notifications = "shell" | "swaync"`
  - `wallpaper = "shell" | "files"` (`files` = `wallpaper/` folder via mpvpaper/swww)
  - `lock = "shell" | "hyprlock"`
- `[fonts]` `display`, `ui`, `mono`, `ui_size = 14`, `mono_size = 15`–`15.5`,
  `weight`, `weight_strong`, `display_weight`; optionally `app_size`, the apps' interface
  size (gsettings fonts, qt6ct, zathura, imv; defaults to `ui_size`, which the shell keeps). Sizes were raised 2pt at scale 1; keep
  new rices at these sizes. Any new font family must be added to the font list in
  `install`.
- `[shape]` `window rounding_power panel popup chip border gaps_in gaps_out`.
- `[motion]` bezier `bloom settle sink` and durations `open close move workspace
  scratchpad focus border_loop panel_in panel_out stagger`.
- `[gtk]` `cursor_size`. The cursor isn't the rice's: it's one for every rice, by the
  light (the one exception is `[meta] cursor`, a rice's own cursor for both modes; no
  rice uses it now: Golden Gate wears the shared ones too). `rice-render` sets
  `gtk.cursor` to Bibata Modern Classic in light builds and Ice in dark ones (a palette
  that sets `[gtk] cursor` is an error), and `rice` applies Classic
  by day and Ice at night, in a dark-only rice and before any mode is chosen. It does
  this through `hyprctl setcursor`, gsettings and `~/.icons/default`, only when the
  cursor changes (`$STATE_DIR/cursor`), so a switch within one mode leaves it alone.
- `[nvim]` `colorscheme = "rice"`.
- `[install]` generated files that live outside `build/`, e.g. the shell's `Theme.qml`.
- `[meta] overlay = "<path under XDG_STATE_HOME>"`: a generated palette whose
  `[modes.*]` tables `rice-render` merges over this one, key by key, while it exists
  (Satsuei: `satsuei-wall` writes the plate's colours to `satsuei/palette.toml`).
  The rice's own `palette.toml` then holds the seed look, and `[install]` files must
  not read a colour the overlay writes (they're committed). `rice recolour` renders
  the active rice again and pushes the colours out live, as a mode change does.

Per mode (`[modes.light.*]`, `[modes.dark.*]`):

- `meta`: `gtk_theme`, `icon_theme`, `color_scheme` (templates and `rice` see them as
  `gtk.theme`, `gtk.icons`, `gtk.color_scheme`; packages go in `install`'s theme list),
  and optionally `screen_shader = "<file in the rice folder>"`: Hyprland's
  `decoration:screen_shader`, set by `rice` on every switch (and cleared for rices
  without one); `rice grain off` keeps it off. No `time` uniform: it must not redraw
  every frame. Merged into `[meta]` for templates.
- `colors` named colours; `roles` maps role → colour name. Shared templates use
  **only** roles: `bg surface overlay border fg muted accent urgent selection success
  warning cursor link shadow term_bg term_fg`. Every role must exist.
- `gradient` `stops` (colour names), `angle`.
- `ansi` `color0`–`color15`; keep normal colours ≥ 4.5:1 against the terminal background.
- `opacity` `terminal active inactive glass`.
- `wallpaper` only when the shell draws the wallpaper.

## Light and dark

Every rice renders both modes, `build/light/` and `build/dark/`, from the same
templates; `~/.local/share/rice/active` → `current/build/<mode>` (the mode is
`~/.local/state/rice/mode`, light when unset), and every linked app config, kitty's
include, `hyprland.lua` and `rice.zsh` go through `active/`. A rice without
`[modes.dark.*]` renders its light tables into `dark/` too. Boot screens and the
greeter always use `build/light/`.

**One-mode rices.** `[meta] modes = ["dark"]` (Abyss) declares the only mode a rice
has: it carries only `[modes.dark.*]`, renders only `build/dark/`, and `build/light`
is a link to `dark`, so `active`, the greeter and boot screens reach its one look
whatever the mode file says. Its own templates may be lone `name@dark.ext` files
(shared ones still come in pairs), its `light.*` in templates is its `dark.*`, and its
`meta.json` has `fixed_mode`. `rice mode` while it is active still writes the mode
(the other rices open in it later) but changes nothing on screen: no freeze, Hyprland,
GTK or app steps; a manual choice asks its shell for a toast (`shell.toast("dark", "Abyss is
always dark")`, icon then text), auto mode stays quiet. Its shell's `Mode` has `only: "dark"`, its
control centre has no mode toggle, and the chooser shows its card with no sun or moon.

- Templates stay mode-agnostic: roles, colours, `gtk.*`, `meta.*` and `{{ mode }}`.
  A file that must hold both modes reads `light.*` and `dark.*`; every `[install]` file
  (`Theme.qml`) must render the same in both modes, or the build fails. A template that
  genuinely differs by structure is a pair, `name@light.ext` + `name@dark.ext`; one
  without its twin fails the build. For one value, `{{ colors.sticky | night(colors.kraft) }}`
  is the value by day and the argument at night (the argument may be a dark-only colour).
  In a Theme, `cc("sticky", "kraft")` mixes one colour by day into another at night.
- **Shells follow the mode live.** `Theme.k` goes 0 → 1 (light → dark); a colour fixed to
  one mode would never change, so Themes have none. Shaders that need it get
  `uniform float dark` bound to `Theme.k`. The chooser's `rice/Theme.qml` mixes the
  active rice's roles from `meta.json`'s `modes`.
- **No colours in QML.** Every colour in a shell, the chooser or a `card.qml` comes from
  the generated `Theme.qml` (or a rice's rendered `meta.json`); add a named colour to the
  palette for anything new. `tests/test_qml_lint.py` fails on hex literals, numeric
  `Qt.rgba`, named colours other than `transparent`, and font weights under 400. A
  justified exception goes in `tests/qml-colour-allowlist.txt` with its reason.
- **Night rules** (`tests/test_night.py`, on `[modes.dark.*]`): no `#000000` or
  `#ffffff`; `bg`/`term_bg` at L* 7–12, `surface` at L* 10–16, no large surface above
  L* 25; `fg` 7–14:1 on `bg` and `surface` (above 14 it shimmers), `muted`, accents,
  `success` and `warning` at least 4.5:1; `accent`/`urgent`/`link` less saturated than in
  light; normal ANSI at least 4.5:1 on `term_bg`; the dark wallpaper's mean L* at most 16
  and its 99.9th percentile at most 45 (Paper's from `assets/gen.py`, Nacre's from
  `tools/render-wall dark`). Accents used as text that must stay pale (Nacre's
  pastels) get their own dark-only `*_ink` colours; gradient stops can stay saturated.
  Abyss is exempt from the L* bands, the 14:1 ceiling, the saturation rule and the
  wallpaper limits (`EXEMPT` in the test): the user chose the mock's near-black water
  over them. Its ANSI contrast is still checked.

`tests/snapshots/light.sha256` pins every light-mode output; refresh it
(`RICE_SNAPSHOT_UPDATE=1 python3 -m unittest tests.test_snapshot`) only when a change
is meant to alter light mode, and say so in the commit.

## How a switch hooks in

`rice <name>`: render → freeze (shared shell overlay) → swap `current` → apply:
`hyprctl reload`, the cursor (when it changes), the screen shader (`hyprctl eval`), GTK via gsettings (theme, icons, cursor, fonts, colour
scheme), kitty, nvim, notifications daemon, wallpaper, the rice's Quickshell
(old one killed, new one started), `spicetify refresh`, `hooks/post-switch` →
dissolve with the rice's `transition` shader. A failing step is logged and skipped.

Hooks a rice can ship (`hooks/`, executable): `enter` runs before the incoming rice applies
anything (Golden Gate saves the user's GTK, Qt and cursor settings there), `post-switch`
after it has, `post-mode MODE` after `rice mode`, and `leave TO` in the outgoing rice
before the next one applies its own (Golden Gate unloads its plugins and restores what
`enter` saved). They run while `rice` holds its lock, so a hook must not call `rice`.

Rendered for every rice from shared templates: kitty, GTK css (`gtk/gtk.css` for GTK 3,
`gtk/gtk4.css` for GTK 4, which imports the former unless a rice ships its own), qt6ct (Fusion style +
palette + fonts), btop, fastfetch, Firefox userChrome, imv, mpv, nvim + lualine,
Spicetify, starship, Telegram, Vesktop, yazi, zathura, cava, Limine, Plymouth, ReGreet.
Text on a coloured fill (accent buttons, active tabs, mode pills) uses
`{{ roles.X | readable }}`, never a fixed role: it picks `fg`, or `bg` when `fg` falls
under 3:1 on that fill and `bg` reads better.

`rice mode light|dark|toggle [--instant]`: freeze (unless instant, animations off, or a
battery under 20%: then the shells crossfade for 200 ms) → write `~/.local/state/rice/mode`
(atomically) → re-point `active` → `hyprctl eval` of `active/hypr-mode.lua` (no reload) →
gsettings colour scheme, GTK theme, icons → SIGUSR1 to kitty and cava, nvim's
colourscheme, Spicetify's `rice-<mode>` scheme → `qs ipc call mode jump|fade` to the
rice's shell and the shared one → `rice ipc call rice reveal <mode>`: the shared shell's
`Freeze` dissolves with the rice's mode shader from `[meta] mode_transition` (`mode_origin`,
`mode_tint` (a colour name or hex) with `mode_tint_alpha`, `mode_ms`; the shader also gets
`dark` and the target mode's gradient as `c0`–`c4`), on the rice's bloom curve, or fades.
Qt passes colours to shaders premultiplied. `mode_sound` (Paper's click) plays when
`sound = true` in `mode.toml`. So **everything that
changes with the mode in Hyprland goes in `templates/hypr-mode.lua`**; `hypr.lua` loads it
and must render the same in both modes (a test checks), window rules included.

Auto mode: `rice mode auto [off]`; `rice-mode.timer` (and login, and hypridle's
`after_sleep_cmd`) run `rice mode tick`, which asks `rice-sun` (stdlib Python, NOAA,
offline; settings in `~/.config/rice/mode.toml`, shipped with the user's location in
`switcher/.local/share/rice/mode.toml`) and applies its mode, unless a manual choice
holds (`$STATE_DIR/mode-hold-until`, the next sunrise or sunset). Rices are never
switched by time.

## Checklist for a new rice

1. `rices/.config/rices/<name>/palette.toml` with every section above.
2. `templates/hypr.lua`: borders, rounding, blur, shadows, animations and the look of
   each window tag. Visuals only: no binds, monitors, env or autostart.
3. Its shell, if it has one (`quickshell/.config/quickshell/<name>/`), must provide
   the same entry points so the shared binds work:
   - `GlobalShortcut` names: `launcher`, `launcher-tap`, `clipboard`, `center`,
     `keybinds`, `power`
   - `IpcHandler` targets: `lock` (function `lock`), `osd` (`trigger`), `shell`
   - a volume OSD/slider that allows up to `1.5`
   - a network speed widget that samples continuously (one long-lived process)
   - a key sheet built from `hyprctl binds -j`
   - screen recording: `shell.recording(on)` on the `shell` IpcHandler, a `rice-rec status`
     check at startup, a record control in the control centre (click: screen, right-click:
     region, both through `rice-rec toggle`, started 350 ms after the panel closes) and
     something visible while recording (Nacre: the orb's dot; Paper: "rec m:ss" in the bar;
     Abyss: a breathing pink dot and the time in the bar)
   - `Theme.qml` generated from the palette through `templates/quickshell/Theme.qml`
     plus an `[install]` entry. It carries both modes (`lightPalette`, `darkPalette`
     from `light.*`/`dark.*`), and every colour property is `c("name")` or
     `role("name")`, mixed by `k`; it holds a `Mode` (`mode`, `dark`, `k`).
   - an island over the middle of the bar (`bar/Island.qml`, a `PanelWindow` per screen on
     `WlrLayer.Overlay`, namespace `<shell>-island`, masked to itself): always the time
     (the bar has no clock) and the notification count; the playing track with its cover
     and a small visualizer, glowing with `Beat.level`, hover for play/pause and next;
     each notification as a card for `Notifs.lifetime` (4 s) from `Notifs.queue`, with
     its actions, dismiss and swipe; a click grows it into media plus the notification
     history (`Shell.toggleIsland`). It is the only notification popup; the control
     centre has neither media nor history. Every visualizer reads the shell's one cava,
     an identical copy of `services/Beat.qml`. The window title goes after the
     workspaces, in a `Marquee` when long
   - the draggable system card on the desktop (`desk/Stats.qml`, `WlrLayer.Bottom`, saved in
     `Shell.statsShown`/`statsAt`, toggled from the control centre), fed by an identical
     copy of `services/Sys.qml` (CPU, memory and `/` from one long-lived reader)
   - a copy of `Mode.qml` next to `Theme.qml` (the tests keep every copy identical): it
     reads `~/.local/state/rice/mode` before the first frame, watches it, crossfades `k`
     over 600 ms, and answers the `mode` IpcHandler (`set`, `jump`, `fade`, `toggle`,
     `get`).

   With no shell, set `shell = ""`, `notifications = "swaync"`, `lock = "hyprlock"`, and
   ship a `wallpaper/` folder.
4. `transition.frag` (compile with `tools/shaders`), `card.qml` for the chooser, and
   `preview.png`.
5. Run `rice-render <name>`, then `rice <name>`. Check the key sheet, lock, OSD at 150%,
   the Qt and GTK apps, and Spotify.
6. Run the tests; update the README's rice list.

## The reef (Abyss's wallpaper)

`abyss/reef/Reef.qml` is plain Qt Quick, so the wallpaper, the lock screen and
`assets/gen.py --still` all run the same reef. `reef.js` is the mock's simulation
(the creatures and a coarse ripple field they feel); `Ripple.qml` runs the same field
on the GPU in four chained RGBA16F passes, and that is what the water refracts.
`Scene.qml` draws at `scale` of the screen: what never moves (ridge, floor, anemone
bodies) once, the corals and fans baked once and swayed by vertex shaders, kelp built
in a vertex shader, and one Threaded Canvas for what moves (tips, tentacles, fish,
jellies, plankton). `water.frag` composes it with the gradient, rays, caustics, snow,
refraction, a quarter-size bloom and the tone map.

- It ticks on a `Timer`, never a `FrameAnimation` (a test checks): between ticks
  nothing redraws. `Wallpaper.qml` stops it (fullscreen, locked; not DPMS, whose
  state Hyprland's monitor info can keep stale) or reduces
  it (92% covered, low battery); `qs -c abyss ipc call reef stats` says which and why.
- In QV4, index arrays with integers (`|0`): a double index made the reef 15× slower.
- A running `ParticleSystem` keeps the window redrawing every vsync, so plankton stays
  on the Canvas.
- Settings come from `~/.config/rice/abyss.toml` (`services/Config.qml`); the shipped
  `switcher/.local/share/rice/abyss.toml` must list the same defaults (a test checks).
- The glow sprites are `assets/gen.py`'s; the reef asks for exactly the set
  `sprite_keys` makes. Re-run it after changing the reef's hues.

## Satsuei (the picture rice)

Satsuei takes its look from the user's wallpaper: `satsuei-wall set` (see Layout and
`[meta] overlay`). Its plate (`plate/Plate.qml`) draws the picture through a
compositing pass (`plate/shaders/satsuei.frag`, the rays at an eighth of the size in
`rays.frag`), timed by a `Timer` at 30 fps and paused for fullscreen, a battery under
30% and the lock; `plate/tools/grab.py --bench` measures its GPU time. Every surface
is `satsuei-*`. By the user's choice it departs from the shared shell in three ways:

- **The bar has the clock** in its middle (Dela Gothic One, with the date), and there
  is no island: the left is the seal (the Satsuei panel) and the episodes (workspaces
  `01`–`05`), the right what's playing and the status.
- **Notifications are subtitles** at the bottom centre, not island cards; Quiet keeps
  them in the control centre's list.
- **Its own binds** (only its shell registers them): Super+Ctrl+W the wallpaper
  selector, Super+Alt+C the Cast picker, Super+Alt+Shift+C / Super+Alt+M the next
  dancer / mascot. Super+W stays the browser.

The plate frosts itself behind windows: Hyprland drew no blur behind GTK windows
(Nautilus), so `services/Windows.qml` reads `hyprctl clients -j` on window and
workspace events and the pass swaps the plate for its blur maps inside every
window on the screen's workspace, pass or no pass (`Settings.s.frost`). GTK's big
fills are `opacity.gtk` (`templates/gtk/gtk.css.append`; a rice's `<name>.append` is
rendered onto the end of the shared `<name>`) so that frost shows through.

Characters (`chars/`): a built-in is a `Rig` (the mock's `pose()`, ticked at 30 fps only
while shown) whose parts are `Part`s (pivots) of `Blob`s (`QtQuick.Shapes` on the
mock's 120 × 160 canvas, curve renderer); their clothes are the plate's tokens and
their skin and eyes `Style.art`. `services/Tempo.qml` guesses the tempo from Beat's
kicks; `Characters.qml` says who plays the dancer and the mascot.

The user's own characters are folders in `~/.config/satsuei/characters/<id>/`: a
`dance` clip (required), optional `idle`/`wave`/`sleep`/`thumb.png` and `meta.json`
(`name nameJa baseBpm scale offsetX offsetY flip trimBottom puppet`, and `frames fps`
for a `.png` sprite sheet). GIF and animated WebP play as they are (WebP needs
qt6-imageformats); an APNG is converted once by ffmpeg into
`~/.cache/satsuei/characters/`, since Qt shows only its first frame. `Characters`
watches the folders (`FolderListModel` plus each `meta.json`), so they appear with no
restart. `chars/Custom.qml` is a `Rig` that plays the clips and moves the whole sprite
(the beat puppet); `chars/Actor.qml` shows any character, built-in or not, and every
host (the media card, the timesheet, `center/Strip.qml`, the Cast picker
`cast/Cast.qml`) goes through it. The Cast picker casts either role from a grid of
every character and adds one from a file (zenity; copied in as its `dance`).
A custom character is drawn through `chars/SceneMatch.qml` (`shaders/scenematch.frag`,
a `layer.effect` on its clip): `recolor` rules move colours near `from` to a token's hue
and chroma in OKLab, keeping their lightness relative; `protect` colours never move; then
the plate's grade (`ambient`), a rim toward its light source (`rim`), an optional
`outline` and the grain. `tests/scenematch_probe.py` renders the fixture through it, and
a test checks that its recoloured part follows three accents and its protected part
stays put.

The edge mascot (`mascot/Mascot.qml`, `satsuei-mascot` on the top layer, masked to its
head) rests below the bottom edge 8% in from the right, springs up and waves for 4.2 s
when a subtitle goes up, sleeps after 40 s idle (`IdleMonitor`) and hops when clicked.

The wallpaper folder (`Settings.s.wallDir`) is `walls/Library.qml`: `satsuei-wall scan`
(cached per picture in `~/.cache/satsuei/walls/<sha1>/`, one JSON line each) and one
`inotifywait` on the folder; it also does the auto-rotate. `walls/Selector.qml`
(Super+Ctrl+W) previews the focused picture on the real plate through `Theme.preview`
(no blur maps until it's set), keeps it with `Library.apply` (the preview holds until
`theme.json` changes) or drops it on Esc. `panel/Studio.qml` (the bar's seal) holds the
pass's switches, the hour, the wallpaper, the palette and the light picker; the click
goes to the screen's plate through `Plates.pick`.

The system card (`desk/Stats.qml`) is a timesheet: CUT and the day, ten frames inked
down three columns (CPU, MEM, DSK) with a playhead stepping once a second, the readout
beside, and the dancer small on its top edge (15 fps, still while windows cover it,
fanning itself when the CPU runs hot). Its place is in `Settings`, behind `Shell.statsAt`.

The lock (`lock/Lock.qml`, `LockSurface.qml`) is an episode title card over the plate
graded and blurred: 第<day of year>話, the date's title from
`rices/satsuei/lock-titles.json` (366, in calendar order, seasonal; indexed as in a
leap year, a test checks), the time and date, and a glass password pill. The
bar's battery is `bar/Reel.qml`, a strip of film exposed as far as the charge goes.
The chooser card (`card.qml`) shows the plate on screen now (from `theme.json`), and
`transition.frag` is a light leak.

`Theme.qml` is not generated: it reads `theme.json` and crossfades every token over
600 ms (Behaviors inside a singleton crash the engine, so it mixes from a snapshot);
`Style.qml` is, from the palette, and holds no plate colour.

## Golden Gate (macOS 27)

Golden Gate is macOS 27 "Golden Gate", behaviour as well as looks; the plan and what was
verified are in `docs/goldengate/PLAN.md`. Apple's fixed system colours (palette.toml),
labels as black or white at 85/50/25/10% (exempt from the night rules' "no pure extremes"
for that), and one user accent: `gg accent` writes `appearance.accent` in
`~/.config/goldengate/settings.json` (the shell reads it) and the overlay
`~/.local/state/goldengate/palette.toml` (roles, opacity and the MacTahoe names: the apps),
then `rice recolour`s. The overlay never writes `[colors]`, so the committed `Theme.qml`
doesn't change with the accent.

- **Themes:** MacTahoe GTK (every accent, translucent, built by `gg-theme install` into
  `~/.local/share/themes`), MacTahoe Kvantum (accent copies `GoldenGate[Dark]` in
  `~/.config/Kvantum`), MacTahoe icons, the shared Bibata cursors (Classic by day, Ice at night), SF Pro
  Text and SF Mono for GTK and Qt (`gg-theme` writes qt6ct's fonts and restores the user's). Kvantum and qt6ct's `kvantum`
  style are Golden Gate's only: `gg-theme save` (the `enter` hook) keeps the user's
  values, `gg-theme restore` (the `leave` hook) puts them back exactly; "Kvantum was
  dropped" still holds for every other rice.
- **Light and dark** are `rice mode`'s; the shared freeze reveals them with
  `crossfade.frag` over 450 ms. `post-mode` re-applies Kvantum and the glass's theme.
- **Glass:** `gg glass liquid|frosted|solid`, `gg glass clarity 0..1` (Ultraclear … Tinted),
  `gg glass backend auto|hyprglass|hyprliquid|shader`. Liquid is a plugin that `gg` loads with
  `hyprctl plugin load` while Golden Gate is on screen (never `hyprpm enable`) and the `leave`
  hook unloads: hyprglass (hyprpm's build), else hyprliquid (AUR); never both. A plugin that
  is missing, paused or can't draw falls back to Frosted (Hyprland's blur), and
  `~/.local/state/goldengate/glass.json` says why: the shell's `Glass` service reads it and
  puts up a banner. What Hyprland draws is the rice's `glass.lua` (rendered, loaded by
  `hypr.lua` on every reload), reading gg's `glass-state.lua`; a clarity change is an eval
  with `GG_GLASS_LIVE` (no rules, which would stack), a plugin change an eval, and leaving
  hyprliquid a reload (its rules outlive it). Panels are `common/GlassPane.qml`; under a
  plugin their shadows stay below its mask threshold (0.06) so only the panel is glass.
  Backend `shader` is the shell's own (`common/LiquidLayer.qml`, `shaders/liquid.frag`): it
  bends a copy of the wallpaper, or with `glass.accurate` a still of the screen taken as the
  pane opens. **Never keep a `ScreencopyView` alive**: it holds the screencopy, and grim and
  hyprlock (the idle lock) then hang; capture, `grabToImage`, destroy.
- **Its own binds and windows** (the exception to the shared binds, as Satsuei's are):
  the rice's `session.lua` (rendered, loaded by `hypr.lua` on every reload, so any other
  rice's reload drops it) unbinds what the Mac uses differently and binds its set with ⌘ as
  Super and no global Ctrl grabs: ⌘Q quit the app, ⌘W close, ⌘H / ⌥⌘H hide, ⌘M minimize,
  ⇧⌘M show all, ⌃⌘F full screen, ⌃⌘arrows halves then quarters, ⌃⌘Return Fill, ⌃⌘C
  Center, ⌘` the app's next window, ⌥⌘←/→ and ⌥⌘1–9 Spaces, ⌥⌘↑/↓ Mission Control and
  App Exposé, ⌘F4 Apps, ⌘F11 Show Desktop, ⇧⌘3/4/5 screenshots (rice-shot until the shell's
  toolbar), ⌘N Notification Center, ⌘, Settings, ⌃⌘Q lock, ⌥⌘G the glass. Windows float
  and centre (`windows.layout = "tiled"` turns that off; `gg set` reloads Hyprland), and one
  asking for more than the screen opens smaller. Minimize, Hide and Show Desktop move
  windows to `special:minimized|hidden|desktop`. Everything a window can be asked is a
  `GG.*` Lua function; `gg win …`, the traffic lights and the shell call them through
  `hyprctl eval`. The traffic lights are hyprbars, which `gg` loads like the glass plugins
  (a load reloads the config, so `GG.bars()` runs once per Lua state), except on the apps
  in `own_bar` that draw their own; tiles leave room for its 30 px bar. No Golden Gate bind
  is in `base.lua` (a test checks).
- **Its shell** departs from the shared one as macOS does: the menu bar has the clock, the
  Dynamic Island sits in it (activities only), notifications are banners at the top right
  and live in Notification Center, and there is a Dock. Every panel is `common/Panel.qml`
  (one open at a time, `Shell.open`), given its screen's name as `at`; app icons are
  `common/AppIcon.qml`, symbols `common/Sym.qml` (MacTahoe's symbolic icons, recoloured).
  The shared entry points are all there (`launcher` is Spotlight, `center` Control Center).
  The menu bar's two sides are frosted pills (`menubar/Pill.qml`, Hyprland's blur whatever
  the glass), tray icons recoloured as symbols (`menubar.monoTray`; colour badges such as Spotify's
  take Colloid's symbolic or Papirus's panel icon instead). The Dock keeps out of
  the way (no autohide, no reserved space): it stays up only on an empty workspace and slides
  back when the pointer touches the bottom edge. ⌥Tab is the shell's window switcher
  (`switcher/Switcher.qml`, this workspace's windows, most recent first; the one bind
  without ⌘). A click on the island opens `menubar/IslandCard.qml` (cover, controls, Beat's bars,
  Spotify's synced lyrics from LRCLIB, `services/Lyrics.qml`). The desktop widgets
  (`desk/Stats.qml`: system and weather, Open-Meteo, `services/Weather.qml`) are toggled
  and dragged one by one. Notification sounds are `sounds/*.wav`, made by `tools/gg-sounds`.
- **Wallpaper:** the shell draws it from `~/Pictures/Wallpapers` (shared with Satsuei);
  a `name-light.*` / `name-dark.*` pair is one wallpaper that crossfades with the mode
  (`gg wall set`).

### Working on Golden Gate

Where things are, for a change asked of one part:

| Part | Files |
|---|---|
| menu bar, pills, tray, clock | `menubar/MenuBar.qml`, `Pill.qml`, `TrayIcon.qml` (`menubar.monoTray`: Colloid's symbolic, then Papirus's panel icons for colour badges) |
| Dynamic Island, media card, lyrics | `menubar/Island.qml`, `IslandCard.qml`, `services/Lyrics.qml` (LRCLIB: exact `get`, else `search` without "feat."), `services/Beat.qml` |
| Dock | `dock/Dock.qml`: up only on an empty workspace, edge reveal, right-click menu (its mask must include the menu or clicks fall through) |
| ⌥Tab | `switcher/Switcher.qml` + `session.lua`'s `ALT + TAB` → `quickshell:switcher`; the choice is raised after the strip closes (`GG.raise`) |
| widgets | `desk/Stats.qml` (system + weather), `desk/Widget.qml`, `services/Weather.qml` (Open-Meteo; location from ipinfo.io once, kept in Settings) |
| sounds | `services/Chime.qml`, `sounds/*.wav` from `tools/gg-sounds` |
| glass, blur | `templates/glass.lua` (Frosted's numbers; the menu bar is always Hyprland's blur), `templates/hypr.lua` (layer rules), `gg glass` |
| binds, window actions | `templates/session.lua` (`GG.*`, reached by `gg win …`); keyd: `docs/goldengate/keyd-goldengate.conf` (installed to `/etc/keyd` by `install --fresh`) |
| settings | `services/Settings.qml` (`~/.config/goldengate/settings.json`), `settings/SettingsApp.qml`, `services/Shell.qml` (`shell.json`: widgets, DND) |

Traps met while building it:

- Quickshell's hot reload can stop picking up edits: restart the shell (stop every
  `goldengate` instance from `qs list --all`, then `qs -c goldengate -d`); two at once
  leave the second without the notification server.
- An error inside an inline `component` shows only as "X is not a type": move it to its
  own file to see the real one (or to fix it).
- `layer.effect: MultiEffect` with a mask punched holes through what's behind on a
  layer surface; draw the source hidden with `layer.enabled` and a sibling `MultiEffect`
  (`common/Sym.qml`).
- Several `Settings.set` in a row race the file's own reload: write one object
  (`gg set location '{…}'`).
- A binding on `font.family` that reads `font.pixelSize` loops: set
  `Theme.fontDisplay` by hand on large text.
- `hyprctl reload` after changing a template (`rice-render goldengate` first); check
  `hyprctl configerrors`. Changing a template changes light mode, so refresh
  `tests/snapshots/light.sha256` and say so in the commit.

## Audio

The `audio/` stow package is the same for every rice. PipeWire's `allowed-rates` let the
card follow a stream's rate (no resampling of 44.1 kHz music); ALSA outputs never suspend
(no pop). Leave `resample.quality` at PipeWire's default: a client builds its resampler
in its realtime data loop, and with rtkit that thread has an `RLIMIT_RTTIME`, so quality
10 had the kernel SIGKILL mpv's `data-loop.0` as a video started (a test checks). Even
without it the kills went on (mpv and cava together), so clients aren't realtime at all:
`client.conf.d` sets `module.rt = false` (the condition on client.conf's module-rt);
the daemon stays realtime. WirePlumber offers every installed
Bluetooth codec (never set `bluez5.codecs`: it would shut out LHDC), LDAC at `auto`,
AAC at bitrate mode 5, and `bluetooth.autoswitch-to-headset-profile = false` so a mic
never drops music to HFP. `install --fresh` adds `pipewire-audio` (which pulls libldac,
libfreeaptx, libfdk-aac, liblc3), the sound firmware and rtkit, and offers LHDC from the
AUR, whose failure only warns. `tests/test_audio.py` checks all of it.

## Things learned the hard way

- Qt: Kvantum was dropped. Its dark artwork broke light rices; use Fusion + qt6ct.
- Spotify: themed through Spicetify from its GitHub release (the AUR build breaks). It
  runs as a native Wayland app (`~/.config/spotify-flags.conf` /
  `spotify-launcher.conf`) or XWayland upscaling blurs the text. Fonts are set through
  Spotify's `--encore-*-font-stack` variables, falling back to Noto (CJK too).
- AUR helper: paru is built from source, not `paru-bin` (it breaks on libalpm bumps).
- `--fresh` disables iwd/networkd without `--now` and hands over to NetworkManager;
  it installs GPU drivers by sysfs vendor and gnome-keyring unlocked by greetd PAM.
- OSD fills clip to their track, so levels above 100% never overflow.
