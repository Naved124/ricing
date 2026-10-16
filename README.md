# ricing

Hyprland dotfiles where switching rice changes the whole desktop at once: borders and
animations, the shell (bar, launcher, notifications, lock screen), the wallpaper, and the
theme of every app, all from one `palette.toml`.

The config has two layers:

- **Base** (never changes): keybinds, input, layout, window tags, autostart.
- **Rice** (one folder per rice in `~/.config/rices/`): everything visual. `current` is a
  symlink to the active rice, and everything reads its look through it.

```
~/.config/rices/
  nacre/  urushi/  paper/   ← palette.toml, templates/, card.qml, transition.frag
  auto.conf                 ← schedule for auto mode
  current -> nacre/         ← the active rice
```

Three rices ship today:

| Rice | Look | Shell |
| --- | --- | --- |
| **Nacre** | pearl glass, colour only at the edges and in motion | its own Quickshell config: bar, launcher, control centre, notifications, OSDs, lock, power menu, live wallpaper |
| **Urushi** | black lacquer, vermilion, gold | Hyprland visuals and app themes; bring your own bar (swaync, hyprlock, wallpaper files) |
| **Paper** | ink on warm stock, daylight | the same as Urushi |

Targets **Hyprland 0.56** (Lua config; 0.55 or newer is needed) and **Quickshell 0.3**.

## Packages

