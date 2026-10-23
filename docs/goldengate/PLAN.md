# Golden Gate: plan

Golden Gate is macOS 27 ("Golden Gate"), behaviour as well as looks, on Hyprland 0.56 (Lua config)
with a Quickshell-only shell. The full brief is the user's original request; this file is the plan,
the decisions already made and what has been verified. Step 0 is finished on the laptop (see
"Start here").

## Start here (for the session on the laptop)

1. Read `CLAUDE.md` first. Everything in its house rules applies.
   - Commit as `Naved124 <nk7987513533@gmail.com>`, with plain messages and no attribution lines.
   - Commit straight to `main`.
   - Use `yay -S --needed`, never system pip.
   - No colour literals in QML.
   - Don't break the other rices.
2. Run `hyprctl version`, `qs --version` and `yay -Si <name>` for every package below.
   - Fill in the "Verified on the laptop" table.
   - Pick the closest maintained alternative for any name that's gone, and note it there.
3. Run `hyprpm add https://github.com/hyprnux/hyprglass` on the branch that matches the installed
   Hyprland (`hyprland-0.56`), then `hyprpm add https://github.com/hyprwm/hyprland-plugins` (for
   hyprbars).
   - Build with `hyprpm update`, but **never `hyprpm enable`**.
   - Record the `.so` paths hyprpm builds to (under `/var/cache/hyprpm/$USER/`).
4. Commit this file as step 0, then work through the steps below: one commit per step, and a push
   after steps 5, 11, 17 and 23.
5. After every step:
   - run `rice goldengate` and read the Quickshell log
   - fix every QML warning
   - take `grim` shots in light and dark and look at them
   - run `python3 -m unittest discover -s tests`

## Decisions already made by the user

- **Binds:** Golden Gate swaps in its own macOS bind set while it is active, and the shared set
  from `base.lua` comes back on switch-away. Other rices are untouched.
  - Document it in CLAUDE.md as a Golden Gate exception, the way Satsuei's are.
  - A test checks that no Golden Gate bind is in `base.lua`.
- **No global Ctrl grabs:** apps keep Ctrl+arrows, Ctrl+1–9, F4 and F11.
  - Spaces: Super+Alt+Left/Right and Super+Alt+1–9.
  - Mission Control / App Exposé: Super+Alt+Up / Super+Alt+Down.
  - Apps: Super+F4. Show Desktop: Super+F11.
  - Gestures and hot corners stay as in the brief.
- **Qt:** Kvantum MacTahoe, but only while Golden Gate is active.
  - Switching away restores Fusion + qt6ct exactly as it was.
  - CLAUDE.md's "Kvantum was dropped" still holds for every other rice.
- **Ask first:** the SDDM theme and the keyd remap are written and shown as a diff only. They are
  installed only after the user says yes.

## Verified so far (from this repo and hyprglass's README)

- The repo uses the Lua config.
  - `hypr/.config/hypr/hyprland.lua` loads `base`, then `~/.local/share/rice/active/hypr.lua`,
    then `local`.
  - Binds are `bind(key(...), action, "Group · what")` in `base.lua`.
  - Rice-only binds are GlobalShortcuts that only that rice's shell registers (Satsuei's
    `quickshell:satsuei-*`).
- `docs/goldengate/refs/` has three phone captures of Reddit posts (not committed): KDE Liquid
  Glass over a wood wallpaper (strong edge refraction, clear centres), KDE MacTahoe light (white,
  saturated frost, dock with squircle icons) and a frosted Dolphin. They are the look to match.
