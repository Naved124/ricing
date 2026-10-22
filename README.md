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
  nacre/  paper/  abyss/  satsuei/   ← palette.toml, templates/, card.qml, transition.frag
  current -> nacre/         ← the active rice
```

Four rices ship today:

| Rice | Look | Shell |
| --- | --- | --- |
| **Nacre** | pearl glass, colour only at the edges and in motion | its own Quickshell config: bar with a dynamic island (time, media, notifications), launcher, control centre, OSDs, lock, power menu, live wallpaper |
| **Paper** | sheets on a desk, typewriter and pencil | its own Quickshell config: a taped bar, tear-off calendar, wastebasket, an island whose notifications unfold as sticky notes, index-card launcher, envelope lock, rubber-stamp power menu, and a paper grain over the screen |
| **Abyss** | a night dive on a reef, dark only | its own Quickshell config: a live reef as the wallpaper (jellies, schooling fish, swaying corals, plankton lit by the ripples you make), glass panels floating in it, notification cards that land and sink, a depth-gauge OSD, a jellyfish system card, a lock with its own dimmed reef |
| **Satsuei** | your wallpaper, composited like an anime frame, dark only | its own Quickshell config: your picture with a shader pass over it (bloom, light rays, dust motes, a grade that follows the hour), glass whose every colour comes from the picture, a clock bar with episodes, subtitle notifications, dancing characters (your own GIFs too), an edge mascot, a timesheet system card, a wallpaper selector, an episode title-card lock |

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

### Abyss

Deep water with a living reef in it, and the desktop as glass floating in the water.
It is the port of `docs/abyss/reef-mock.html`, so it has the same water gradient, light
rays, caustics, marine snow, ripples that refract and catch the light, and plankton
that lights up where the water moves. It also has the same jellies (pulsing bells,
trailing tentacles, rim lights), a school of fish that scatters, swaying corals with
glowing tips, sea fans, anemones that pull in when touched, kelp, the ridge and the
floor. Click or drag on the bare desktop to disturb the water; the reef only feels the
pointer where no window covers it. A workspace switch sends a current across in the
direction you moved, a notification makes the nearest jelly flare, and music kicks the
reef on the bass (through the shell's one cava). Without cava it breathes slowly while
something plays.

Abyss is **dark only** (`[meta] modes = ["dark"]`). `rice mode` while it's active still
records your choice for the other rices but changes nothing on screen, and says so in
a toast. It's darker than the night rules allow (the water is near black, the ink
16.6:1), by choice; the terminal colours still keep 4.5:1 and more.

The reef runs on a timer (30 fps by default), not on every frame, and works less when
it can:

- **stopped** (no frames, no simulation) while a window is fullscreen on that screen,
  or while the session is locked (the lock screen has its own reef; hypridle locks before
  the screen turns off)
- **reduced** (15 fps, half the plankton, no bloom) while tiled windows cover 92% of the
  screen, or on battery under 30%

Its settings live in `~/.config/rice/abyss.toml` (copy
`switcher/.local/share/rice/abyss.toml`, which lists the defaults). The shell re-reads
the file as soon as it changes:

| Key | Default | What it does |
| --- | --- | --- |
| `fps` | 30 | the reef's frame rate (15 when reduced) |
| `scale` | 0.55 | what's drawn of the creatures, against the screen's size; the water is always full size |
| `plankton` | 620 | at most this many (a small screen gets fewer) |
| `fish` | 24 | |
| `jellies` | 5 | |
| `interactive` | true | the reef feels the pointer (Super+Ctrl+R toggles it) |
| `music_react` | true | the reef pulses to music |
| `ui_disturbances` | true | cards landing, the launcher, clicks in the bar touch the water |
| `reduce_on_battery` | true | the battery rule above |

To see what it's doing, press Super+Ctrl+Shift+R for an overlay in the corner, or ask:

```sh
qs -c abyss ipc call reef stats      # per screen: fps, ms a frame (world + drawing), sizes,
                                     # entity counts, and why it runs as it does
