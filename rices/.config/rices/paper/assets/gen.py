#!/usr/bin/env python3
"""Draw Paper's images. Seeded, so the same arguments give the same bytes.

    gen.py                      every image, wall.png at 1920x1080
    gen.py --size 2560x1440     the wallpaper at your monitor's resolution
    gen.py --seed 7             a different (but still repeatable) desk

Writes, next to this file:
    wall.png        the desk: a drafting sheet with fibres, a faint 24 px grid,
                    a coffee ring, a pencil doodle and a note in Kalam
    paper-tex.png   512x512 tileable paper stock: kitty's background_image and
                    the shell's sheets
    ink-wear.png    256x256 tileable alpha mask: where a rubber stamp's ink
                    took (opaque) and where the paper shows through
    wall-dark.png   the same desk at night: walnut-charcoal with its grain, the
                    grid in dim blue, silvery pencil, and the lamp's warm pool
                    at the top left
    sheet-dark.png  512x512 tileable dark sheet (kitty and the shell at night)
    click.wav       the lamp's pull-chain, for `rice mode` (sound = true in
                    ~/.config/rice/mode.toml): two band-passed noise clicks
and ../templates/fastfetch/logo.png, a pencil typewriter that rice-render
copies to fastfetch and the Plymouth splash.

Needs Pillow (python-pillow).
"""

from __future__ import annotations

import argparse
import math
import random
import shutil
import struct
import subprocess
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent

WALL = (0xEB, 0xE8, 0xDF)
PAPER = (0xF7, 0xF5, 0xEF)
FIBRE = (90, 75, 50)
GRID = (91, 140, 190, round(0.10 * 255))
COFFEE = (140, 95, 45)
STAIN = (150, 105, 55)
PENCIL = (75, 74, 70)
INK = (28, 42, 110)
RED = (200, 55, 45)

# the same desk under a lamp (palette.toml's dark colours)
NIGHT = {
    "wall": (0x16, 0x14, 0x11),          # walnut-charcoal
    "paper": (0x1F, 0x1C, 0x19),         # the sheet
    "fibre": (205, 195, 175),            # fibres catch the lamp: lighter, not darker
    "grain": (60, 46, 32),               # the desk's wood grain
    "grid": (0x2F, 0x3A, 0x4C, round(0.35 * 255)),
    "coffee": (70, 48, 28),              # dark umber
    "stain": (52, 36, 22),
    "pencil": (165, 165, 168),           # graphite is silvery at night
    "ink": (0xA3, 0xB4, 0xF0),           # gel-blue, dim
    "red": (0xEF, 0x8A, 0x78),
    "pool": (0x3A, 0x2F, 0x22),          # the lamp's pool
}
DAY = {"wall": WALL, "paper": PAPER, "fibre": FIBRE, "grid": GRID, "coffee": COFFEE, "stain": STAIN,
       "pencil": PENCIL, "ink": INK, "red": RED}
LAMP = (0.18, 0.12)                      # palette.toml: [modes.dark.meta] lamp_pos


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    """The repo's vendored copy, the stowed one, or whatever fontconfig finds."""
    for d in (HERE.parents[4] / "fonts/.local/share/fonts/paper" if len(HERE.parents) > 4 else None,
              Path.home() / ".local/share/fonts/paper"):
        if d and (d / name).is_file():
            return ImageFont.truetype(str(d / name), size)
    if shutil.which("fc-match"):
        family = name.split("-")[0]
        path = subprocess.run(["fc-match", "-f", "%{file}", family], capture_output=True, text=True).stdout
        if path:
            return ImageFont.truetype(path, size)
    raise SystemExit(f"gen.py: can't find {name}; stow the fonts package first")


def layer(size: tuple[int, int]) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def wobble(draw: ImageDraw.ImageDraw, rng: random.Random, pts, width: float, colour, passes=2, jitter=1.2):
    """A pencil line: drawn twice, each pass a little off the last, and
    wavering along its length rather than only at the corners."""
    for _ in range(passes):
        shaky = []
        drift = 0.0
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            n = max(1, round(math.hypot(x1 - x0, y1 - y0) / (14 * max(1.0, width / 2))))
            for i in range(n):
                t = i / n
                drift = drift * 0.6 + rng.uniform(-jitter, jitter) * 0.5
                nx, ny = -(y1 - y0), x1 - x0
                ln = math.hypot(nx, ny) or 1
                shaky.append((x0 + (x1 - x0) * t + nx / ln * drift, y0 + (y1 - y0) * t + ny / ln * drift))
        shaky.append((pts[-1][0] + rng.uniform(-jitter, jitter), pts[-1][1] + rng.uniform(-jitter, jitter)))
        draw.line(shaky, fill=colour, width=max(1, round(width)), joint="curve")


