# Satsuei (撮影)

Satsuei is named after the compositing stage of anime production, where finished
background art and character cels get their light. The rice works in three layers:

1. **The plate**: your wallpaper, any picture or animated GIF/WebP.
2. **The pass**: a shader over the plate that adds light without repainting it. It does
   diffusion, bloom, light shafts from the picture's light source, dust motes, a grade
   that follows the hour, and optional film grain.
3. **The cels**: the glass UI on top. Every colour in it is taken from the wallpaper.

Change the wallpaper and the whole desktop re-themes: the shell, kitty, GTK and Qt,
nvim, Spotify and the rest. Satsuei is dark only.

## Using it

```sh
rice satsuei                      # switch to it (a light leak sweeps across)
satsuei-wall set ~/Pictures/x.png # take the look from a picture, from a terminal
```

| Keys | What |
| --- | --- |
| Super+Ctrl+W | the wallpaper selector |
| Super+Alt+C | the Cast picker: choose the characters |
| Super+Alt+Shift+C / Super+Alt+M | the next dancer / edge mascot |
| Super+N | the control centre: media with the dancer, the character strip, the toggles (Wi-Fi, Bluetooth, Quiet, Night light, Microphone, Performance, Caffeine, Screenshot, Record, Compositing, Mascot, Timesheet), sliders, notifications |
| the seal (撮 Satsuei, left of the bar) | the Satsuei panel |

The shared keys (launcher, lock, power, key sheet and so on) work as in every rice;
Super+/ lists them all.

### The bar

- **Left:** the seal, then the workspaces as episodes `01`–`05`.
- **Middle:** the clock.
- **Right:** what's playing (with a small equaliser from cava), the network speed,
  Bluetooth, volume, the tray, the lock and the control centre button.
- **The battery** is a strip of film whose frames are exposed as far as the charge goes.
  While charging, the film runs through the gate; under 20%, the last frame flickers.
  Hover it for the time left.

Switching workspace shows an eyecatch, `EP 03` plus its label, in the bottom left.

### Notifications

Notifications are subtitles at the bottom centre. **Quiet**, in the control centre,
keeps them in the list without showing them; critical ones still show.

### The Satsuei panel

Click the seal on the left of the bar.

- **The five effects:** bloom, rays, motes, grain and grade.
- **The time of day** the grade follows: drag the slider to hold an hour, or tick
  *Follow the clock*.
- **The wallpaper** on now, with *Choose wallpaper…*.
- **Its palette:** click a swatch to copy its hex.
- **The light source:** *Pick on wallpaper* gives a crosshair (click where the light
  comes from; Esc cancels). *Hold to compare* shows the raw picture while held.

### The desktop

- **The timesheet** (the system card) shows CPU, memory and disk as an animator's
  exposure sheet, with your dancer standing on it. Drag it anywhere, right-click it to
  put it away, and bring it back from the control centre's *Timesheet* tile.
- **The edge mascot** sits below the bottom-right edge with its head showing. It springs
  up and waves when a notification comes in, sleeps after 40 s without input, and hops
  when you click its head. The control centre's *Mascot* tile hides it.

### The lock screen

The lock is an episode title card: `第295話 · EPISODE 295` (the day of the year), that
day's title, the time and the date, over the graded plate.

There is a title for every date, 366 of them, and they follow the year the way an
anime's seasons do: snow and shrine visits in January, cherry blossom and the new term
in spring, rain in June, fireworks and Obon in summer, the moon, red leaves and the
culture festival in autumn, kotatsu and Christmas lights in December. Some dates have
their own, like 七夕 on 7 July or 大晦日 on 31 December.

The titles are in `~/.config/rices/satsuei/lock-titles.json`, as `[Japanese, English]`
pairs in calendar order (entry 60 is 29 February, skipped in other years). Edit them
freely; the file is read again when it changes, and a shorter list just repeats.

## Wallpapers

Put pictures in **`~/Pictures/Wallpapers`**. Subfolders become filter chips in the
selector. JPG, PNG, WebP and GIF all work; animated GIF and WebP stay animated.

The folder is watched, so a new picture shows up in the selector straight away, first as a
shimmer while it's read and then as its card. Each picture is read once:
`satsuei-wall scan` caches its thumbnail and palette in `~/.cache/satsuei/walls/`.

In the selector (Super+Ctrl+W):

| Key | What |
| --- | --- |
| ← → | move; after 250 ms the real desktop previews the picture |
| Enter | keep it (`satsuei-wall set`) |
| Esc | go back to what was there |
| / | search by name |

Along the top are the folder chips, sort (name, date added, colour), auto-rotate (off,
15m, 30m, 1h, daily; it picks from what the selector last showed), *Shuffle*, *Open
folder* and *Change folder…*.

Each wallpaper you apply is kept in `~/.local/share/satsuei/walls/`.

## Characters

Five built-in characters can dance on the media card (the **dancer**) and peek from the
screen edge (the **mascot**): Hana, Mochi, Kon, Bit and Yuki. The two roles are chosen
separately, from the control centre's strip, the Cast picker or the keys above. *Shuffle
daily* picks new ones each day.

### Your own

A character is a folder in **`~/.config/satsuei/characters/<id>/`**:

| File | |
| --- | --- |
| `dance.gif` (or `.webp`, `.apng`, `.png`) | required |
| `idle`, `wave`, `sleep` | optional, in the same formats |
| `thumb.png` | optional: shown while the first frame loads |
| `meta.json` | optional, below |

You can also make one with *Add from file…* in the Cast picker: the file you pick
becomes the new folder's `dance`.

- **Playback:** GIF and animated WebP play as they are. An APNG is converted once to WebP
  (with ffmpeg) under `~/.cache/satsuei/characters/`. A `.png` with `"frames"` in
  `meta.json` is read as a sprite sheet.
- **With the music:** the dance plays only while music does, sped to the tempo.
- **Missing clips:** with no `wave`, the character springs and rocks; with no `sleep`,
  it dims under a floating "z z Z".
- **Changes show at once:** the folder is watched, so new characters, clips and
  `meta.json` edits appear without a restart.

```json
{
  "name": "Miku", "nameJa": "ミク",
  "baseBpm": 100,
  "scale": 1.0, "offsetX": 0, "offsetY": 0, "flip": false, "trimBottom": 0,
  "puppet": 0.6,
  "frames": 0, "fps": 12,
  "recolor": [
    { "from": "#39c5bb", "to": "accent",  "tol": 0.10, "strength": 1.0 },
    { "from": "#e12885", "to": "accent2", "tol": 0.08, "strength": 0.9 }
  ],
  "protect": ["#f6d7c4"],
  "ambient": 0.7, "rim": 0.5, "outline": false,
  "match": true
}
```

| Key | Default | What it does |
| --- | --- | --- |
| `name`, `nameJa` | the folder name, "" | shown on the tiles |
| `baseBpm` | 100 | the tempo the dance clip was drawn at |
| `scale`, `offsetX`, `offsetY`, `flip`, `trimBottom` | 1, 0, 0, false, 0 | line the feet up on the media card and at the screen edge. Offsets are in the 120 × 160 canvas's units; `trimBottom` is rows of the clip's own pixels |
| `puppet` | 0.6 | how much the whole sprite bobs, sways and squashes on the beat |
| `frames`, `fps` | 0, 12 | for a `.png` sprite sheet |
| `recolor` | none | up to four rules. A colour near `from` (within `tol`, in hue and chroma) takes the hue and chroma of `to`: a theme token (`accent`, `accent2`, `tint`, `ink`, `glass`, `fg`, `fgDim`, `hair`, `onAccent`) or a hex colour. Its shading is kept |
| `protect` | none | colours never shifted (skin, eye whites) |
| `ambient` | 0.7 | how much of the plate's hourly grade it takes |
| `rim` | 0.5 | a rim of light on the side facing the plate's light source |
| `outline` | false | a thin edge in the glass tint |
| `match` | true | `false` draws the character exactly as the file is |

With `recolor` rules, a character's clothes follow each wallpaper, the way the built-ins'
do, and its protected colours stay as drawn.

## IPC

```sh
qs -c satsuei ipc call satsuei theme               # the tokens on screen now (JSON)
qs -c satsuei ipc call satsuei stats               # each screen's pass: running or paused and why, fps, effects
qs -c satsuei ipc call satsuei fx rays false       # bloom, rays, motes, grain, grade, pass, frost
qs -c satsuei ipc call satsuei toggleFx grain
qs -c satsuei ipc call satsuei hour 17.5           # hold the hour; a negative one follows the clock again
qs -c satsuei ipc call satsuei wallpaper next      # open, next, prev, random
qs -c satsuei ipc call satsuei setWallpaper ~/Pictures/Wallpapers/x.png
qs -c satsuei ipc call satsuei setCharacter dancer bit
qs -c satsuei ipc call satsuei nextCharacter mascot
qs -c satsuei ipc call satsuei cast mascot         # the Cast picker, for a role
qs -c satsuei ipc call satsuei testNote            # a test subtitle
qs -c satsuei ipc call shell studio                # the Satsuei panel
qs -c satsuei ipc call lock lock
```

`satsuei-wall` from a terminal:

```sh
satsuei-wall set <picture>     # take the look from it
satsuei-wall scan [folder]     # read a folder (one JSON line per picture)
satsuei-wall light 0.7 0.2     # move the light source (0–1 from the top left)
satsuei-wall theme <picture>   # print the tokens it would take, without applying
satsuei-wall current           # the plate on now
```

## Files

| Path | What |
| --- | --- |
| `~/.local/state/satsuei/theme.json` | the plate's tokens, swatches and light source |
| `~/.local/state/satsuei/palette.toml` | those colours, merged over the rice's palette for every app |
| `~/.local/state/satsuei/settings.json` | the effects, the hour, the characters, the wallpaper folder and rotation, the timesheet's place |
| `~/.cache/satsuei/walls/` | thumbnails and palettes of the wallpaper folder |
| `~/.config/satsuei/characters/` | your characters |

## Performance

- **Frame rate:** the pass runs at 30 fps on a timer and redraws nothing between ticks.
- **When it pauses:** for a fullscreen window, on battery under 30%, and while locked.
  Paused, the plate keeps its grade.
- **Measuring:** `plate/tools/grab.py --bench` measures the pass's GPU time. On the
  laptop it was about 1.7 ms a frame at 1080p (the spec's budget is 1.5 ms).
- **Characters:** they tick only while shown. A custom one is drawn through its
  colour-matching shader in a single pass.