qs -c abyss ipc call reef interactive false
```

Switching to Abyss floods the screen from the bottom edge; switching away drains it
(`[meta] transition_out`). The greeter, boot menu and splash use the reef's still
frame, `assets/wall-static.png`. Re-render it with `assets/gen.py --still` (under
`xvfb-run` on a headless machine, with PySide6), adding `--size` for another screen.

What Abyss does without:

- **The reef under windows.** It's the wallpaper layer, so only bare desktop feels the
  pointer.
- **Sound.** None, by design.

### Satsuei

The look comes from your wallpaper: `satsuei-wall set <picture>`, or the selector on
Super+Ctrl+W, takes a picture's colours and light source, and the whole desktop (shell,
terminal, GTK, Qt, nvim, Spotify) re-themes to it. The picture is the plate; a shader
pass adds the light, the way the compositing stage of anime production does. Put
pictures in `~/Pictures/Wallpapers` and your own characters (GIFs) in
`~/.config/satsuei/characters/`. Everything is in [docs/satsuei/README.md](docs/satsuei/README.md).

Targets **Hyprland 0.56** (Lua config; 0.55 or newer is needed) and **Quickshell 0.3**.

## Packages

Install with [GNU Stow](https://www.gnu.org/software/stow/). Each folder is a package:

| Package | Installs | What it is |
| --- | --- | --- |
| `switcher` | `~/.local/bin/rice`, `rice-sun`, `rice-shot`, `rice-rec` | the switch script, the sunrise/sunset calculator, the screenshot tool and the screen recorder |
| `render` | `~/.local/bin/rice-render`, `~/.local/share/rice/templates/` | palette → theme files for every app |
| `rices` | `~/.config/rices/` | the rices |
| `hypr` | `~/.config/hypr/` | `hyprland.lua` (entry), `base.lua`, `hypridle.conf` |
| `quickshell` | `~/.config/quickshell/{rice,nacre,paper,abyss}/` | the shared chooser and switch overlay, and Nacre's, Paper's and Abyss's shells |
| `systemd` | `~/.config/systemd/user/rice-mode.*` | the timer for auto mode (light and dark by the sun) |
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
- points git at the repo's hooks (`.githooks/`), so every `git pull` re-links with
  `tools/relink` and new files reach `~/.config` without running stow again;
- creates `~/.config/hypr/local.lua` and copies your monitor and keyboard settings into
  it from the old `hyprland.conf`;
- makes Nacre the active rice, renders every theme, links the app themes, adds the
  include to `kitty.conf` and turns on Firefox's `userChrome.css`;
- reloads Hyprland if you're in it; otherwise log in and it starts by itself.

It's safe to run again. Useful options: `--rice paper` to start on another rice,
`--dry-run` to see what it would do, `--no-deps`,
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
uses it), PipeWire with every Bluetooth codec Arch has (LDAC, aptX, aptX HD, AAC, LC3)
and the sound firmware laptops need (`sof-firmware`, `alsa-ucm-conf`), Bluetooth, the
Hyprland and GTK portals, a polkit agent, Firefox,
Nautilus, Noto fonts, GNOME Keyring and the Mesa/Vulkan/video drivers for an Intel
or AMD GPU. It builds `paru` from source for the AUR-only themes (a few
minutes; a prebuilt `paru-bin` breaks whenever pacman updates its library), offers the
LHDC codec from the AUR (see Audio below), hands the
network from iwd to NetworkManager at the next boot, enables the Bluetooth and
power-profiles services, and does everything `--system`
does. After the reboot you get the themed Limine menu, the splash, ReGreet, and then
the desktop.

### Audio

Every rice gets the same sound setup (the `audio/` package, PipeWire and WirePlumber
drop-ins):

- **Wired**: the card switches to the music's own rate (44.1, 48, 88.2, 96, 176.4 or
  192 kHz) instead of resampling everything to 48 kHz; when a stream must be resampled,
  it's at the best quality; the jack never suspends, so sound starting doesn't pop.
- **Bluetooth**: LDAC (adaptive, from 990 kbps), aptX, aptX HD, AAC (highest bitrate),
  LC3, SBC-XQ, and LHDC v5 if you said yes to it. The headphones get the best codec you
  both have. Opening a mic no longer drops music to the phone-quality call profile; pick
  the headset profile yourself for a call.
- The codec in use: `pactl list cards | grep -i codec`; the rate the card runs at: `pw-top`.
- LHDC comes from the AUR (`liblhdcv5 pipewire-bluez5-lhdc-git wireplumber-lhdc-config`)
  and runs PipeWire's development Bluetooth plugins. If Bluetooth audio ever stops after
  an update, remove them with `yay -Rns` and the other codecs come back.

How each app follows the rice:

| App | How | When a switch shows up |
| --- | --- | --- |
| GTK apps | `gsettings` theme, icons, cursor and fonts, plus a linked `gtk.css` | at once (open GTK 3 apps on restart) |
| Qt apps | qt6ct with the rice palette, drawn by Qt's Fusion style (`QT_QPA_PLATFORMTHEME=qt6ct` is set in `base.lua`) | on restart |
| Firefox, Zen, LibreWolf | `userChrome.css` / `userContent.css` linked into every profile, with the pref turned on in `user.js` | on restart; websites keep their own colours |
| Spotify | Spicetify's Rice theme (Spicetify comes from its official release, set up and applied for you when Spotify is installed) | next time Spotify starts |
| mpv | `include="~~/rice.conf"` in `mpv.conf` for the on-screen text, `osc.conf` for the built-in controls, `uosc.conf` if you use uosc | next file opened |
| Telegram Desktop | `~/.local/share/rice/active/telegram/rice.tdesktop-theme`: open it in Telegram | only when you open it again; Telegram can't follow by itself |
| kitty, nvim | include line / colorscheme; reloaded live | at once |

A few more include the theme rather than having it replaced; the installer prints the one
line to add for each (btop, zathura, nvim).

**Requirements:** `hyprland` ≥ 0.55, `quickshell` 0.3, Python 3.11 or newer, `stow`,
`grim`, `slurp`, `jq`, `wl-clipboard`, `cliphist`, `brightnessctl`, `hypridle`,
`hyprsunset`, `playerctl`, `wireplumber`, `kitty`, and the three fonts above.

**Optional, used if present:** `satty` (screenshot editing), `fd` (launcher file search),
`cava` (the island's glow and the visualisers), `wf-recorder` (screen recording), `hyprpicker`, `imagemagick` (blurred lock
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
rice mode dark       light or dark, for every rice (also: light, toggle; --instant)
rice mode auto       light by day and dark by night, from ~/.config/rice/mode.toml (off: stop)
rice mode status -v  the mode, where it came from, the next switch, the last switch's time
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
| Super+Alt+D / Super+Alt+Shift+D | light ⇄ dark / auto (by the sun) |
| Super+Ctrl+R / Super+Ctrl+Shift+R | Abyss: the reef feels the pointer or not / its stats overlay |
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
   - `hyprctl reload`, and the cursor if it changes (one for every rice: Bibata Modern
     Classic in light mode, Ice in dark and dark-only rices);
   - GTK theme, icons and fonts through `gsettings`;
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
   with an iridescent wavefront, and Paper's page peeled from the corner. A rice without
   one fades.

Switches are serialised with `flock`, so pressing the key repeatedly just queues them.

## Light and dark

Every rice is rendered in both modes, into `build/light/` and `build/dark/`, and
`~/.local/share/rice/active` points at the active rice's build in the active mode. Every
app's theme links through it. The mode is global: `rice paper` while dark opens Paper in
dark. `rice mode dark` changes the light without reloading anything:

1. freezes the screen as a switch does (skipped with `--instant`, when animations are off,
   or on a battery under 20%; the shells then crossfade over 200 ms instead);
2. writes `~/.local/state/rice/mode` and re-points `active`;
3. sends Hyprland the mode's `hypr-mode.lua` (borders, shadows, blur, background, the
   screen shader) with one `hyprctl eval`;
4. sets GTK's colour scheme, theme and icons with `gsettings`;
5. signals kitty and cava, re-applies nvim's colourscheme, and switches Spotify's scheme;
6. tells the shells, which crossfade every colour (they also watch the state file);
7. lets the frozen frame go with the rice's own reveal. In Paper the lamp clicks: going
   dark, the night closes in from the edges to the desk lamp (top left) behind a warm amber
   edge; going light, the lamp's pool grows until the room is lit (900 ms). Set
   `sound = true` in `~/.config/rice/mode.toml` for the pull-chain click (`pw-play`). In
   Nacre the pearl turns: a thin iridescent ring in the new mode's colours grows from the
   bar's orb with a glint running round it (800 ms).

**Paper Night** is the same desk under a lamp in the top-left corner: walnut-charcoal
under a dark sheet, cream type, gel-blue ink and coral where Paper was red, with the
lamp's warm pool on the wallpaper and the lock screen. Notes become black card with a
coloured strip of adhesive, the washi tape lets more dark through, and the grain's
fibres lighten instead of darkening, under a faint lamp vignette (`lamp_vignette` in
`[modes.dark.meta]`, 0 turns it off). Pull the chain hanging from the bar's right-hand
tape to switch; the control centre's "lamp" goes light → dark → auto.

**Black Pearl** is Nacre at night: a Tahitian black pearl. Smoked-pearl glass over a
dark body whose blooms drift through peacock, sapphire, aubergine and rose, silver growth
lines and a faint orient sheen that crosses every 40 s; borders and rings in the dark
orient stops, and a 1 px specular edge instead of white highlights. The screenshot flash
becomes an iridescent outline pulse, never white. Right-click the orb, or use the
control centre's "Black pearl" tile (light → dark → auto; right-click for auto on or off).
`tools/render-wall dark` renders the wallpaper's still (`assets/wall-static-dark.png`),
which the luminance test checks.

Both control centres also have **performance** (power-profiles-daemon: click for
performance or balanced, right-click for the power saver) and **microphone** (mute)
toggles.

### The island

The middle of each bar is an island, on a layer of its own so it can grow. It always
shows the time (hover for the date, click it for the calendar) and the notifications
waiting (a bell and a count in Nacre, "3 notes" in Paper, or a dot when there are none).
The window's title sits on the left, after the workspaces; a title or track too long
for its room scrolls past and comes round again.

- **Something playing**: the cover, the track and a small visualizer join the time, and
  the island glows with the music's beat. In Nacre it's a pearl-glass pill ringed with
  the orient, like a focused window's border; in Paper it's a tab of paper with the cover
  pinned on like a photo and the desk lamp's warmth underneath (the highlighter's yellow
  by day, the lamp's straw at night). Hover widens it for play/pause and next. It follows
  whichever player is playing.
- **A notification**: the island grows into its card for 4 s (hover holds it): pearl
  glass in Nacre, a sticky note in Paper. Its actions are there, × (or "peel") dismisses
  it, and so does a swipe sideways. More wait their turn. With Do Not Disturb on only the
  count goes up; critical ones still open. There are no other popups.
- **A click**: it grows into a panel with what's playing on top and the notification
  history below, with "Clear all" ("clear desk" in Paper). Esc or a click outside closes
  it.

Notifications open on the focused monitor, even over a fullscreen window. The control
centre no longer carries media or notifications. The glow and visualizers come from one
cava per shell (`services/Beat.qml`, only while something plays; install `cava` for
them). Nacre's system tray icons are always out on the right of the bar.

### System card

Every desktop carries a **system card** under the windows. In Nacre and Paper it shows CPU and memory as Material 3
style dials, and the root disk as a bar with used, free and total sizes. Paper draws it
as an index card taped to the desk (red pen for CPU, ink for memory, pencil hatching for
the used disk); Nacre as a pane of pearl glass with the orient's colours. Both follow
light and dark live. Abyss's is one of the reef's jellyfish: the CPU in its bell, its
rim lights running faster the busier it is, and three tentacles (CPU teal, memory violet,
disk pink) lit down their length as far as each value goes. Drag it anywhere; it stays where you leave it (`shell.json` in the
shell's state folder). Right-click puts it away, and the control centre's "system card"
brings it back. It hides while a window is fullscreen. One reader samples `/proc/stat`
and `/proc/meminfo` every 2 s and `df /` every 30 s (`services/Sys.qml`).

What follows the change, and when:

| App | When |
| --- | --- |
| Quickshell, Hyprland, kitty, nvim, cava | at once |
| Firefox (chrome, its own pages, and sites with a dark mode), libadwaita/GTK4 and other portal-aware apps (Chromium, Electron) | at once, through the desktop's colour scheme |
| Spotify | after Spicetify's refresh, a moment later |
| yazi | new windows (it picks a flavour from the terminal's background when it starts) |
| btop, fastfetch, zathura | the next time they start |
| GTK3 and Qt apps that are already open | only fully when restarted |
| Telegram | when you open its theme file again |
| the boot menu, the splash and the login screen | never: they run before anyone logs in, so they stay light |

Not covered, on purpose:

- **Already-open GTK3 and Qt apps** that don't listen for theme changes only switch fully
  when restarted; libadwaita/GTK4 and portal-aware apps (Firefox, Chromium, Electron)
  switch live.
- **The login screen** (ReGreet) stays on the light build: it runs before login and can't
  know the mode. A clean way to darken it at night would be a small greetd pre-start
  hook that compares the time with the last sunrise and sunset `rice-sun` cached and
  copies `build/dark/regreet.css` over the light one; it isn't built.
- **Websites** follow their own dark mode through Firefox's colour scheme; there's no
  Dark Reader or other extension forcing it.

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
folder, once per mode (`build/light/` and `build/dark/`). Apps read them through
`~/.local/share/rice/active`, which points at the active rice's build in the active mode. Templates live in `render/.local/share/rice/templates/`, and a rice's own
`templates/` folder overrides any of them. It writes themes for kitty, nvim (with
lualine), starship, zsh highlighting, btop, yazi, fastfetch, GTK 3 and 4, qt6ct, Firefox (chrome
and a start page), Vesktop, Spicetify, mpv/uosc, imv, zathura, cava (in a terminal),
ReGreet and Hyprland's visual layer. A theme for an app you don't use is just an unused
file. Paper overrides kitty (Courier Prime on a tiled paper texture), nvim and lualine,
btop (graph paper), yazi (a manila folder), fastfetch (a typed typewriter), cava (ink),
the Firefox start page (ruled paper) and ReGreet. Abyss overrides kitty (glass-pill tabs),
nvim (violet keywords, teal functions, the glass for floats), btop (teal → violet → pink),
cava, yazi (a teal line for the current row), fastfetch (a jellyfish) and zathura.

Templates use `{{ roles.accent }}`-style placeholders with filters, for example
`{{ roles.bg | rgba(0.8) }}`, `{{ colors.rose | mix(colors.sky, 0.5) }}`,
`{{ gradient.stops | join(", ") }}`, `{{ shape.window | add(4) }}` or
`{{ roles.accent | readable }}` (the rice's text colour, or its background when the text
wouldn't read on that colour, as on Paper's ink blue). The palette's
`[modes.light.roles]` name colours from `[modes.light.colors]`, so shared templates work
for every rice; templates see them as `roles` and `colors`.

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

## Network

Every rice has the same network widget: right-click or double-click the Wi-Fi tile in the
control centre (or run `qs -c rice ipc call network open`). It's drawn in the active rice's
colours, fonts and corners. In it you can:

- turn Wi-Fi on or off and rescan
- join a network (a password is asked for once and kept by NetworkManager), or a hidden one
- see your address, gateway and DNS, and set DNS servers: the network's own, Cloudflare,
  Google, Quad9 or your own list
- for each saved network: whether it joins on its own, show its password, forget it

It talks to NetworkManager through `nmcli`. To have NetworkManager drive Wi-Fi through
**iwd** instead of wpa_supplicant:

```sh
sudo system/install --network     # from the next boot; --undo puts it back
```

That writes `wifi.backend=iwd` to `/etc/NetworkManager/conf.d/rice-iwd.conf`, enables
iwd and turns off wpa_supplicant. Your saved networks stay. The bar shows one network
mark: a network applet's own tray icon (nm-applet, iwgtk) is left out.

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
   dress its chooser card (it receives `rice`, `selected`, `active`, and if it declares
   them `base`, the generic card to wrap, and `mode`; `rice.meta`'s colours are the
   current mode's, crossfading with it), and a `preview.png`.

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

Light by day, dark by night, worked out offline: `rice-sun` computes sunrise and sunset
for your place with NOAA's solar calculator. `./install` copies a settings file to
`~/.config/rice/mode.toml`. Its latitude and longitude (rounded to a degree is plenty)
default to a built-in location, 22.12° N 78.10° E, which is also used when they're left
blank; change them if you move, then turn it on:

```toml
lat = 22.12232
lon = 78.10159
offset_minutes_dark  = -20   # dark 20 minutes before sunset
offset_minutes_light = 20    # light 20 minutes after sunrise
```

```
rice mode auto       # follow the sun from now on (and switch now if it's due)
rice mode status     # e.g. "dark · auto · light at 06:41"
rice mode auto off   # stay in whatever mode you're in
```

The `rice-mode.timer` user timer runs `rice mode tick` every 5 minutes, at login and
after resume, and applies the sun's mode. A `rice mode light` or `dark` while auto is
on holds until the next sunrise or sunset and then auto takes over again
("light · held until 18:02 (then auto)"). In polar day it stays light and in polar
night dark. The chooser's footer is a `light · dark · auto` pill (or `d` and `a` in it)
with the next switch beside it; its cards show each rice in the current mode, with a sun
or moon in the corner. Which rice you use is always your choice. The night light
(hyprsunset) is separate and isn't touched.

## Development

```sh
python3 -m unittest discover -s tests   # render, switch (sandboxed) and Hyprland config tests
tools/regen                             # re-render the committed Theme.qml after a palette edit
tools/relink                            # re-link the dotfiles (git pull does it through .githooks/)
tools/shaders                           # recompile *.frag → *.frag.qsb (needs qsb)
tools/emoji                             # rebuild the launcher's emoji list
tools/fake-hyprland                     # a stand-in Hyprland IPC for previewing shells headless
tools/hypr-migrate OLD.conf [local.lua]  # turn an old hyprland.conf's monitors/keyboard into Lua
tests/qs_smoke.py quickshell/.config/quickshell/abyss   # start a shell under PySide6 and list QML errors
```

The shell tests run each shell under PySide6 against stand-ins for Quickshell's own
types (`tests/qsstub/`), so a binding error, a TypeError or a bad property fails a test
without Quickshell or a compositor. They skip when PySide6 isn't installed.

A few notes:

- Hyprland caps animation speed at 10 s, so Nacre's border gradient turns once every 10
  seconds rather than 60.
- `rounding_power = 2` gives ordinary round corners; set it to 4 for true squircles.
- Wi-Fi state comes from Quickshell's NetworkManager module, so `nmcli` is not needed.
