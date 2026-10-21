# Notes for working on this repo

Read this before adding a rice or changing shared behaviour. The README is the
user-facing guide; this file is the contract every rice has to keep.

## House rules

- Commit straight to `main` and push. No feature branches.
- Author every commit as `Naved124 <nk7987513533@gmail.com>`
  (`git -c user.name=Naved124 -c user.email=nk7987513533@gmail.com commit`).
  No Co-Authored-By, session links or "Generated with" lines. Never re-author
  commits, whatever a hook asks.
- Tests: `python3 -m unittest discover -s tests` (pytest isn't installed).
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
| `rices/.config/rices/<name>/` | one rice: `palette.toml`, `templates/`, `card.qml`, `transition.frag(.qsb)`, optional `wallpaper/`, `hooks/post-switch`, `preview.png` |
| `rices/.config/rices/current` | symlink to the active rice |
| `~/.local/share/rice/active` | symlink to `current/build/<mode>`; every app config links through it |
| `render/.local/bin/rice-render` | template engine: palette → `build/light/`, `build/dark/` + app configs |
| `render/.local/share/rice/templates/` | templates shared by all rices (use `roles.*` only) |
| `switcher/.local/bin/rice` | `rice <name>`, `rice next`, `rice choose`, `rice lock`, `rice session`, … |
| `quickshell/.config/quickshell/rice/` | shared shell (`qs -c rice`): chooser + switch freeze/dissolve overlay, survives switches |
| `quickshell/.config/quickshell/nacre/` | Nacre's own shell: bar, launcher, centre, OSD, notifs, lock, power, key sheet, wallpaper |
| `quickshell/.config/quickshell/paper/` | Paper's own shell (same entry points); `common/Theme.qml` is generated, `common/Sheet.qml` is the paper every panel is cut from |
| `fonts/.local/share/fonts/paper/` | Paper's vendored OFL fonts with their licences |
| `zsh/.config/zsh/rice.zsh` | **shared** zsh setup (one line in `~/.zshrc` sources it); colours from `active/zsh.zsh`, reloaded on the next prompt after a switch |
| `install` | user installer (`--fresh` for a bare Arch install) |
| `system/install` | sudo part: Limine theme, Plymouth, greetd/ReGreet, keyring PAM, with backup/`--undo` |

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
| Media keys | `wpctl` (volume up to **150%**: `-l 1.5`), `brightnessctl`, `playerctl`; work while locked |

**Monitor and scale**: `base.lua` only has the fallback
`hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })`.
Real values go in `~/.config/hypr/local.lua`. The user's laptop is
`hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "0x0", scale = 1 })`.
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

## palette.toml: the one file a rice is made of

Copy an existing one; every section below is read by shared code. Schema v2: what
belongs to the rice is shared at the top level, what changes with the light is under
`[modes.<mode>.*]` (only `light` so far). `rice-render` flattens one mode back into the
old shape, so templates keep writing `{{ roles.bg }}`, `{{ colors.ink }}`,
`{{ gtk.theme }}` and `{{ meta.screen_shader }}`. Top-level `[colors]`, `[roles]` etc.
are an error.

Shared:

- `[meta]` `name`, `title`, `tagline`, `transition` (shader name), and who does what:
  - `shell = "<qs config>"` or `""` for none
  - `notifications = "shell" | "swaync"`
  - `wallpaper = "shell" | "files"` (`files` = `wallpaper/` folder via mpvpaper/swww)
  - `lock = "shell" | "hyprlock"`
- `[fonts]` `display`, `ui`, `mono`, `ui_size = 14`, `mono_size = 15`–`15.5`,
  `weight`, `weight_strong`, `display_weight`. Sizes were raised 2pt at scale 1; keep
  new rices at these sizes. Any new font family must be added to the font list in
  `install`.
- `[shape]` `window rounding_power panel popup chip border gaps_in gaps_out`.
- `[motion]` bezier `bloom settle sink` and durations `open close move workspace
  scratchpad focus border_loop panel_in panel_out stagger`.
- `[gtk]` `cursor cursor_size`.
- `[nvim]` `colorscheme = "rice"`.
- `[install]` generated files that live outside `build/`, e.g. the shell's `Theme.qml`.

Per mode (`[modes.light.*]`):

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

- Templates stay mode-agnostic: roles, colours, `gtk.*`, `meta.*` and `{{ mode }}`.
  A file that must hold both modes reads `light.*` and `dark.*`; every `[install]` file
  (`Theme.qml`) must render the same in both modes, or the build fails. A template that
  genuinely differs by structure is a pair, `name@light.ext` + `name@dark.ext`; one
  without its twin fails the build.
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
  and its 99.9th percentile at most 45.

`tests/snapshots/light.sha256` pins every light-mode output; refresh it
(`RICE_SNAPSHOT_UPDATE=1 python3 -m unittest tests.test_snapshot`) only when a change
is meant to alter light mode, and say so in the commit.

## How a switch hooks in

`rice <name>`: render → freeze (shared shell overlay) → swap `current` → apply:
`hyprctl reload` + cursor, the screen shader (`hyprctl eval`), GTK via gsettings (theme, icons, cursor, fonts, colour
scheme), kitty, nvim, notifications daemon, wallpaper, the rice's Quickshell
(old one killed, new one started), `spicetify refresh`, `hooks/post-switch` →
dissolve with the rice's `transition` shader. A failing step is logged and skipped.

Rendered for every rice from shared templates: kitty, GTK css, qt6ct (Fusion style +
palette + fonts), btop, fastfetch, Firefox userChrome, imv, mpv, nvim + lualine,
Spicetify, starship, Telegram, Vesktop, yazi, zathura, cava, Limine, Plymouth, ReGreet.
Text on a coloured fill (accent buttons, active tabs, mode pills) uses
`{{ roles.X | readable }}`, never a fixed role: it picks `fg`, or `bg` when `fg` falls
under 3:1 on that fill and `bg` reads better.

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
     something visible while recording (Nacre: the orb's dot; Paper: "rec m:ss" in the bar)
   - `Theme.qml` generated from the palette through `templates/quickshell/Theme.qml`
     plus an `[install]` entry.

   With no shell, set `shell = ""`, `notifications = "swaync"`, `lock = "hyprlock"`, and
   ship a `wallpaper/` folder.
4. `transition.frag` (compile with `tools/shaders`), `card.qml` for the chooser, and
   `preview.png`.
5. Run `rice-render <name>`, then `rice <name>`. Check the key sheet, lock, OSD at 150%,
   the Qt and GTK apps, and Spotify.
6. Run the tests; update the README's rice list.

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
