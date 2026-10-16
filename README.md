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
| **Paper** | sheets on a desk, typewriter and pencil | its own Quickshell config: a taped bar, tear-off calendar, wastebasket, sticky-note notifications, index-card launcher, envelope lock, rubber-stamp power menu, and a paper grain over the screen |

### Paper

A desk in daylight, all light: no blur, no transparency, no borders. Windows are
sheets with warm brown shadows, the terminal is a typewriter on paper stock, and
Hyprland draws a faint paper grain over everything (`rice grain off` or Super+Shift+G
turns it off, for games and video). Switching workspace turns a page: Hyprland slides
the workspaces sideways and the shell draws the turning page's back along the seam. The wallpaper, the paper texture and the stamp wear
are drawn by `rices/.config/rices/paper/assets/gen.py` (needs `python-pillow`); the
committed ones are 1920×1080, so for another screen run it with `--size 2560x1440`, then
restart the shell.

Closing a window drops a crumpled ball in the wastebasket on the desk. Click the
basket to fish the last one out (it starts again from its command line), or empty it.
Only apps it could start again count: floating dialogs and windows the shell opened
itself are left out, and it holds up to 20.

What Hyprland and Quickshell can't do, so Paper does without:

- **Tilted windows and the crumple.** Hyprland can't rotate or deform a client window.
  Shadows and a `popin` close stand in. Only the shell's own sheets tilt, and never one
  you type into.
- **Typewriter key sounds.** They'd need a global key listener.
- **A wider shadow for the focused window.** Hyprland has one shadow range; only the
  colour changes with focus.
- **kitty's typed look.** No per-character jitter or ink spread; the paper texture is
  its background image.
- **Yazi's manila panes.** Yazi themes can't colour a pane's background, so the kraft is
  in the tabs, mode pills and the hovered row.
- **Kvantum.** Qt apps get Fusion and qt6ct like every rice (Kvantum's artwork broke
  light rices).

Targets **Hyprland 0.56** (Lua config; 0.55 or newer is needed) and **Quickshell 0.3**.

## Packages