def speckle(im: Image.Image, rng: random.Random, count: int, alpha: float, tile: bool = False,
            fibre=FIBRE):
    """Paper fibres: single dots plus short hairs at random angles."""
    w, h = im.size
    lay, d = layer(im.size)
    for _ in range(count):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        a = round(rng.random() * alpha * 255)
        if rng.random() < 0.18:
            ang = rng.uniform(0, math.pi)
            ln = rng.uniform(2, 7)
            seg = [(x, y), (x + math.cos(ang) * ln, y + math.sin(ang) * ln)]
            for ox in ((-w, 0, w) if tile else (0,)):
                for oy in ((-h, 0, h) if tile else (0,)):
                    d.line([(px + ox, py + oy) for px, py in seg], fill=(*fibre, a), width=1)
        else:
            d.point((x, y), fill=(*fibre, a))
    im.alpha_composite(lay)


# ── the wallpaper ───────────────────────────────────────────────────────────

def wall(width: int, height: int, seed: int, night: bool = False) -> Image.Image:
    """The desk; night=True is the same desk under the lamp (wall-dark.png):
    the same things in the same places, in night colours, with the wood's
    grain and the lamp's pool."""
    rng = random.Random(seed)
    P = NIGHT if night else DAY
    # everything is placed on the preview's 1280x720 desk and scaled
    s = min(width / 1280, height / 720)
    X = lambda v: v / 1280 * width
    Y = lambda v: v / 720 * height

    im = Image.new("RGBA", (width, height), (*P["wall"], 255))
    if night:
        wood_grain(im, random.Random(seed + 5), s)
    speckle(im, rng, round(14000 * width * height / (1280 * 720)), 0.06 * (0.5 if night else 1), fibre=P["fibre"])

    # the drafting grid: 24 px, whatever the resolution
    lay, d = layer(im.size)
    for gx in range(0, width, 24):
        d.line([(gx, 0), (gx, height)], fill=P["grid"])
    for gy in range(0, height, 24):
        d.line([(0, gy), (width, gy)], fill=P["grid"])
    im.alpha_composite(lay)

    # a coffee ring, bottom left: a soft stain, then three wobbly rims
    cx, cy, R = X(230), Y(660), 74 * s
    stain = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(stain)
    for k in range(40, 0, -1):
        t = k / 40
        a = 0.05 + 0.04 * t ** 3
        r = R * t
        sd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*P["stain"], round(a * 255 * 0.35)))
    im.alpha_composite(stain.filter(ImageFilter.GaussianBlur(3 * s)))
    lay, d = layer(im.size)
    for k in range(3):
        pts = []
        steps = 160
        phase = rng.uniform(0, math.tau)
        for i in range(steps + 3):
            a = i / steps * math.tau
            r = R + k * 3 * s + math.sin(a * 5 + phase) * 2 * s + rng.uniform(0, 1.5) * s
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        d.line(pts, fill=(*P["coffee"], round((0.18 - k * 0.05) * 255 * (1.6 if night else 1))), width=max(1, round((3 - k) * s)), joint="curve")
    im.alpha_composite(lay.filter(ImageFilter.GaussianBlur(0.6 * s)))

    # a pencil sketch, bottom right: a wobbly triangle inside another
    lay, d = layer(im.size)
    tri = [(X(1090), Y(420)), (X(1150), Y(330)), (X(1210), Y(420)), (X(1090), Y(420))]
    wobble(d, rng, tri, 1.3 * s, (*P["pencil"], round((0.32 if night else 0.55) * 255)), jitter=1.2 * s)
    inner = [(X(1105), Y(410)), (X(1150), Y(345)), (X(1195), Y(410))]
    wobble(d, rng, inner, 1.0 * s, (*P["pencil"], round((0.2 if night else 0.35) * 255)), jitter=1.2 * s)
    # a short red pencil stroke near the bottom centre
    wobble(d, rng, [(X(470), Y(700)), (X(520), Y(690)), (X(575), Y(694))], 1.2 * s,
           (*P["red"], round((0.3 if night else 0.5) * 255)), jitter=1.2 * s)
    im.alpha_composite(lay)

    # "btw i use arch", in ink at 55%, slightly turned
    f = font("Kalam-Regular.ttf", round(22 * s))
    text = "btw i use arch"
    box = f.getbbox(text)
    tw, th = box[2] - box[0] + 8, box[3] + 8
    note = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    ImageDraw.Draw(note).text((4, 0), text, font=f, fill=(*P["ink"], round((0.3 if night else 0.55) * 255)))
    note = note.rotate(math.degrees(0.06), resample=Image.BICUBIC, expand=True)
    im.alpha_composite(note, (round(X(1060)), round(Y(460) - th)))

    if night:
        lamp_pool(im)
    return im.convert("RGB")


