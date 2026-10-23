"""The night rules: what every rice's dark mode has to keep.

Checked on each rice's [modes.dark.*] tables (a rice without them renders its
light tables in dark/ and is skipped here until it gets some). Light mode keeps
its own checks in test_render.py.

  · no pure extremes: no #000000 or #ffffff in the dark palette (a base
    only ever used at partial alpha can be exempt: Golden Gate's labels)
  · bg (and the terminal's) at L* 7–12, surface at L* 10–16, and no large
    surface (panels, bars, launcher, notifications) above L* 25
  · primary text 7:1 to 14:1 on its background (above that it shimmers),
    secondary text and accents used as text at least 4.5:1
  · accents less saturated than in light mode
  · the normal ANSI colours at least 4.5:1 on the terminal
  · the dark wallpaper's mean at or below L* 16, nothing above L* 45 but
    specks (the 99.9th percentile)

A rice can be exempt from a rule by choice, listed in EXEMPT with why. The
ANSI rule and the floors (muted and accents at least 4.5:1) are never exempt.
"""

import importlib.machinery
import importlib.util
import math
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCRIPT = REPO / "render/.local/bin/rice-render"
RICES = REPO / "rices/.config/rices"

loader = importlib.machinery.SourceFileLoader("rice_render_night", str(SCRIPT))
spec = importlib.util.spec_from_loader("rice_render_night", loader)
rr = importlib.util.module_from_spec(spec)
loader.exec_module(rr)

# colours each rice spreads over large areas (bars, panels, notes, the desk)
PANELS = {
    "paper": ["desk", "wall", "paper", "card", "kraft", "envelope"],
    "nacre": ["pearl", "shell", "mist", "frost", "glaze"],
    "abyss": ["deep", "shoal", "term", "glass", "glass_strong"],
    "goldengate": ["window", "grouped", "under_page", "frost"],
}
# the dark wallpaper the luminance check renders, relative to the rice
WALLPAPERS = {
    "paper": "assets/wall-dark.png",
    "nacre": "assets/wall-static-dark.png",
}
# rules a rice keeps out of by choice, each with why
EXEMPT = {
    "abyss": {
        # the reef mock's values, kept as they are: the abyss is near black
        # (bg L* 1.5, the terminal's glass L* 3.9) and its ink 16.6:1 on it
        "bands": "deep water is darker than L* 7; the mock's #01060b and #040f17",
        "halation": "the mock's ink #cdeef0 on the abyss, 15–16.6:1",
        # dark only: there's no day for its accents to be paler than
        "saturation": "one mode; nothing to compare against",
        # the reef's glow is meant to be bright points on near black
        "wallpaper": "glowing creatures; the still's specks pass 45",
    },
    "goldengate": {
        # Apple's labels and separators are white (or black) at 85/50/25/10%,
        # never solid: the solid text is label #dddddd. The shadow and the
        # Dynamic Island are black on the Mac too.
        "extremes": "Apple's label, separator and shadow bases, always used at partial alpha",
    },
}


def lab(c: str) -> tuple[float, float, float]:
    """CIE L*a*b* (D65) of a #rrggbb colour."""
    def lin(v: int) -> float:
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

    r, g, b = (lin(v) for v in rr.rgb(c))
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 216 / 24389 else (24389 / 27 * t + 16) / 116
    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def lightness(c: str) -> float:
    return lab(c)[0]


def chroma(c: str) -> float:
    _, a, b = lab(c)
    return math.hypot(a, b)


