# Satsuei (撮影): plan

Satsuei is the anime compositing stage: the finished background art and the cels
get their light (bloom, shafts, haze, grain). The rice is three layers:

1. **Plate**: any picture or animated GIF/WebP the user picks.
2. **Pass**: a GLSL shader over the plate that adds light without repainting it.
3. **Cels**: glass UI whose every colour comes from the plate.

Changing the wallpaper re-themes the whole rice. The reference is `mock.html`
(with `wall.webp`, the seed plate).

## How it fits the repo

- **One-mode rice.** Dark only, like Abyss: `[meta] modes = ["dark"]`.
- **A rice is still its palette.** `palette.toml` holds what never changes (fonts,
  shape, motion, the seed colours). `satsuei-wall set` writes the per-wallpaper part to
  `~/.local/state/satsuei/palette.toml` (`[modes.dark.colors/roles/ansi/gradient]`).
  `rice-render` merges that overlay over the palette (`[meta] overlay`), so every
  shared app template (kitty, Hyprland, GTK, qt6ct, nvim, btop, Spicetify, …) follows
  the wallpaper, and matugen does no app templating of its own.
- **The shell reads `theme.json`.** `satsuei/common/Theme.qml` is a singleton over
  `FileView { watchChanges: true }` on `~/.local/state/satsuei/theme.json`. Every token
  is a `ColorAnimation` over 600 ms, and there are no colour literals in QML.
- **What belongs to Satsuei lives in its shell.** The notification server, the
  `IdleMonitor`, cava (its own config) and the `inotifywait` watcher are all children of
  `qs -c satsuei`. `rice` stops that shell on a switch, so they stop with it. Its layer
  rules are in its own `templates/hypr.lua`, which a switch's reload drops.
- **Exceptions to the shared shell contract**, chosen with the user:
  - The clock sits in the bar's centre.
  - Notifications are subtitles, not an island.
  - The keys: Super+Ctrl+W opens wallpapers, Super+Alt+C opens the Cast picker,
    Super+Alt+Shift+C cycles the dancer and Super+Alt+M cycles the mascot. Super+W
    stays the browser.

## Files

```
rices/.config/rices/satsuei/
  palette.toml            fonts, shape, motion, seed colours, overlay path
  templates/hypr.lua      glass: blur, borders accent→accent2, layer rules satsuei-*
  templates/hypr-mode.lua the colours (borders, shadow) from the overlay
  card.qml                chooser tile: the current plate, live
  transition.frag(.qsb)   switch-in: a light leak across the plate
  lock-titles.json        the episode titles
  seed/wall.webp          the mock's plate; seed/theme.json its tokens
  preview.png
switcher/.local/bin/
  satsuei-wall            set | scan | apply | light | theme (matugen, ImageMagick)
  satsuei-char            import | suggest | preview (Pillow / ImageMagick)
switcher/.local/share/satsuei/cava.conf, settings.json (defaults)
quickshell/.config/quickshell/satsuei/
  shell.qml               entry points shared by every shell + Satsuei's IPC
  common/                 Theme (theme.json), Mode, Glass, Settings (settings.json), Grade
  plate/                  Plate.qml (per screen), Pass.qml, shaders/satsuei.frag
  bar/                    Bar, Episodes, Title, Status, Eyecatch
  center/                 Center (drawer), MediaCard, Cava, Tiles, Sliders, NoteList
  subs/Subtitles.qml
  chars/                  Rig.qml, Hana/Mochi/Kon/Bit/Yuki, Custom.qml, SceneMatch.qml,
                          Characters.qml (built-ins + folder scan), Strip, CastPicker
  mascot/Mascot.qml
  walls/                  Library.qml (cache + inotify), Selector.qml
  panel/Studio.qml        the Satsuei panel
  lock/Lock.qml           the episode title card
  launcher/ clipboard/ keys/ power/ osd/   the shared entry points, in glass
  services/               Hypr, Sys, Beat (cava), Notifs, Media, Audio, Net, …
  shaders/                satsuei.frag, scenematch.frag, … (+ .qsb via tools/shaders)
docs/satsuei/             mock.html, wall.webp, PLAN.md, README.md
tests/test_satsuei.py     pipeline, overlay render, shell smoke + pokes, chars, import tool
```

## State on disk

| Path | What |
|---|---|
| `~/.local/state/satsuei/plate.<ext>` | the current plate |
| `~/.local/state/satsuei/bloom.png`, `soft.png` | 1/4 and 1/8 blur maps |
| `~/.local/state/satsuei/theme.json` | tokens, swatches, `lightX`/`lightY`, `bright` |
| `~/.local/state/satsuei/palette.toml` | the overlay `rice-render` merges |
| `~/.local/state/satsuei/settings.json` | effect toggles, roles' characters, wallDir, rotate |
| `~/.local/share/satsuei/walls/` | the library of applied plates |
| `~/.cache/satsuei/walls/<sha1>/` | thumb.webp + palette.json per scanned wallpaper |
| `~/.config/satsuei/characters/<id>/` | custom characters |

## Steps

The work goes in twenty steps, one commit each: 0 the plan, 1 packages, 2 the theme
pipeline, 3 the plate and pass, 4 glass, the bar and the eyecatch, 5 the control
centre, 6 the subtitles, 7 the rig and Hana, 8 the other four built-ins, 9 custom
characters and the strip, 10 `satsuei-char`, 11 scene matching, 12 the Cast picker,
13 the edge mascot, 14 the wallpaper scan, 15 the selector, 16 the Satsuei panel, 17 the
lock, 18 integration, and 19 verification and the README.