def wood_grain(im: Image.Image, rng: random.Random, s: float):
    """Fine, long, slightly wavy lines along the desk: walnut under the paper."""
    w, h = im.size
    lay, d = layer(im.size)
    y = 0.0
    while y < h:
        y += rng.uniform(2, 7) * s
        amp, freq, phase = rng.uniform(1, 4) * s, rng.uniform(0.6, 1.6) / w * math.tau, rng.uniform(0, math.tau)
        a = round(rng.uniform(0.04, 0.12) * 255)
        pts = [(x, y + math.sin(x * freq + phase) * amp) for x in range(0, w + 16, 16)]
        d.line(pts, fill=(*NIGHT["grain"], a), width=1)
    im.alpha_composite(lay.filter(ImageFilter.GaussianBlur(0.7 * s)))


def lamp_pool(im: Image.Image):
    """The lamp's warm pool: pool colour at 35% at the lamp, gone by 45% of the width."""
    w, h = im.size
    cx, cy, R = LAMP[0] * w, LAMP[1] * h, 0.45 * w
    pool = Image.new("L", (w, h))
    px = pool.load()
    step = 4                                # a coarse grid, smoothed after
    for y in range(0, h, step):
        for x in range(0, w, step):
            t = min(1.0, math.hypot(x - cx, y - cy) / R)
            v = round(0.35 * 255 * (1 - t) ** 2 * (1 + 2 * t))   # a soft falloff
            for yy in range(y, min(h, y + step)):
                for xx in range(x, min(w, x + step)):
                    px[xx, yy] = v
    lay = Image.new("RGBA", (w, h), (*NIGHT["pool"], 0))
    lay.putalpha(pool.filter(ImageFilter.GaussianBlur(step * 2)))
    im.alpha_composite(lay)


# ── tileable paper stock ────────────────────────────────────────────────────