- **hyprglass** (hyprnux/hyprglass, BSD-3) has stable `hyprland-X.Y` branches; `main` tracks
  hyprland-git.
  - **Lua:** `hg.config{...}`, `hg.layer("ns", {...})` and `hg.preset(...)`, guarded by
    `if hl.plugin.hyprglass then`.
  - **Global options:** `enabled`, `manage_window_blur` (default true; it sets `noblur` on glassed
    windows, so there is no double blur), `skip_opaque_windows`, `blur_fold`, `default_theme`
    (`light`/`dark`), `default_preset` (built-ins: `pomme`, `high_contrast`, `subtle`, `clear`,
    `glass`).
  - **Appearance:** `blur_strength`, `refraction_strength`, `chromatic_aberration`,
    `fresnel_strength`, `specular_strength`, `tint_color`, `glass_opacity`, `edge_thickness`,
    `edge_thickness_px`, `edge_height`, `frost`, `noise_strength`, …
  - **Per theme:** a `light = {}` / `dark = {}` block with `brightness`, `contrast`, `saturation`,
    `vibrancy`, `adaptive_dim` and `adaptive_boost`. The tags `hyprglass_theme_dark` and
    `hyprglass_theme_light` override the theme per window.
  - **Layers:** `layers:enabled` (off by default), `layers:namespaces` (whitelist; empty means
    all), `layers:exclude_namespaces`, `mask_mode` (`auto`/`region`/`alpha`/`contour`),
    `mask_threshold` (default 0.001, can be set per layer), and `layers:manage_blur` (default on).
  - **Status:** `hyprctl hyprglass status -j` says whether it is active and why a feature isn't.
    There are also `stats` and `items`.
  - Re-check every name against the README of the branch you actually build.

## Verified on the laptop (2026-10-23)

`hyprctl version`: Hyprland 0.56.2 (tag v0.56.2). `qs --version`: Quickshell 0.3.2 (Arch `extra`).
Every name was checked with `yay -Si`; "have" means it's already installed.

