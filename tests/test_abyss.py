"""Abyss: the reef wallpaper and the shell around it.

The shells are run under PySide6 against stand-ins for Quickshell's types
(tests/qs_smoke.py); those tests skip when PySide6 isn't installed. The reef's
look is checked against the mock with tools/still.py --mock (needs a GL
context), not here.
"""

import importlib.machinery
import importlib.util
import json
import re
import sys
import tomllib
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SHELLS = REPO / "quickshell/.config/quickshell"
ABYSS = SHELLS / "abyss"
REEF = ABYSS / "reef"
RICE = REPO / "rices/.config/rices/abyss"

sys.path.insert(0, str(Path(__file__).resolve().parent))


def has_pyside() -> bool:
    try:
        import PySide6.QtQml  # noqa: F401
    except ImportError:
        return False
    return True


def load(name: str, path: Path):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class Palette(unittest.TestCase):
    def test_dark_only_with_the_mocks_tokens(self):
        data = tomllib.loads((RICE / "palette.toml").read_text())
        self.assertEqual(data["meta"]["modes"], ["dark"])
        self.assertEqual(sorted(data["modes"]), ["dark"])
        c = data["modes"]["dark"]["colors"]
        want = {"abyss": "#01060b", "glass": "#040f17b3", "glass_strong": "#040e15db", "line": "#78e8f026",
                "glow": "#62f2e2", "glow2": "#b98cff", "pink": "#ff8fc0", "ink": "#cdeef0", "ink_dim": "#7ea4ab"}
        for k, v in want.items():
            self.assertEqual(c[k], v, k)
        w = data["modes"]["dark"]["wallpaper"]
        self.assertEqual(w["water_top"], [0.016, 0.085, 0.125])
        self.assertEqual(w["water_mid"], [0.006, 0.034, 0.062])
        self.assertEqual(w["water_bottom"], [0.002, 0.009, 0.018])
        self.assertEqual(w["creatures"], [168, 186, 205, 272, 312])
        self.assertEqual(w["jellies"], [186, 272, 322, 166, 205])
        m = data["motion"]
        self.assertEqual((m["bloom"], m["settle"], m["sink"]),
                         ([0.2, 0.9, 0.2, 1.0], [0.34, 1.3, 0.64, 1.0], [0.55, 0.0, 0.85, 0.4]))


class Reef(unittest.TestCase):
    def test_every_shader_is_compiled(self):
        for src in sorted(REEF.glob("shaders/*.frag")) + sorted(REEF.glob("shaders/*.vert")):
            with self.subTest(src.name):
                qsb = src.with_name(src.name + ".qsb")
                self.assertTrue(qsb.exists(), "run tools/shaders")
                self.assertGreaterEqual(qsb.stat().st_mtime, src.stat().st_mtime - 1, "recompile with tools/shaders")

    def test_the_water_is_the_mocks(self):
        water = (REEF / "shaders/water.frag").read_text()
        for line in ("bg += vec3(.025, .10, .12) * smoothstep(.28, 0., suv.y);",
                     "float r1 = pow(.5 + .5 * sin(ang * 36. + t * .12 + sweep * 6. + noise(vec2(ang * 6., t * .07)) * 3.), 5.);",
                     "float r2 = pow(.5 + .5 * sin(ang * 59. - t * .09 + sweep * 4.), 9.);",
                     "bg += vec3(.035, .14, .17) * rays * (.6 + beat * .35);",
                     "bg += vec3(.06, .18, .2) * c * smoothstep(.3, 0., suv.y) * .4;",
                     "float sn = snow(suv, 22., .35, t, asp) * .5 + snow(suv + .37, 38., .22, t, asp) * .3;",
                     "vec2 off = g * .016;", "col += vec3(.2, .62, .7) * spec * .32 * (1. - uv.y * .55);",
                     "col = col / (1. + col * .25);"):
            self.assertIn(line, water)
        ripple = (REEF / "shaders/ripple.frag").read_text()
        self.assertIn("* 0.5 - st.g) * 0.982", ripple)

    def test_the_world_is_the_mocks(self):
        js = (REEF / "reef.js").read_text()
        for line in ("wB[i] = ((wA[i - 1] + wA[i + 1] + wA[i - gw] + wA[i + gw]) * .5 - wB[i]) * .982;",
                     "if (d2 < 484)", "if (d2 < 4900)", "if (d2 < 8100)", "ns = clamp(sp, .55, 2.8)",
                     "const vx = (nd.x - nd.ox) * .93", "R.NP = Math.round(clamp(W * H / 2600, 180,",
                     "pb[i] = Math.min(1, .05 + (pb[i] - .05) * Math.pow(.962, dt) + gm * .35);",
                     "R.flow = dir * 2.8 * R.mot;", "drop(x, y, 1.6, 24); excite(x, y, 190, .85); scatterFish(x, y, 240, 3.2);"):
            self.assertIn(line, js)

    def test_a_sprite_for_every_glow(self):
        gen = load("abyss_gen", RICE / "assets/gen.py")
        w = tomllib.loads((RICE / "palette.toml").read_text())["modes"]["dark"]["wallpaper"]
        keys = gen.sprite_keys(w)
        self.assertEqual(len(keys), 23)
        have = sorted(p.name for p in (REEF / "sprites").glob("glow-*.png"))
        self.assertEqual(have, sorted("glow-{}-{}-{}.png".format(*k) for k in keys), "run assets/gen.py")
        # reef.js asks for the same list
        js = (REEF / "reef.js").read_text()
        self.assertIn("for (const h of [c[0], c[1], c[3], c[4]]) k.push([h, 95, 62]);", js)

    def test_the_shipped_config_says_the_defaults(self):
        shipped = (REPO / "switcher/.local/share/rice/abyss.toml").read_text()
        config = (ABYSS / "services/Config.qml").read_text()
        for key, value in re.findall(r"(?m)^\s+(\w+): ([\w.]+),?\s+//", config):
            with self.subTest(key):
                self.assertRegex(shipped, rf"(?m)^#?\s*{key} = {re.escape(value)}\b")

    def test_no_frame_animation(self):
        # a FrameAnimation keeps the window redrawing at the display's rate;
        # the reef ticks on a Timer and draws only when something changed
        for f in ABYSS.rglob("*.qml"):
            self.assertNotIn("FrameAnimation", f.read_text(), f)