def night_violations(light: dict, dark: dict, panels: list[str], exempt=()) -> list[str]:
    """Every night rule a dark palette breaks, as readable lines (minus the
    ones in `exempt`: bands, halation, saturation)."""
    bad: list[str] = []
    r, c = dark["roles"], dark["colors"]
    every = {**{f"colors.{k}": v for k, v in c.items()},
             **{f"roles.{k}": v for k, v in r.items()},
             **{f"ansi.{k}": v for k, v in dark["ansi"].items()}}
    for where, v in every.items() if "extremes" not in exempt else ():
        if v[:7] in ("#000000", "#ffffff"):
            bad.append(f"{where} is {v[:7]}: no pure black or white at night")

    def band(role: str, lo: float, hi: float) -> None:
        L = lightness(r[role])
        if not lo <= L <= hi:
            bad.append(f"roles.{role} {r[role]} is L* {L:.1f}, wants {lo}–{hi}")

    if "bands" not in exempt:
        band("bg", 7, 12)
        band("term_bg", 7, 12)
        band("surface", 10, 16)
    for name in ["roles.bg", "roles.surface", "roles.overlay", "roles.term_bg"] + \
            [f"colors.{n}" for n in panels if n in c]:
        v = every[name]
        if lightness(v) > 25:
            bad.append(f"{name} {v} is L* {lightness(v):.1f}: large surfaces stay at or under 25")

    def ratio(fg: str, bg: str, lo: float, hi: float = 21) -> None:
        k = rr.contrast(r[fg], r[bg])
        if not lo <= k <= hi:
            want = f"{lo}–{hi}:1" if hi < 21 else f"at least {lo}:1"
            bad.append(f"roles.{fg} on roles.{bg} is {k:.2f}:1, wants {want}")

    top = 21 if "halation" in exempt else 14
    ratio("fg", "bg", 7, top)
    ratio("fg", "surface", 7, top)
    ratio("term_fg", "term_bg", 7, top)
    ratio("muted", "bg", 4.5)
    for role in ("accent", "link", "urgent", "success", "warning"):
        ratio(role, "bg", 4.5)
    for role in ("accent", "urgent", "link") if "saturation" not in exempt else ():
        if chroma(r[role]) >= chroma(light["roles"][role]):
            bad.append(f"roles.{role} {r[role]} is no less saturated than light's "
                       f"{light['roles'][role]} (C* {chroma(r[role]):.0f} vs {chroma(light['roles'][role]):.0f})")
    for i in range(1, 8):
        k = rr.contrast(dark["ansi"][f"color{i}"], r["term_bg"])
        if k < 4.5:
            bad.append(f"ansi.color{i} {dark['ansi'][f'color{i}']} on the terminal is {k:.2f}:1, wants 4.5")
    if dark["fonts"]["weight"] < 400:
        bad.append(f"fonts.weight {dark['fonts']['weight']}: nothing under 400 at night")
    return bad


def wallpaper_violations(path: Path) -> list[str]:
    """Mean L* at or under 16, and the 99.9th percentile at or under 45."""
    import numpy as np
    from PIL import Image

    with Image.open(path) as im:
        px = np.asarray(im.convert("RGB"), dtype=np.float64) / 255
    lin = np.where(px <= 0.04045, px / 12.92, ((px + 0.055) / 1.055) ** 2.4)
    y = lin @ np.array([0.2126, 0.7152, 0.0722])
    L = np.where(y > 216 / 24389, 116 * np.cbrt(y) - 16, 24389 / 27 * y)
    bad = []
    if L.mean() > 16:
        bad.append(f"{path.name}: mean L* {L.mean():.1f}, wants at most 16")
    if np.percentile(L, 99.9) > 45:
        bad.append(f"{path.name}: L* {np.percentile(L, 99.9):.1f} at the 99.9th percentile, wants at most 45")
    return bad


def has_pil() -> bool:
    try:
        import numpy  # noqa: F401
        from PIL import Image  # noqa: F401
    except ImportError:
        return False
    return True


class NightRules(unittest.TestCase):
    def test_each_rice_at_night(self):
        for name, panels in PANELS.items():
            with self.subTest(name):
                ctxs = rr.load_modes(RICES / name)
                if not ctxs["dark"]["has_mode"]:
                    self.skipTest(f"{name} has no [modes.dark.*] yet")
                self.assertEqual(night_violations(ctxs["light"], ctxs["dark"], panels, EXEMPT.get(name, ())), [])

    @unittest.skipUnless(has_pil(), "needs numpy and Pillow")
    def test_dark_wallpapers(self):
        for name, rel in WALLPAPERS.items():
            if "wallpaper" in EXEMPT.get(name, {}):
                continue
            with self.subTest(name):
                path = RICES / name / rel
                if not path.exists():
                    self.skipTest(f"{name} has no {rel} yet")
                self.assertEqual(wallpaper_violations(path), [])


