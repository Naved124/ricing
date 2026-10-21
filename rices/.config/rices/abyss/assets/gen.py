#!/usr/bin/env python3
"""Draw Abyss's images. Seeded, so the same arguments give the same bytes.

    gen.py                  the sprites (no Qt needed)
    gen.py --still          also the reef's still frames, rendered by the
                            real reef (reef/Reef.qml) through PySide6; run
                            under xvfb-run when headless
    gen.py --still --size 2560x1440

Writes:
    quickshell/.config/quickshell/abyss/reef/sprites/glow-H-S-L.png
                    the reef's glow sprites, 64×64: the mock's sprite(h, s, l),
                    a radial falloff (l+18% at the centre, then .55, .12 and
                    0 alpha at 18%, 50% and the edge), one per colour the reef
                    draws (reef.js spriteKeys)
    wall-static.png the reef at rest, 1920×1080: the greeter, boot screens,
                    and the wallpaper when the water shader can't load
    preview.png     the chooser's thumbnail (../preview.png), 600×600
and ../templates/fastfetch/logo.png, a jellyfish in teal and violet that
rice-render copies to fastfetch and the Plymouth splash.

Needs Pillow and numpy; --still also needs PySide6.
"""

from __future__ import annotations

import argparse
import colorsys
import importlib.machinery
import importlib.util
import json
import math
import subprocess
import sys
import tomllib
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
RICE = HERE.parent
REPO = RICE.parents[3]
REEF = REPO / "quickshell/.config/quickshell/abyss/reef"
SPRITES = REEF / "sprites"


def palette() -> dict:
    data = tomllib.loads((RICE / "palette.toml").read_text())
    return data["modes"]["dark"]


def sprite_keys(w: dict) -> list[tuple[int, int, int]]:
    """Every (hue, saturation, lightness) the reef draws a glow in; the same
    list as reef.js spriteKeys()."""
    keys = set()
    c = w["creatures"]
    for h in (c[0], c[1], c[3], c[4]):
        keys.add((h, 95, 62))                          # coral tips
    for h in c[:3]:
        keys.add((h + w["back_shift"], 95, 62))        # the back corals' tips
    for h in w["fans"]:
        keys.add((h, 95, 65))
    for h in w["anemones"]:
        keys.add((h, 100, 70))
    for h in w["jellies"]:
        keys.add((h, 90, 55))                          # halo
        keys.add((h, 100, 75))                         # rim lights
    keys.add((w["sparkle"], 90, 65))
    keys.add((w["plankton"], 100, 70))
    return sorted(keys)


def hsl(h: float, s: float, l: float) -> np.ndarray:
    r, g, b = colorsys.hls_to_rgb(h / 360 % 1, min(l, 100) / 100, s / 100)
    return np.array([r, g, b])


def glow(h: int, s: int, l: int, n: int = 64) -> Image.Image:
    """The mock's sprite(): a radial gradient over n×n, interpolated between
    stops unpremultiplied (as a canvas does), stored premultiplied-free RGBA."""
    y, x = np.mgrid[0:n, 0:n] + 0.5
    d = np.hypot(x - n / 2, y - n / 2) / (n / 2)
    stops = [(0.0, hsl(h, s, l + 18), 1.0), (0.18, hsl(h, s, l), 0.55),
             (0.5, hsl(h, s, l), 0.12), (1.0, hsl(h, s, l), 0.0)]
    rgba = np.zeros((n, n, 4))
    for (p0, c0, a0), (p1, c1, a1) in zip(stops, stops[1:]):
        m = (d >= p0) & (d <= p1)
        t = ((d - p0) / (p1 - p0))[..., None]
        rgba[m, :3] = (c0 * (1 - t) + c1 * t)[m]
        rgba[m, 3] = (a0 * (1 - t[..., 0]) + a1 * t[..., 0])[m]
    rgba[d > 1] = 0
    return Image.fromarray(np.round(rgba * 255).astype(np.uint8), "RGBA")


def sprites(w: dict) -> list[Path]:
    SPRITES.mkdir(parents=True, exist_ok=True)
    out = []
    for key in sprite_keys(w):
        path = SPRITES / "glow-{}-{}-{}.png".format(*key)
        glow(*key).save(path, optimize=True)
        out.append(path)
    # anything left from an older palette goes
    for old in SPRITES.glob("glow-*.png"):
        if old not in out:
            old.unlink()
    return out


# ── the jellyfish logo (fastfetch, Plymouth) ─────────────────────────────────