class Apps(unittest.TestCase):
    """Hyprland and the app themes, rendered from the palette."""

    @classmethod
    def setUpClass(cls):
        rr = load("rice_render", REPO / "render/.local/bin/rice-render")
        rr.SHARED = REPO / "render/.local/share/rice/templates"
        ctx = rr.load_modes(RICE)["dark"]
        cls.out = {p.relative_to(RICE / "build/dark").as_posix(): v.decode(errors="replace")
                   for p, v in rr.mode_outputs(RICE, ctx).items() if "build/dark" in p.as_posix()}

    def test_hyprland(self):
        hypr, mode = self.out["hypr.lua"], self.out["hypr-mode.lua"]
        for want in ("rounding         = 12", "gaps_in     = 8", "gaps_out    = 18", "border_size = 1",
                     "size              = 8", "passes            = 3", 'style = "popin 96%"',
                     '"^abyss-(bar|launcher|island|center|osd|power|toast|keys|stats)$"'):
            self.assertIn(want, hypr)
        self.assertNotIn("screen_shader", hypr)
        for want in ('"rgba(62f2e2aa)", "rgba(b98cffaa)"', "angle  = 45", '"rgba(78e8f026)"',
                     "range          = 24", "brightness = 0.85", "vibrancy   = 0.2",
                     'background_color = "rgba(01060bff)"'):
            self.assertIn(want, mode)

    def test_terminal_and_editor(self):
        self.assertIn("background_opacity    0.8", self.out["kitty.conf"])
        kitty = self.out["kitty-colors.conf"]
        for want in ("background            #040f17", "cursor                #62f2e2",
                     "active_tab_foreground   #62f2e2"):
            self.assertIn(want, kitty)
        nvim = self.out["nvim/rice.lua"]
        for want in ('hl("Normal",       { fg = c.term_fg, bg = "NONE" })', 'hl("Keyword",    { fg = c.magenta })',
                     'hl("Function",   { fg = c.accent })', 'hl("Type",       { fg = c.link })',
                     'hl("Comment",    { fg = c.comment, italic = true })', 'comment   = "#7ea4ab"',
                     'faint     = "#2a4450"', 'hl("LineNr",       { fg = c.faint })', 'magenta   = "#b98cff"',
                     'green     = "#5fe0a8"', 'yellow    = "#e8d27a"', 'link      = "#82c3ff"',
                     'hl("FloatBorder",  { fg = c.border, bg = c.float })'):
            self.assertIn(want, nvim)

    def test_tools(self):
        btop = self.out["btop.theme"]
        for want in ('cpu_start]="#62f2e2"', 'cpu_mid]="#b98cff"', 'cpu_end]="#ff8fc0"', 'cpu_box]="#13282d"'):
            self.assertIn(want, btop)
        self.assertIn("gradient_count = 3", self.out["cava/config"])
        self.assertIn('current = { fg = "#62f2e2", bg = "#061521", underline = true', self.out["yazi/flavor.toml"])
        ff = self.out["fastfetch/config.jsonc"]
        self.assertIn('"type": "data"', ff)
        self.assertIn('"keys": "magenta"', ff)
        self.assertIn('set default-bg              "#040f17"', self.out["zathurarc"])
        # GTK: adw-gtk3-dark (palette meta) with the teal accent
        self.assertIn("#62f2e2", self.out["gtk/gtk.css"])
        self.assertIn("adw-gtk3-dark", (RICE / "palette.toml").read_text())