Install with [GNU Stow](https://www.gnu.org/software/stow/). Each folder is a package:

| Package | Installs | What it is |
| --- | --- | --- |
| `switcher` | `~/.local/bin/rice`, `rice-shot` | the switch script and the screenshot tool |
| `render` | `~/.local/bin/rice-render`, `~/.local/share/rice/templates/` | palette → theme files for every app |
| `rices` | `~/.config/rices/` | the rices and `auto.conf` |
| `hypr` | `~/.config/hypr/` | `hyprland.lua` (entry), `base.lua`, `hypridle.conf` |
| `quickshell` | `~/.config/quickshell/{rice,nacre}/` | the shared chooser and switch overlay, and Nacre's shell |
| `systemd` | `~/.config/systemd/user/rice-auto.*` | the timer for auto mode |
| `system/greetd` | (not stowed) | the login screen, installed with sudo, see below |

`./install` at the top level sets all of this up; see below.

## Install

```sh
git clone https://github.com/Naved124/ricing ~/ricing
cd ~/ricing
./install
```

That one script:

- installs the packages that are missing (pacman, plus `paru`/`yay` for AUR ones; on
  other distros it lists what to install);
- downloads Italiana, Manrope and IBM Plex Mono into `~/.local/share/fonts/rice` if you
  don't have them;
- moves any file the dotfiles would replace (your old `hyprland.conf`, for instance) to
  `~/.local/state/rice/backup/<time>/`, then links everything with stow;
- creates `~/.config/hypr/local.lua` and copies your monitor and keyboard settings into
  it from the old `hyprland.conf`;
- makes Nacre the active rice, renders every theme, links the app themes, adds the
  include to `kitty.conf` and turns on Firefox's `userChrome.css`;
- reloads Hyprland if you're in it; otherwise log in and it starts by itself.

It's safe to run again. Useful options: `--rice paper` to start on another rice,
`--dry-run` to see what it would do, `--no-deps`, `--auto` for time-of-day switching,
`--greetd` for the login screen, and `--uninstall` to remove the links. `./install --help`
lists them all.

A few apps include the theme rather than having it replaced; the installer prints the one
line to add for each of them (btop, zathura, nvim, Kvantum, qt6ct, Spicetify).

**Requirements:** `hyprland` ≥ 0.55, `quickshell` 0.3, Python 3.11 or newer, `stow`,
`grim`, `slurp`, `jq`, `wl-clipboard`, `cliphist`, `brightnessctl`, `hypridle`,
`hyprsunset`, `playerctl`, `wireplumber`, `kitty`, and the three fonts above.

**Optional, used if present:** `satty` (screenshot editing), `fd` (launcher file search),
`cava` (control-centre visualiser), `hyprpicker`, `imagemagick` (blurred lock
backdrop), `swaync`, `swww`/`mpvpaper` and `hyprlock` (for rices without their own shell),
`nvim`, `gsettings`, `power-profiles-daemon`, `bluez`.

<details><summary>By hand, without the installer</summary>

```sh
# stow refuses to overwrite files: move your own hyprland.lua/.conf aside first
stow --no-folding -t ~ switcher render rices hypr quickshell systemd
ln -sfn nacre ~/.config/rices/current
rice-render --all
rice-render --link --firefox
```

`--no-folding` matters: it keeps `~/.config/rices` a real directory, so `current` and each
rice's `build/` are created there and not inside the repo.
</details>

## Usage

```
rice <name>          switch to a rice
rice next | prev     cycle (Super+Shift+T)
rice choose          toggle the chooser (Super+T)
rice list            list rices, * marks the active one
rice get roles.bg    read a value from the active palette
rice auto on|off     time-of-day switching (see auto.conf)
rice reapply         run every apply step again
rice session         bring the active rice up at login (Hyprland runs this)
rice lock            lock with the rice's own lock screen, or hyprlock
rice-shot region     screenshot (also: screen, window, edit)
```

### Keys

| Keys | Action |
| --- | --- |
| Super+Space | launcher (`=` calculator, `/` files, `:` emoji, `>` run, `?` web, `!` clipboard) |
| Super+V | clipboard history (the launcher in `!` mode) |
| Super+N | control centre |
| Super+Escape | power menu |
| Super+Ctrl+L | lock |
| Super+T / Super+Shift+T | rice chooser / next rice |
| Print, Shift+Print, Super+Print, Ctrl+Print | screenshot a region, the screen, the window, or into satty |
| Super+Shift+C | colour picker |
| Super+Return, E, Q, F, Shift+F, P, G, Tab | terminal, files, close, fullscreen, float, pseudo, group, next in group |
| Super+M | dwindle ⇄ master |
| Super+H/J/K/L (+Shift) | focus (move) |
| Super+1…9 (+Shift) | workspace (move to it) |
| Super+S (+Shift) | scratchpad (send to it) |
| 4-finger swipe left/right | previous / next workspace |

## How a switch works

1. `rice-render <target>` writes the incoming rice's theme files while the old desktop is
   still live, so the frozen moment stays short.
2. `grim` screenshots every monitor, and the always-running shared shell (`qs -c rice`)
   pins the shots above everything (`qs -c rice ipc call rice freeze <dir>`).
3. Under the overlay, `current` is swapped atomically and each step runs:
   - `hyprctl reload` and the cursor;
   - GTK theme, icons, cursor and fonts through `gsettings`;
   - `SIGUSR1` to kitty, and `:colorscheme` to every running nvim;
   - notifications: swaync is stopped when the rice's shell is the daemon, otherwise
     started or reloaded;
   - the wallpaper: the shell draws it, or a `wallpaper/` folder plays through
     `mpvpaper` (video) or `swww` (image);
   - the per-rice Quickshell: `qs kill -c <old>`, then `qs -c <new> -d`;
   - `current/hooks/post-switch`, if the rice has one.

   Steps whose tool or file is missing are skipped. A failing step is logged and the
   switch carries on, so a broken step never leaves the screen frozen. The overlay also
   lets go by itself after 8 s.
4. The overlay dissolves through the incoming rice's `transition.frag`: Nacre's ripple
   with an iridescent wavefront, Urushi's lacquer lid that darkens and lifts away on a
   gold edge, and Paper's page peeled from the corner. A rice without one fades.

Switches are serialised with `flock`, so pressing the key repeatedly just queues them.

## Theme files

`rice-render` reads `palette.toml` and writes every app's theme into the rice's `build/`
folder. Templates live in `render/.local/share/rice/templates/`, and a rice's own
`templates/` folder overrides any of them. It writes themes for kitty, nvim (with
lualine), starship, btop, yazi, fastfetch, GTK 3 and 4, qt6ct, Kvantum, Firefox (chrome
and a start page), Vesktop, Spicetify, mpv/uosc, imv, zathura, ReGreet and Hyprland's
visual layer. A theme for an app you don't use is just an unused file.

Templates use `{{ roles.accent }}`-style placeholders with filters, for example
`{{ roles.bg | rgba(0.8) }}`, `{{ colors.rose | mix(colors.sky, 0.5) }}`,
`{{ gradient.stops | join(", ") }}` or `{{ shape.window | add(4) }}`. The palette's
`[roles]` name colours from `[colors]`, so shared templates work for every rice.

## The login screen

ReGreet under greetd, themed by the active rice. This touches `/etc`, so it's opt-in:
`./install --greetd`, or by hand:

```sh
sudo system/greetd/install            # uses the shell's wallpaper still, or pass an image
sudo systemctl disable <your display manager>; sudo systemctl enable greetd
```

## Adding a rice

1. `mkdir ~/.config/rices/<name>` and write `palette.toml` (copy one of the others). Its
   `[meta]` names the shell, the transition, and who handles notifications, the
   wallpaper and locking.
2. Add `templates/hypr.lua` for borders, rounding, blur and animations, plus any other
   template you want to override.
3. Optionally add a `transition.frag` (compile it with `tools/shaders`), a `card.qml` to
   dress its chooser card (it receives `rice`, `selected`, `active` and `base`, the
   generic card to wrap), and a `preview.png`.

It shows up in `rice list` and the chooser right away.

## Auto mode

`auto.conf` lists `HH:MM rice` lines. The latest time that has passed wins, wrapping
round midnight. The timer checks every 5 minutes but switches only when the scheduled
slot changes, so a manual switch sticks until the next boundary.

## Development

```sh
python3 -m unittest discover -s tests   # render, switch (sandboxed) and Hyprland config tests
tools/regen                             # re-render the committed Theme.qml after a palette edit
tools/shaders                           # recompile *.frag → *.frag.qsb (needs qsb)
tools/emoji                             # rebuild the launcher's emoji list
tools/fake-hyprland                     # a stand-in Hyprland IPC for previewing shells headless
tools/hypr-migrate OLD.conf [local.lua]  # turn an old hyprland.conf's monitors/keyboard into Lua
```

A few notes:

- Hyprland caps animation speed at 10 s, so Nacre's border gradient turns once every 10
  seconds rather than 60.
- `rounding_power = 2` gives ordinary round corners; set it to 4 for true squircles.
- Wi-Fi state comes from Quickshell's NetworkManager module, so `nmcli` is not needed.
