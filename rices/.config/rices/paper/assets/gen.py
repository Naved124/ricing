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
and ../templates/fastfetch/logo.png, a pencil typewriter that rice-render
copies to fastfetch and the Plymouth splash.

Needs Pillow (python-pillow).
"""

from __future__ import annotations

import argparse
import math
import random
import shutil
import subprocess
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


def speckle(im: Image.Image, rng: random.Random, count: int, alpha: float, tile: bool = False):
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
                    d.line([(px + ox, py + oy) for px, py in seg], fill=(*FIBRE, a), width=1)
        else:
            d.point((x, y), fill=(*FIBRE, a))
    im.alpha_composite(lay)


# ── the wallpaper ───────────────────────────────────────────────────────────

def wall(width: int, height: int, seed: int) -> Image.Image:
    rng = random.Random(seed)
    # everything is placed on the preview's 1280x720 desk and scaled
    s = min(width / 1280, height / 720)
    X = lambda v: v / 1280 * width
    Y = lambda v: v / 720 * height

    im = Image.new("RGBA", (width, height), (*WALL, 255))
    speckle(im, rng, round(14000 * width * height / (1280 * 720)), 0.06)

    # the drafting grid: 24 px, whatever the resolution
    lay, d = layer(im.size)
    for gx in range(0, width, 24):
        d.line([(gx, 0), (gx, height)], fill=GRID)
    for gy in range(0, height, 24):
        d.line([(0, gy), (width, gy)], fill=GRID)
    im.alpha_composite(lay)

    # a coffee ring, bottom left: a soft stain, then three wobbly rims
    cx, cy, R = X(230), Y(660), 74 * s
    stain = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(stain)
    for k in range(40, 0, -1):
        t = k / 40
        a = 0.05 + 0.04 * t ** 3
        r = R * t
        sd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*STAIN, round(a * 255 * 0.35)))
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
        d.line(pts, fill=(*COFFEE, round((0.18 - k * 0.05) * 255)), width=max(1, round((3 - k) * s)), joint="curve")
    im.alpha_composite(lay.filter(ImageFilter.GaussianBlur(0.6 * s)))

    # a pencil sketch, bottom right: a wobbly triangle inside another
    lay, d = layer(im.size)
    tri = [(X(1090), Y(420)), (X(1150), Y(330)), (X(1210), Y(420)), (X(1090), Y(420))]
    wobble(d, rng, tri, 1.3 * s, (*PENCIL, round(0.55 * 255)), jitter=1.2 * s)
    inner = [(X(1105), Y(410)), (X(1150), Y(345)), (X(1195), Y(410))]
    wobble(d, rng, inner, 1.0 * s, (*PENCIL, round(0.35 * 255)), jitter=1.2 * s)
    # a short red pencil stroke near the bottom centre
    wobble(d, rng, [(X(470), Y(700)), (X(520), Y(690)), (X(575), Y(694))], 1.2 * s,
           (*RED, round(0.5 * 255)), jitter=1.2 * s)
    im.alpha_composite(lay)

    # "btw i use arch", in ink at 55%, slightly turned
    f = font("Kalam-Regular.ttf", round(22 * s))
    text = "btw i use arch"
    box = f.getbbox(text)
    tw, th = box[2] - box[0] + 8, box[3] + 8
    note = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    ImageDraw.Draw(note).text((4, 0), text, font=f, fill=(*INK, round(0.55 * 255)))
    note = note.rotate(math.degrees(0.06), resample=Image.BICUBIC, expand=True)
    im.alpha_composite(note, (round(X(1060)), round(Y(460) - th)))

    return im.convert("RGB")


# ── tileable paper stock ────────────────────────────────────────────────────

def paper_tex(size: int, seed: int) -> Image.Image:
    """Paper colour with a soft cloudy formation and fibres, wrapping at the edges."""
    rng = random.Random(seed + 1)
    im = Image.new("RGBA", (size, size), (*PAPER, 255))

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
    shade = Image.new("RGBA", im.size, (*FIBRE, 0))
    # darker where the cloud is low: at most ~3% of the stock's lightness
    shade.putalpha(cloud.point(lambda v: max(0, 128 - v) // 8))
    im.alpha_composite(shade)

    speckle(im, rng, size * size // 40, 0.07, tile=True)
    return im.convert("RGB")


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
    lg = a.out.parent / "templates/fastfetch/logo.png" if a.out == HERE else a.out / "logo.png"
    lg.parent.mkdir(parents=True, exist_ok=True)
    logo(192, a.seed).save(lg, optimize=True)
    for p in (a.out / "wall.png", a.out / "paper-tex.png", lg):
        print(f"  {p}")


if __name__ == "__main__":
    main()