class Binds(unittest.TestCase):
    """base.lua's shell binds reach a GlobalShortcut in every shell; the
    reef's two are Abyss's alone."""

    def test_every_global_has_a_shortcut(self):
        base = (REPO / "hypr/.config/hypr/base.lua").read_text()
        names = set(re.findall(r'global\("quickshell:([\w-]+)"\)', base))
        self.assertIn("reef-interactive", names)
        self.assertIn("reef-stats", names)
        self.assertRegex(base, r'key\("CTRL \+ R"\),\s+hl\.dsp\.global\("quickshell:reef-interactive"\)')
        self.assertRegex(base, r'key\("CTRL \+ SHIFT \+ R"\),\s+hl\.dsp\.global\("quickshell:reef-stats"\)')
        # Super+Alt+R stays region recording
        self.assertRegex(base, r'key\("ALT \+ R"\),\s+hl\.dsp\.exec_cmd\("rice-rec toggle region"\)')
        for shell in ("abyss", "nacre", "paper"):
            have = set()
            for f in (SHELLS / shell).rglob("*.qml"):
                have |= set(re.findall(r'GlobalShortcut \{(?:\s*id: \w+)?\s*name: "([\w-]+)"', f.read_text()))
            want = names if shell == "abyss" else {n for n in names if not n.startswith("reef-")}
            with self.subTest(shell):
                self.assertEqual(want - have, set())

    def test_the_fonts_are_installed(self):
        install = (REPO / "install").read_text()
        for family in ("Jura", "JetBrains Mono"):
            self.assertIn(f'"{family}|', install)


class Switch(unittest.TestCase):
    """Abyss floods in and drains out; its card is the reef at rest."""

    def test_flood_and_drain(self):
        meta = tomllib.loads((RICE / "palette.toml").read_text())["meta"]
        self.assertEqual((meta["transition"], meta["transition_out"]), ("flood", "drain"))
        for shader in ("transition", "drain"):
            with self.subTest(shader):
                src, qsb = RICE / f"{shader}.frag", RICE / f"{shader}.frag.qsb"
                self.assertTrue(qsb.exists(), "run tools/shaders")
                self.assertGreaterEqual(qsb.stat().st_mtime, src.stat().st_mtime - 1, "recompile with tools/shaders")
        rice = (REPO / "switcher/.local/bin/rice").read_text()
        self.assertIn('dissolve "$target" "$from"', rice)
        chooser = (SHELLS / "rice/shell.qml").read_text()
        for needle in ("transition_out", "flood: 1100", "drain: 1000"):
            self.assertIn(needle, chooser)

    def test_the_card(self):
        card = (RICE / "card.qml").read_text()
        self.assertIn("source: root.base", card)
        self.assertIn("running: root.visible", card)
        self.assertTrue((RICE / "preview.png").exists())


@unittest.skipUnless(has_pyside(), "needs PySide6")
class Shells(unittest.TestCase):
    """Every shell starts without a QML error against the Quickshell stand-ins."""

    def test_each_shell_starts_clean(self):
        import qs_smoke
        for shell in ("abyss", "nacre", "paper", "rice"):
            with self.subTest(shell):
                self.assertEqual(qs_smoke.smoke(SHELLS / shell)[0], [])

    def test_the_reef_throttles(self):
        import qs_smoke
        found, pokes = qs_smoke.smoke(ABYSS, 11, REPO / "tests/pokes/abyss-throttle.qml")
        self.assertEqual(found, [])
        by = {p["state"]: p for p in pokes}
        self.assertEqual(len(by), 12, pokes)
        full = by["full"]
        self.assertEqual((full["rate"], full["running"], full["reduced"]), (30, True, False))
        self.assertEqual(full["plankton"], 620)
        for state, why in (("fullscreen", "stopped: fullscreen"), ("locked", "stopped: locked"),
                           ("dpms off", "stopped: dpms off")):
            with self.subTest(state):
                self.assertEqual((by[state]["rate"], by[state]["running"], by[state]["throttle"]), (0, False, why))
        for state, why in (("covered", "reduced: windows cover 100%"), ("low battery", "reduced: battery 20%")):
            with self.subTest(state):
                p = by[state]
                self.assertEqual((p["rate"], p["reduced"], p["throttle"], p["plankton"], p["bloom"]),
                                 (15, True, why, 310, "off"))
        for state in ("back", "unlocked", "half covered", "charging", "dpms on"):
            with self.subTest(state):
                self.assertEqual((by[state]["rate"], by[state]["throttle"]), (30, "full"))
        self.assertEqual(by["half covered"]["coverage"], 0.5)
        self.assertFalse(by["pointer off"]["interactive"])

    def test_every_surface_opens_clean(self):
        import qs_smoke
        found, pokes = qs_smoke.smoke(ABYSS, 8, REPO / "tests/pokes/abyss-walk.qml")
        self.assertEqual(found, [])
        self.assertEqual(len(pokes), 1, pokes)
        self.assertEqual(pokes[0]["mode"], "dark")
        self.assertTrue(pokes[0]["locked"])
        # every screen's wallpaper reef stops while the lock's own runs
        self.assertEqual({s["throttle"] for s in pokes[0]["stats"].values()}, {"stopped: locked"})


if __name__ == "__main__":
    unittest.main()
