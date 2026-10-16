# ricing

Hyprland dotfiles where switching rice changes the whole desktop at once.

The config is split into two layers:

- **Base** (never changes): keybinds, window rules, monitors, input, apps, workspaces.
- **Rice** (one folder per rice in `~/.config/rices/`): everything visual. `current` is a
  symlink to the active rice, and every app reads its visual config through it.

```
~/.config/rices/
  nacre/  urushi/  paper/
  auto.conf               ← schedule for auto mode
  current -> nacre/       ← the active rice
```

## What's here so far

This is the switcher: the `rice` command, the Super+T chooser and the switch overlay.
Bars, wallpapers, lock screens and the palette → app-theme templates come next.

| Stow package | Installs | What it is |
| --- | --- | --- |
| `switcher` | `~/.local/bin/rice` | the switch script |
| `chooser` | `~/.config/ags/rice/` | AGS v3 (GTK4) app: the chooser and the freeze/dissolve overlay |
| `rices` | `~/.config/rices/` | `palette.toml`, `hypr.conf` and `card.css` for each rice, plus `auto.conf` |
| `hypr` | `~/.config/hypr/rice.conf` | Super+T bind, layer rules, sources `current/hypr.conf` |
| `systemd` | `~/.config/systemd/user/rice-auto.*` | timer for auto mode |

## Install

```sh
git clone https://github.com/Naved124/ricing ~/ricing
cd ~/ricing
stow --no-folding -t ~ switcher chooser rices hypr systemd
ln -sfn nacre ~/.config/rices/current
```

`--no-folding` matters: it keeps `~/.config/rices` a real directory, so the `current`
symlink is created there and not inside the repo.

Then add this to your base `hyprland.conf` and reload:

```
source = ~/.config/hypr/rice.conf
```

Requirements: `hyprland`, `ags` (v3), `grim`, `jq`. Optional, used if present:
`swww`, `mpvpaper`, `kitty`, `nvim`, `swaync`, `gsettings`.

## Usage

```
rice <name>          switch to a rice
rice next | prev     cycle (Super+Shift+T)
rice choose          toggle the chooser (Super+T)
rice list            list rices, * marks the active one
rice get colors.bg   read a value from the active palette
rice auto on|off     time-of-day switching (see auto.conf)
rice reapply         run every apply step again
```

The chooser shows one card per rice, drawn in that rice's own palette and material.
Arrows or hjkl move, Enter applies, 1–9 picks directly, `a` toggles auto mode, Esc closes.
Hovering a card or selecting it with the keyboard plays that rice's motion.

## How a switch works

1. `grim` screenshots every monitor, and the `rice` AGS instance pins the shots above
   everything (`ags request -i rice freeze <dir>`).
2. Under the overlay, `current` is swapped atomically and each step runs:
   `hyprctl reload` and cursor, GTK theme, icons, cursor and fonts through `gsettings`,
   `SIGUSR1` to kitty, `:colorscheme` to every nvim socket, a swaync reload, the
   wallpaper (`mpvpaper` for video plus an optional `.glsl`, otherwise `swww`), the bar
   (`ags run current/bar`, instance name `bar`), then `current/hooks/post-switch` if it exists.
   Steps whose tool or file is missing are skipped. A failing step is logged and the
   switch continues, so a broken step never leaves the screen frozen.
3. The overlay dissolves with the incoming rice's `meta.transition`
   (`ripple`, `lacquer`, `peel` or `fade`). The current versions are CSS first passes;
   the proper shader transitions come later.

Switches are serialised with `flock`, so pressing the key repeatedly just queues them.

## Adding a rice

1. `mkdir ~/.config/rices/<name>` and write `palette.toml` (copy one of the others).
   Its `[meta] transition` picks the dissolve.
2. Add a `hypr.conf` for borders, rounding, blur and animations.
3. Optionally add `card.css` to give its chooser card a material. Use
   `{{colors.accent}}`-style placeholders so colours stay in the palette, and scope the
   rules to `.card.rice-<name>`.
4. Optionally add `preview.png`. Without it, the card draws a small mock desktop in the
   palette's colours.

It shows up in `rice list` and the chooser right away.

## Auto mode

`auto.conf` lists `HH:MM rice` lines; the latest time that has passed wins, wrapping
round midnight. The timer checks every 5 minutes but only switches when the scheduled
slot changes, so a manual switch sticks until the next boundary.