def fixture(**roles: str) -> dict:
    """A dark palette that keeps every rule, with `roles` swapped in."""
    base = {"bg": "#1c1a17", "surface": "#24211d", "overlay": "#161411", "border": "#3a3630",
            "fg": "#d9d2c3", "muted": "#9c968a", "accent": "#a3b4f0", "urgent": "#ef8a78",
            "selection": "#3b3024", "success": "#9cc48a", "warning": "#e2c46a", "cursor": "#e6dfcf",
            "link": "#a3b4f0", "shadow": "#0b0a09", "term_bg": "#1c1a17", "term_fg": "#d9d2c3"}
    base.update(roles)
    ansi = ["#1c1a17", "#ef8a78", "#9cc48a", "#e2c46a", "#a3b4f0", "#d39bd0", "#86c4bd", "#c9c1b0"] * 2
    return {"roles": base, "colors": {"sheet": base["bg"]},
            "ansi": {f"color{i}": v for i, v in enumerate(ansi)}, "fonts": {"weight": 400}}


LIGHT = {"roles": {"accent": "#1c2a6e", "urgent": "#c8372d", "link": "#1c2a6e"}}


class TheRulesThemselves(unittest.TestCase):
    """The checker catches what it should, so a green run means something."""

    def test_a_kept_palette_passes(self):
        self.assertEqual(night_violations(LIGHT, fixture(), ["sheet"]), [])

    def test_each_rule_bites(self):
        cases = {
            "no pure black": fixture(bg="#000000"),
            "wants 7–12": fixture(bg="#2e2a26"),
            "large surfaces": fixture(overlay="#5a554c"),
            "wants 7–14:1": fixture(fg="#f4f1ec"),          # halation
            "muted on roles.bg": fixture(muted="#5a554c"),
            "no less saturated": fixture(accent="#3d5cff", link="#3d5cff"),
        }
        for want, dark in cases.items():
            with self.subTest(want):
                found = night_violations(LIGHT, dark, ["sheet"])
                self.assertTrue(any(want in line for line in found), found)

    def test_exemptions_reach_only_their_rules(self):
        everything = {"bands", "halation", "saturation", "extremes"}
        abyss_like = fixture(bg="#01060b", term_bg="#040f17", surface="#061521", fg="#cdeef0",
                             shadow="#000000")
        self.assertEqual(night_violations(LIGHT, abyss_like, ["sheet"], everything), [])
        # unreadable terminal colours and dim accents are never let off
        bad = fixture(bg="#01060b", term_bg="#040f17", muted="#2a4450")
        bad["ansi"]["color1"] = "#3a1a24"
        found = night_violations(LIGHT, bad, ["sheet"], everything)
        self.assertTrue(any("ansi.color1" in f for f in found), found)
        self.assertTrue(any("muted on roles.bg" in f for f in found), found)
        for name, rules in EXEMPT.items():
            self.assertLessEqual(set(rules), everything | {"wallpaper"}, name)
            self.assertTrue(all(why for why in rules.values()), f"{name}: every exemption says why")

    @unittest.skipUnless(has_pil(), "needs numpy and Pillow")
    def test_the_wallpaper_check(self):
        import tempfile
        from PIL import Image

        with tempfile.TemporaryDirectory() as d:
            dim = Path(d) / "dim.png"
            Image.new("RGB", (64, 36), "#141210").save(dim)
            self.assertEqual(wallpaper_violations(dim), [])
            grey = Path(d) / "grey.png"
            Image.new("RGB", (64, 36), "#5a5a5a").save(grey)
            self.assertTrue(any("mean L*" in v for v in wallpaper_violations(grey)))
            lamp = Image.new("RGB", (100, 100), "#141210")
            lamp.paste((200, 190, 170), (0, 0, 10, 10))     # 1% of the frame, bright
            lamp.save(Path(d) / "lamp.png")
            self.assertTrue(any("99.9th" in v for v in wallpaper_violations(Path(d) / "lamp.png")))


if __name__ == "__main__":
    unittest.main()