def logo(size: int = 192) -> Image.Image:
    """A jellyfish, drawn the way the reef draws them: a translucent bell with
    a bright scalloped rim, teal into violet, trailing tentacles, a soft halo."""
    w = palette()
    cols = {k: tuple(int(v[i:i + 2], 16) / 255 for i in (1, 3, 5)) for k, v in w["colors"].items() if k in ("glow", "glow2", "ink")}
    S = 4                                     # supersampling
    n = size * S
    y, x = (np.mgrid[0:n, 0:n] + 0.5) / S
    img = np.zeros((n, n, 3))
    alpha = np.zeros((n, n))
    cx, cy, r = size / 2, size * 0.42, size * 0.3
    teal, violet = np.array(cols["glow"]), np.array(cols["glow2"])

    def add(mask, colour, a):
        nonlocal img, alpha
        a = np.clip(mask * a, 0, 1)
        img = img * (1 - a[..., None]) + colour * a[..., None]
        alpha = alpha + a * (1 - alpha)

    # halo
    d = np.hypot(x - cx, y - cy) / (r * 1.9)
    add(np.clip(1 - d, 0, 1) ** 2, teal * 0.7 + violet * 0.3, 0.35)
    # tentacles: eight sine strands from the rim, violet toward their ends
    for k in range(8):
        x0 = cx - r * 0.85 + 1.7 * r * k / 7
        for i in range(140):
            u = i / 139
            yy = cy + u * size * 0.5
            xx = x0 + math.sin(u * 5 + k) * r * 0.18 * u + (k - 3.5) * u * r * 0.08
            m = np.clip(1.2 - np.hypot(x - xx, y - yy) / 0.9, 0, 1)
            add(m, teal * (1 - u) + violet * u, 0.5 * (1 - u * 0.6))
    # the bell: a dome, brighter toward its top, its rim scalloped
    rel_x, rel_y = (x - cx) / r, (y - cy) / r
    scallop = 0.1 + 0.07 * np.abs(np.sin(rel_x * math.pi * 4))
    inside = (rel_x ** 2 + (rel_y / 0.9) ** 2 < 1) & (rel_y < scallop)
    shade = np.clip(1 - np.hypot(rel_x, rel_y + 0.5) / 1.4, 0, 1)
    add(inside.astype(float), teal + (np.array(cols["ink"]) - teal) * 0.25, 0.35)
    add(inside * shade, np.array(cols["ink"]), 0.35)
    edge = np.abs(np.hypot(rel_x, rel_y / 0.9) - 1) < 0.04
    rim = (np.abs(rel_y - scallop) < 0.04) & (np.abs(rel_x) < 1)
    add(((edge & (rel_y < scallop)) | rim).astype(float), teal * 0.6 + np.array(cols["ink"]) * 0.4, 0.9)
    # inner loops
    for k in range(4):
        a = k / 4 * 2 * math.pi + 0.4
        ex, ey = cx + math.cos(a) * r * 0.3, cy - r * 0.45 + math.sin(a) * r * 0.12
        ring = np.abs(np.hypot((x - ex) / (r * 0.16), (y - ey) / (r * 0.1)) - 1) < 0.18
        add(ring.astype(float), violet * 0.5 + np.array(cols["ink"]) * 0.5, 0.6)
    rgb = np.clip(img, 0, 1)
    out = np.dstack([rgb, np.clip(alpha, 0, 1)])
    big = Image.fromarray(np.round(out * 255).astype(np.uint8), "RGBA")
    return big.resize((size, size), Image.LANCZOS)


# ── the still frames, from the real reef ────────────────────────────────────

STILL_QML = REEF / "tools/Still.qml"


def still(size: tuple[int, int], out: Path, seconds: float) -> None:
    """Run reef/Reef.qml offscreen for `seconds` of reef time and grab it."""
    cmd = [sys.executable, str(REEF / "tools/still.py"), "--size", f"{size[0]}x{size[1]}",
           "--seconds", str(seconds), "--out", str(out)]
    subprocess.run(cmd, check=True)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--still", action="store_true", help="also render the reef's still frames (PySide6)")
    ap.add_argument("--size", default="1920x1080")
    a = ap.parse_args()
    w = palette()
    made = sprites({**w["wallpaper"], "colors": w["colors"]})
    print(f"  {len(made)} sprites in {SPRITES.relative_to(REPO)}")
    logo_path = RICE / "templates/fastfetch/logo.png"
    logo_path.parent.mkdir(parents=True, exist_ok=True)
    logo().save(logo_path, optimize=True)
    print(f"  {logo_path.relative_to(REPO)}")
    if a.still:
        width, height = (int(v) for v in a.size.split("x"))
        still((width, height), HERE / "wall-static.png", 20.0)
        img = Image.open(HERE / "wall-static.png").convert("RGB")
        img.save(HERE / "wall-static.png", optimize=True)
        print(f"  {(HERE / 'wall-static.png').relative_to(REPO)}")
        # the thumbnail: the reef's busiest square, the floor and a jelly
        side = min(img.size)
        left = (img.size[0] - side) // 2
        img.crop((left, 0, left + side, side)).resize((600, 600), Image.LANCZOS).save(RICE / "preview.png", optimize=True)
        print(f"  {(RICE / 'preview.png').relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