def paper_tex(size: int, seed: int, night: bool = False) -> Image.Image:
    """Paper colour with a soft cloudy formation and fibres, wrapping at the
    edges; night=True is the dark sheet (sheet-dark.png), whose formation and
    fibres are lighter than the stock rather than darker."""
    rng = random.Random(seed + 1)
    P = NIGHT if night else DAY
    im = Image.new("RGBA", (size, size), (*P["paper"], 255))

    # formation: periodic value noise (a wrapped lattice), two octaves
    def octave(cells: int, amp: float):
        lat = [[rng.uniform(-1, 1) for _ in range(cells)] for _ in range(cells)]
        out = Image.new("L", (size, size))
        px = out.load()
        for y in range(size):
            fy = y / size * cells
            y0 = int(fy) % cells
            y1 = (y0 + 1) % cells
            ty = fy - int(fy)
            ty = ty * ty * (3 - 2 * ty)
            for x in range(size):
                fx = x / size * cells
                x0 = int(fx) % cells
                x1 = (x0 + 1) % cells
                tx = fx - int(fx)
                tx = tx * tx * (3 - 2 * tx)
                a = lat[y0][x0] + (lat[y0][x1] - lat[y0][x0]) * tx
                b = lat[y1][x0] + (lat[y1][x1] - lat[y1][x0]) * tx
                px[x, y] = round(128 + (a + (b - a) * ty) * amp)
        return out

    cloud = Image.blend(octave(6, 110), octave(24, 110), 0.35)
    # soften the lattice, wrapping round the edges so the tile still tiles
    wrap = Image.new("L", (size * 3, size * 3))
    for ox in range(3):
        for oy in range(3):
            wrap.paste(cloud, (ox * size, oy * size))
    cloud = wrap.filter(ImageFilter.GaussianBlur(size / 40)).crop((size, size, size * 2, size * 2))
    shade = Image.new("RGBA", im.size, (*P["fibre"], 0))
    # darker where the cloud is low: at most ~3% of the stock's lightness
    # (at night lighter, and a little weaker)
    shade.putalpha(cloud.point(lambda v: max(0, 128 - v) // (10 if night else 8)))
    im.alpha_composite(shade)

    speckle(im, rng, size * size // 40, 0.07 * (0.7 if night else 1), tile=True, fibre=P["fibre"])
    return im.convert("RGB")


# ── worn stamp ink ─────────────────────────────────────────────────────────

def ink_wear(size: int, seed: int) -> Image.Image:
    """White, opaque where ink took; speckles and a few scuffs let paper through."""
    rng = random.Random(seed + 3)
    alpha = Image.new("L", (size, size), 255)
    d = ImageDraw.Draw(alpha)
    for _ in range(size * size // 22):
        x, y = rng.uniform(0, size), rng.uniform(0, size)
        r = rng.choice((0.5, 0.7, 1.0, 1.0, 1.4, 2.2))
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                d.ellipse([x + ox - r, y + oy - r, x + ox + r, y + oy + r], fill=rng.randint(0, 90))
    for _ in range(14):
        x, y = rng.uniform(0, size), rng.uniform(0, size)
        ang = rng.uniform(0, math.pi)
        ln = rng.uniform(10, 40)
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                d.line([(x + ox, y + oy), (x + ox + math.cos(ang) * ln, y + oy + math.sin(ang) * ln)],
                       fill=rng.randint(60, 140), width=rng.choice((1, 2)))
    im = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    im.putalpha(alpha)
    return im


# ── a pencil typewriter, for fastfetch and the boot splash ─────────────────

def logo(size: int, seed: int) -> Image.Image:
    rng = random.Random(seed + 2)
    k = size / 192
    big = Image.new("RGBA", (size * 2, size * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    P = lambda pts: [(x * k * 2, y * k * 2) for x, y in pts]
    ink = (*INK, 235)
    w = 3.2 * k * 2
    j = 1.4 * k
    # the platen and paper
    wobble(d, rng, P([(52, 70), (52, 22), (140, 22), (140, 70)]), w, (*PENCIL, 200), jitter=j)
    for i, yy in enumerate((36, 46, 56)):
        wobble(d, rng, P([(64, yy), (128 - i * 12, yy)]), w * 0.6, (*RED, 190), passes=1, jitter=j)
    wobble(d, rng, P([(30, 70), (162, 70), (162, 82), (30, 82), (30, 70)]), w, ink, jitter=j)
    # the body
    wobble(d, rng, P([(22, 92), (170, 92), (182, 160), (10, 160), (22, 92)]), w, ink, jitter=j)
    # three rows of keys
    for row, (y0, n, x0) in enumerate(((106, 8, 34), (124, 7, 42), (142, 6, 50))):
        for i in range(n):
            cx, cy = x0 + i * 17, y0 + 4
            r = 5.2
            d.ellipse(P([(cx - r, cy - r), (cx + r, cy + r)]), outline=ink, width=round(w * 0.7))
    return big.resize((size, size), Image.LANCZOS)


def click(seed: int, rate: int = 48000) -> bytes:
    """A pull-chain click as 16-bit mono PCM: a noise burst band-passed around
    2.4 kHz (4 ms attack, ~60 ms decay), and a softer one 35 ms later as the
    chain swings back. Made from seeded noise, nothing sampled."""
    rng = random.Random(seed)
    n = int(rate * 0.14)
    raw = [0.0] * n
    for start, gain in ((0, 1.0), (int(rate * 0.035), 0.4)):
        for i in range(n - start):
            t = i / rate
            env = min(1.0, t / 0.004) * math.exp(-t / 0.012)
            raw[start + i] += gain * env * rng.uniform(-1, 1)
    # RBJ band-pass, constant 0 dB peak, f0 2.4 kHz, Q 1.4
    w = 2 * math.pi * 2400 / rate
    alpha = math.sin(w) / (2 * 1.4)
    b0, b2, a0, a1, a2 = alpha, -alpha, 1 + alpha, -2 * math.cos(w), 1 - alpha
    out, x1, x2, y1, y2 = [], 0.0, 0.0, 0.0, 0.0
    for x in raw:
        y = (b0 * x + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1, y2, y1 = x1, x, y1, y
        out.append(y)
    peak = max(abs(v) for v in out) or 1.0
    return b"".join(struct.pack("<h", round(v / peak * 0.5 * 32767)) for v in out)


def write_wav(path: Path, pcm: bytes, rate: int = 48000) -> None:
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(pcm)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--size", default="1920x1080", help="wallpaper WIDTHxHEIGHT (default 1920x1080)")
    ap.add_argument("--seed", type=int, default=1955)
    ap.add_argument("--out", type=Path, default=HERE)
    a = ap.parse_args()
    w, h = (int(v) for v in a.size.lower().split("x"))

    a.out.mkdir(parents=True, exist_ok=True)
    wall(w, h, a.seed).save(a.out / "wall.png", optimize=True)
    paper_tex(512, a.seed).save(a.out / "paper-tex.png", optimize=True)
    ink_wear(256, a.seed).save(a.out / "ink-wear.png", optimize=True)
    wall(w, h, a.seed, night=True).save(a.out / "wall-dark.png", optimize=True)
    paper_tex(512, a.seed, night=True).save(a.out / "sheet-dark.png", optimize=True)
    write_wav(a.out / "click.wav", click(a.seed))
    lg = a.out.parent / "templates/fastfetch/logo.png" if a.out == HERE else a.out / "logo.png"
    lg.parent.mkdir(parents=True, exist_ok=True)
    logo(192, a.seed).save(lg, optimize=True)
    for p in (a.out / "wall.png", a.out / "paper-tex.png", a.out / "ink-wear.png", a.out / "wall-dark.png",
              a.out / "sheet-dark.png", a.out / "click.wav", lg):
        print(f"  {p}")


if __name__ == "__main__":
    main()