| Want | `yay -Si` result / replacement |
|---|---|
| hyprland, quickshell (0.3+), xdg-desktop-portal-hyprland, xdg-desktop-portal-gtk | all `extra`, have |
| hypridle, hyprsunset, hyprpicker, qt6-shadertools, qt6-5compat | all `extra`, have |
| hyprpm (not in the brief) | `extra` 0.56.2: Arch splits it out of `hyprland`; needed to build the plugins. **To install** |
| hyprliquid (AUR, fallback glass backend) | `aur` 0.2.1. **To install** |
| mactahoe-gtk-theme, mactahoe-icon-theme | `mactahoe-gtk-theme` `aur` 2026.09.10. `mactahoe-icon-theme` is gone: **`mactahoe-icon-theme-git`** (`aur`) instead. Every colour variant comes from vinceliuice's `install.sh` (`-c light -c dark -t all -o normal`, plus `-l` for libadwaita), run by `gg-theme install` into `~/.themes`, since the AUR build ships only the default variants |
| MacTahoe Kvantum, kvantum, qt6ct, apple_cursor | no Kvantum MacTahoe package (`kvantum-theme-mactahoe*` missing): taken from **vinceliuice/MacTahoe-kde**'s `Kvantum/` into `~/.config/Kvantum` by `gg-theme install`. `kvantum` `extra`, **to install**. `qt6ct` have. `apple_cursor` `aur` 2.0.1, **to install** |
| apple-fonts / otf-apple-sf-pro / otf-apple-sf-mono / otf-apple-ny / apple-sf-fonts | all five exist in `aur`. Picked **`otf-apple-sf-pro`, `otf-apple-sf-mono`, `otf-apple-ny`** (Apple's DMGs, SF Pro includes Rounded). **To install** |
| inter-font, ttf-jetbrains-mono | `inter-font` `extra`, **to install**; `ttf-jetbrains-mono` have |
| networkmanager, bluez, bluez-utils, upower, power-profiles-daemon | all `extra`, have |
| wireplumber, playerctl, brightnessctl, cava | all `extra`, have |
| awww (or what the repo uses), grim, slurp, satty, gpu-screen-recorder / wf-recorder | `awww` `extra`, have (it replaced `swww`; the shell draws Golden Gate's wallpaper itself, like the other rices). `grim`, `slurp`, `satty`, `wf-recorder` have. `gpu-screen-recorder` `extra`, **to install** |
| wl-clipboard, cliphist, plocate, fd, libqalculate, imagemagick, jq, inotify-tools | all `extra`; `plocate` **to install**, the rest have |
| nautilus, sushi; terminal = kitty (the repo's) | `nautilus` have, `sushi` `extra` **to install**, `kitty` have |
| plugin build deps: cmake meson cpio pkgconf git gcc | all have |
| hyprglass `.so` path (hyprpm) | `/var/cache/hyprpm/binary0x0/HyprGlass/hyprglass.so` (hyprpm picks the commit for 0.56 from the repo's `hyprpm.toml`; there's no branch prompt) |
| hyprbars `.so` path (hyprpm) | `/var/cache/hyprpm/binary0x0/hyprland-plugins/hyprbars.so` |

What the install found (step 1):

- **`otf-apple-ny`:** the AUR package is stale. Apple re-released `NY.dmg` (10 July 2025),
  so its checksum fails, and the new installer keeps its payload at `NYFonts.pkg/Payload`
  (gzipped cpio) instead of `Payload~`. Built from a patched PKGBUILD in the yay cache
  (`zcat NYFonts.pkg/Payload | cpio -idm`, new sha256 `1c2eedb4…`); a later rebuild needs
  the same patch until the maintainer updates it.
- **`mactahoe-icon-theme-git`** is ~400,000 files: build it with `OPTIONS+=(!strip !debug)`
  (a makepkg config passed through `--mflags "--config …"`) or makepkg's strip pass takes ages.
- **hyprpm** must run in a real terminal: it saves the plugins with sudo.
- **Names on disk:** GTK `MacTahoe-{Light,Dark}[-<accent>]` (graphite is `grey`, Multicolor
  the plain one) in `~/.local/share/themes`, built by `gg-theme install`; icons
  `MacTahoe[-<accent>][-dark]` (no pink set: the plain one stands in); the cursor is `macOS`;
  fonts `SF Pro Text`, `SF Pro Display`, `SF Pro Rounded`, `SF Mono`, `New York`.
- **`shellcheck`** isn't installed (scripts are checked with `bash -n` until it is).

What the glass found (step 3):

- hyprpm built **hyprglass v0.11.0** (commit `7fc3280`, pinned in its `hyprpm.toml` for Hyprland
  0.56.2). Every option name above still holds; new ones used here: `edge_height` (the lens
  rim), `frost`/`frost_blur` (windows frost only over other windows), `mask_feather`, and
  `hyprctl -j hyprglass status` (`shaders`, per-feature `active`/`reason`). A paused build
  has no `hyprglass` command and says `Paused (<reason>): …` in `hyprctl -j plugin list`.
- **hyprliquid 0.2.1** (`/usr/lib/libhyprliquid.so`, built against 0.56.2) loads and draws;
  it is configured by `["hyprliquid:*"]` keys on window and layer rules, which only a reload
  removes.
- `qs ipc call` to a missing target prints `Target not found.` and exits 0: `rice lock` now
  reads the answer, so an idle lock in a shell without one falls back instead of doing nothing.

What the shader glass found (step 4):

- **A `ScreencopyView` that stays alive holds the output's screencopy**, `live: false` or not:
  grim waited forever, and so did hyprlock (its background is a screenshot), so the idle lock
  showed Hyprland's "lockscreen app died". Accurate's capture is now made only as a pane
  opens, copied into an `Image` with `grabToImage` and destroyed (two seconds at most); the
  pane hides for that moment so the still doesn't see it. Check any new capture with
  `timeout 5 grim` while it is on screen.
- `captureFrame()` in `Component.onCompleted` is too early ("no recording context"); a
  non-live view captures once by itself when it's ready.
- `gg set KEY false` was refused: `jq -e` fails on `false` and `null`.

What the Hyprland base found (step 5):

- Hyprland 0.56's Lua has `hl.unbind(keys)`; `hl.gesture{fingers, direction, action}` takes
  `horizontal|vertical|up|down|left|right|pinch|pinchin|pinchout` and an action name or a Lua
  function. Bad arguments to `hl.*` don't raise: check `hyprctl configerrors`.
- A reload starts a fresh Lua state (globals are gone); evals share it. `hl.get_window` wants
  `"address:0x…"`; window objects have `address class pid at size floating fullscreen
  workspace monitor tags stable_id`, monitors `x y width height reserved`.
- **hyprbars** (hyprpm's `hyprland-plugins`) is configured by `hl.config{plugin = {hyprbars =
  {…}}}` and `hl.plugin.hyprbars.add_button{bg_color, fg_color, size, icon, action}`, whose
  action is a shell command; the first button added is the outermost. Loading it reloads the
  config. `["hyprbars:no_bar"] = true` on a window rule turns its bar off. The bar sits above
  the window's `at`, outside its `size`.

Steps 6–23, done as one (the user asked to condense them, code first, tests last):

- The shell: menu bar with the Apple menu, the app in front, status items and the clock,
  the Dynamic Island in its middle; banners top right; Notification Center (the month and
  the history by app); Control Center (every shared control, the glass, the appearance,
  sliders to 150%); the Dock (pinned, running, minimized, Trash, magnification, bounce,
  Keep in Dock); Spotlight (apps, sums, plocate files, the web; ⌘V is its clipboard mode);
  Apps (Launchpad); Mission Control and App Exposé (window stills captured once and
  dropped); hot corners; the key sheet; the OSD; the lock screen (PAM); the system card;
  System Settings as a real window. `services/Shell.qml` holds which one surface is open.
- Quickshell 0.3.2: `iconPath(name, true)` checks the icon (a `?fallback` name is not
  understood); a panel reading its own `screen` in `shown` loops as it maps, so panels get
  the screen's name once (`at`); a singleton function can't be called `focus`.
- Still to do from the brief: Genie (minimize is the special workspace with no effect),
  the app switcher strip (⌘Tab cycles windows), the screenshot toolbar and thumbnail
  (rice-shot stands in), widgets beyond the system card, drag-reordering the Dock.
- Step 22: ReGreet is the repo's greeter (no SDDM here); the keyd remap is
  `docs/goldengate/keyd-goldengate.conf`, written and not installed, waiting for a yes.

Install command (needs sudo, so the user runs it):

    yay -S --needed hyprpm hyprliquid mactahoe-gtk-theme mactahoe-icon-theme-git kvantum \
        apple_cursor otf-apple-sf-pro otf-apple-sf-mono otf-apple-ny inter-font \
        gpu-screen-recorder plocate sushi

## How it fits the repo

- **Rice** `rices/.config/rices/goldengate/`:
  - **`palette.toml` (schema v2):** Apple's fixed system colours for both modes, the
    labels (black/white at 85/50/25/10%), separator, control and window backgrounds, and the
    accents. The night rules and `test_qml_lint` must hold.
  - **Accents:** the accent is a `[meta] overlay`, the Satsuei mechanism in `rice-render`.
    `gg accent` writes `~/.local/state/goldengate/palette.toml` and runs `rice recolour`.
    "From wallpaper" uses ImageMagick's dominant vivid colour, snapped to the nearest Apple hue
    and clamped.
  - **Also in the folder:** `templates/hypr.lua` + `hypr-mode.lua` (visuals), `card.qml`,
    `transition.frag`, `preview.png` and `hooks/post-switch`.
- **Shell** `quickshell/.config/quickshell/goldengate/`:
  - It keeps the shared entry points from CLAUDE.md's checklist, with identical copies of
    `Mode.qml`, `Beat.qml` and `Sys.qml`.
  - `common/Theme.qml` is generated from the palette; `services/Settings.qml` reads
    `~/.config/goldengate/settings.json` through a FileView.
  - Every layer namespace is `goldengate:<part>` (menubar, island, dock, controlcenter,
    notifications, spotlight, widgets, osd, launchpad, missioncontrol).
- **Departures**, written into a CLAUDE.md "Golden Gate" section:
  - the menu bar has the clock and the Dynamic Island
  - banners sit top right
  - Dock and Notification Center
  - its own binds
  - floating-first windows
  - Kvantum
  - the plugins

  Shared tests still apply (e.g. every control centre has the shared controls).
- **Rice-scoped Hyprland:**
  - The visuals go in `templates/hypr.lua`.
  - The bind swap, floating rules, gestures, special workspaces (`minimized`, `hidden`, `desktop`)
    and `hyprctl plugin load/unload` go in a session file. `rice` applies it on switch-in and
    reverts it on switch-out (a new "leaving" hook in `switcher/.local/bin/rice`).
- **Save and restore:** `gg-theme save|apply|restore` keeps the previous GTK, Qt, icon and cursor
  settings in `~/.local/state/goldengate/restore.json`.
- **Wallpaper:**
  - The shell draws it (`wallpaper = "shell"`, which `liquid.frag` needs) from a picture folder,
    by default Satsuei's library folder seeded with the repo's existing stills.
  - Light/dark pairs are `name-light.*` and `name-dark.*`.
- **`gg`:** `switcher/.local/bin/gg`, in bash and shellcheck-clean. It wraps
  `qs -c goldengate ipc call`, `hyprctl eval` and the theme scripts.
- **Packages:** they go in `install` (theme list, font list, a Golden Gate set).

## Steps (one commit each; push after 5, 11, 17, 23)

0. Recon and this file.
1. Packages, fonts (with a README licence note), MacTahoe GTK, icons and Kvantum, apple_cursor,
   and `gg-theme` save/apply/restore.
2. Palette and the generated Theme; the Settings singleton and `settings.json`; the `gg`
   skeleton.
   - Accents and the overlay.
   - Appearance light/dark/auto: auto uses `rice-sun` with the location from Settings.
   - The ScreencopyView 450 ms crossfade.
   - Hooks for GTK, libadwaita, Kvantum and kitty.
3. The glass system.
   - hyprglass load/unload; `pomme` tuned for windows; the layer whitelist with alpha/contour masks.
   - Frosted and Solid, and the Clarity mapping.
   - Live switching; the fallback to Frosted when hyprglass is paused or fails, with its banner.
   - The hyprliquid backend.
4. `shaders/liquid.frag`, the shell-only Liquid fallback: sampled from the wallpaper, with an
   "Accurate" ScreencopyView mode and a backend indicator.
5. The Hyprland base: floating-first windows, rounding 16 with power 2.75, shadows, inactive dim,
   spring beziers, gestures, the bind set, hyprbars traffic lights and the special workspaces.
   **Push.**
6. Menu bar.
7. Dynamic Island, with `gg island test`.
8. Dock.
9. Genie/Scale minimize, Hide, Show All.
10. Notifications.
11. Control Center. **Push.**
12. Widgets and Notification Center.
13. Spotlight.
14. Apps grid.
15. Mission Control, App Exposé, Show Desktop, the app switcher, hot corners.
16. The tiling popover.
17. Screenshots and recording. **Push.**
18. Lock screen, hypridle and the screen saver.
19. System Settings.
20. UI sounds, Reduce motion, Reduce transparency, Increase contrast.
21. Chooser card and a clean switch in and out.
22. SDDM theme and keyd remap: diff only, until the user says yes.
23. Verification and `docs/goldengate/README.md`. **Push.**

## Verification

- **Each step:**
  - Run the unit tests.
  - The shell tests run under `QSG_RHI_BACKEND=opengl xvfb-run -a`. Add stand-ins in
    `tests/qsstub/` for every new Quickshell type: ScreencopyView, NotificationServer,
    WlSessionLock, PamContext, FloatingWindow, SystemTray.
  - Run `shellcheck -S warning` on the scripts.
  - Run the real rice, and check the qs log and `grim` shots in light and dark × Liquid, Frosted
    and Solid.
- **`tests/test_goldengate.py`:**
  - every layer namespace is `goldengate:*` and whitelisted
  - the binds stay out of `base.lua`
  - the restore file round-trips
  - the accents equal Apple's
  - every Settings item is reachable from search
- **At the end:**
  - switch through every rice twice
  - confirm the glass fallback fires when hyprglass is unloaded
  - measure frame times with Liquid on