Install with [GNU Stow](https://www.gnu.org/software/stow/). Each folder is a package:

| Package | Installs | What it is |
| --- | --- | --- |
| `switcher` | `~/.local/bin/rice`, `rice-shot`, `rice-rec` | the switch script, the screenshot tool and the screen recorder |
| `render` | `~/.local/bin/rice-render`, `~/.local/share/rice/templates/` | palette → theme files for every app |
| `rices` | `~/.config/rices/` | the rices and `auto.conf` |
| `hypr` | `~/.config/hypr/` | `hyprland.lua` (entry), `base.lua`, `hypridle.conf` |
| `quickshell` | `~/.config/quickshell/{rice,nacre,paper}/` | the shared chooser and switch overlay, and Nacre's and Paper's shells |
| `systemd` | `~/.config/systemd/user/rice-auto.*` | the timer for auto mode |
| `fonts` | `~/.local/share/fonts/paper/` | Paper's OFL fonts: Courier Prime, Kalam, Newsreader (licences beside them) |
| `zsh` | `~/.config/zsh/rice.zsh` | the shell setup, sourced from `~/.zshrc` (see Shell) |
| `system` | (not stowed) | the boot menu, splash and login screen, installed with sudo, see below |

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
- links Paper's fonts (Courier Prime, Kalam, Newsreader, all OFL) from the repo's `fonts/`
  package and refreshes the font cache;
- moves any file the dotfiles would replace (your old `hyprland.conf`, for instance) to
  `~/.local/state/rice/backup/<time>/`, then links everything with stow;
- creates `~/.config/hypr/local.lua` and copies your monitor and keyboard settings into
  it from the old `hyprland.conf`;
- makes Nacre the active rice, renders every theme, links the app themes, adds the
  include to `kitty.conf` and turns on Firefox's `userChrome.css`;
- reloads Hyprland if you're in it; otherwise log in and it starts by itself.

It's safe to run again. Useful options: `--rice paper` to start on another rice,
`--dry-run` to see what it would do, `--no-deps`, `--auto` for time-of-day switching,
`--system` for the boot menu, splash and login screen, and `--uninstall` to remove the links. `./install --help`
lists them all.

### On a new Arch install

Starting clean avoids leftovers from another desktop, like SDDM still owning the
login. In archinstall pick **Limine** as the bootloader and the **Minimal** profile (no
desktop), and create your user with sudo. Then, at the text login after the first boot:

```sh
sudo pacman -S --needed git
git clone https://github.com/Naved124/ricing ~/ricing
cd ~/ricing && ./install --fresh
reboot
```

`--fresh` adds what a minimal system lacks: NetworkManager (the bar's network widget
uses it), PipeWire, Bluetooth, the Hyprland and GTK portals, a polkit agent, Firefox,
Nautilus, Noto fonts, GNOME Keyring and the Mesa/Vulkan/video drivers for an Intel
or AMD GPU. It builds `paru` from source for the AUR-only themes (a few
minutes; a prebuilt `paru-bin` breaks whenever pacman updates its library), hands the
network from iwd to NetworkManager at the next boot, enables the Bluetooth and
power-profiles services, and does everything `--system`
does. After the reboot you get the themed Limine menu, the splash, ReGreet, and then
the desktop.

How each app follows the rice:

| App | How | When a switch shows up |
| --- | --- | --- |
| GTK apps | `gsettings` theme, icons, cursor and fonts, plus a linked `gtk.css` | at once (open GTK 3 apps on restart) |
| Qt apps | qt6ct with the rice palette, drawn by Qt's Fusion style (`QT_QPA_PLATFORMTHEME=qt6ct` is set in `base.lua`) | on restart |
| Firefox, Zen, LibreWolf | `userChrome.css` / `userContent.css` linked into every profile, with the pref turned on in `user.js` | on restart; websites keep their own colours |
| Spotify | Spicetify's Rice theme (Spicetify comes from its official release, set up and applied for you when Spotify is installed) | next time Spotify starts |
| mpv | `include="~~/rice.conf"` in `mpv.conf` for the on-screen text, `osc.conf` for the built-in controls, `uosc.conf` if you use uosc | next file opened |
| Telegram Desktop | `~/.config/rices/current/build/telegram/rice.tdesktop-theme`: open it in Telegram | only when you open it again; Telegram can't follow by itself |
| kitty, nvim | include line / colorscheme; reloaded live | at once |

A few more include the theme rather than having it replaced; the installer prints the one
line to add for each (btop, zathura, nvim).

**Requirements:** `hyprland` ≥ 0.55, `quickshell` 0.3, Python 3.11 or newer, `stow`,
`grim`, `slurp`, `jq`, `wl-clipboard`, `cliphist`, `brightnessctl`, `hypridle`,
`hyprsunset`, `playerctl`, `wireplumber`, `kitty`, and the three fonts above.

**Optional, used if present:** `satty` (screenshot editing), `fd` (launcher file search),
`cava` (control-centre visualiser), `wf-recorder` (screen recording), `hyprpicker`, `imagemagick` (blurred lock
backdrop), `swaync`, `swww`/`mpvpaper` and `hyprlock` (for rices without their own shell),
`nvim`, `gsettings`, `power-profiles-daemon`, `bluez`.

<details><summary>By hand, without the installer</summary>

```sh
# stow refuses to overwrite files: move your own hyprland.lua/.conf aside first
stow --no-folding -t ~ switcher render rices hypr quickshell systemd fonts zsh
fc-cache -f ~/.local/share/fonts/paper
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
rice next | prev     cycle (Super+Ctrl+T)
rice choose          toggle the chooser (Super+Shift+T)
rice list            list rices, * marks the active one
rice get roles.bg    read a value from the active palette
rice auto on|off     time-of-day switching (see auto.conf)
rice reapply         run every apply step again, restarting the rice's shell
rice session         bring the active rice up at login (Hyprland runs this)
rice lock            lock with the rice's own lock screen, or hyprlock
rice grain off|on    the rice's screen shader (Paper's paper grain); remembered
rice logout          end the session and go back to the login screen
rice system          re-theme the boot menu, splash and login screen (sudo)
rice-shot region     screenshot (also: screen, window, edit)
rice-rec toggle      record the screen to ~/Videos, again to stop (also: region)
```

### Keys

| Keys | Action |
| --- | --- |
| Super (tap on its own), Super+Space | launcher, ready to type (`=` calculator, `/` files, `:` emoji, `>` run, `?` web, `!` clipboard) |
| Super+/ | the key sheet: every bind, live from Hyprland, type to filter |
| Super+T or Super+Return, Super+W, Super+E | terminal, browser (your default), files |
| Super+V | clipboard history (the launcher in `!` mode) |
| Super+N | control centre |
| Super+Escape | power menu |
| Super+L | lock |
| Super+Shift+T / Super+Ctrl+T | rice chooser / next rice |
| Super+Shift+G | Paper's grain on or off (it stops games and video skipping the compositor) |
| Print, Shift+Print, Super+Print, Ctrl+Print | screenshot a region, the screen, the window, or into satty |
| Super+Shift+C | colour picker |
| Super+Shift+R / Super+Alt+R | record the screen / an area to `~/Videos` (again to stop); also in the control centre |
| Super+Q, F, Shift+F, P, G, Tab | close, fullscreen, float, pseudo, group, next in group |
| Super+M | dwindle ⇄ master |
| Super+H/J/K/arrows (+Shift, also L) | focus (move) |
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

## Shell

zsh is set up the same way in every rice; only its colours follow the rice. `./install`
adds one line to `~/.zshrc`, and anything you write after it wins:

```sh
[ -f ~/.config/zsh/rice.zsh ] && source ~/.config/zsh/rice.zsh
```

- **Prompt:** Starship with the rice's `starship.toml`: an Arch glyph, folder glyphs
  (home, Documents, Downloads, Music, Pictures, Videos, Projects, Code, .config), a
  GitHub or GitLab glyph inside repositories, the branch, and language versions.
- **Completion:** an arrow-key menu (Shift+Tab goes back), case-insensitive and
  partial-word matching (`dow` finds `Downloads`), plus `zsh-completions`.
- **Suggestions:** `zsh-autosuggestions` from history, then completion; → or Ctrl+Space
  accepts.
- **Highlighting:** `zsh-syntax-highlighting` in the rice's terminal colours (commands
  green, aliases and functions violet, unknown commands red, strings amber, options
  blue). Open shells pick up a rice switch on their next prompt.
- **History:** 50 000 shared lines; Up/Down search for what's already typed.
- **ls:** `eza` with icons (`ls`, `ll`, `la`, `lt`) when it's installed.

Packages: `zsh starship eza zsh-autosuggestions zsh-syntax-highlighting
zsh-history-substring-search zsh-completions ttf-nerd-fonts-symbols-mono` (the glyphs need
the Nerd Font symbols; kitty 0.36+ also has them built in). Make zsh your shell with
`chsh -s /usr/bin/zsh`, then `exec zsh`.

## Theme files

`rice-render` reads `palette.toml` and writes every app's theme into the rice's `build/`
folder. Templates live in `render/.local/share/rice/templates/`, and a rice's own
`templates/` folder overrides any of them. It writes themes for kitty, nvim (with
lualine), starship, zsh highlighting, btop, yazi, fastfetch, GTK 3 and 4, qt6ct, Firefox (chrome
and a start page), Vesktop, Spicetify, mpv/uosc, imv, zathura, cava (in a terminal),
ReGreet and Hyprland's visual layer. A theme for an app you don't use is just an unused
file. Paper overrides kitty (Courier Prime on a tiled paper texture), nvim and lualine,
btop (graph paper), yazi (a manila folder), fastfetch (a typed typewriter), cava (ink),
the Firefox start page (ruled paper) and ReGreet.

Templates use `{{ roles.accent }}`-style placeholders with filters, for example
`{{ roles.bg | rgba(0.8) }}`, `{{ colors.rose | mix(colors.sky, 0.5) }}`,
`{{ gradient.stops | join(", ") }}`, `{{ shape.window | add(4) }}` or
`{{ roles.accent | readable }}` (the rice's text colour, or its background when the text
wouldn't read on that colour, as on Paper's ink blue). The palette's
`[roles]` name colours from `[colors]`, so shared templates work for every rice.

## Boot and login

From power-on to the desktop in the rice's colours: the **Limine** boot menu, a
**Plymouth** splash, and **ReGreet** under greetd as the login screen. These live in
`/boot` and `/etc`, so a separate script installs them with sudo:

```sh
sudo system/install --all          # or pick: --limine --plymouth --greetd
sudo system/install --dry-run --all   # see what it would change first
sudo system/install --undo         # put back everything the last run changed
```

- **Limine**: colours, font size and the wallpaper's still frame go into a marked block
  at the top of `limine.conf`. Boot entries are never touched, so
  `limine-entry-tool` keeps managing them. If Secure Boot is on, it skips Limine,
  because changing an enrolled `limine.conf` would stop it booting.
- **Plymouth**: installs the `rice` splash theme, adds the `plymouth` hook to
  `mkinitcpio.conf`, puts `quiet splash` on the kernel command line, and rebuilds the
  initramfs.
- **greetd**: copies ReGreet's settings and the wallpaper into `/etc/greetd`, then
  switches the display manager (SDDM, GDM, …) to greetd from the next boot. Your
  running session isn't touched.
- **Keyring**: adds GNOME Keyring to greetd's PAM file, so the password you type at
  ReGreet also unlocks it and apps can keep their sign-ins.

Every changed file is backed up to `/var/backups/rice/<time>/` first. After switching rice,
`rice system` re-themes whichever of the three you set up (it asks for sudo).

**Log out** (power menu, or `rice logout`) uses `uwsm stop` under uwsm, else
`hyprshutdown`, which closes apps gracefully (install it for that), else Hyprland's exit.
If the session is still up a few seconds later, it ends it with
`loginctl terminate-session`, so you always land back on the login screen.

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

## Idle

`hypr/.config/hypr/hypridle.conf` picks its timings from the power source:

| | dim | lock | screen off | sleep |
| --- | --- | --- | --- | --- |
| plugged in | 4:30 | 5 min | 8 min | 10 min |
| on battery | 2:30 | 3 min | 4 min | 5 min |

Unplugging while idle moves you onto the battery timings within 30 s. **Caffeine** in the
control centre (or `qs -c nacre ipc call shell caffeine`) holds all of it off until you
turn it off or the shell restarts; a cup in the bar shows while it's on.

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
