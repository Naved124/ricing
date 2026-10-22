"""Satsuei: the rice that takes its look from the user's wallpaper.

The pipeline (satsuei-wall) runs here against the seed plate, with a stand-in
for matugen when it isn't installed; the shell runs under PySide6 against the
Quickshell stand-ins (tests/qs_smoke.py) and those tests skip without it.
"""

import importlib.machinery
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SHELLS = REPO / "quickshell/.config/quickshell"
SAT = SHELLS / "satsuei"
RICE = REPO / "rices/.config/rices/satsuei"
BIN = REPO / "switcher/.local/bin"

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


class Packages(unittest.TestCase):
    def test_the_fonts_are_installed(self):
        install = (REPO / "install").read_text()
        for family in ("Dela Gothic One", "M PLUS Rounded 1c", "JetBrains Mono"):
            self.assertIn(f'"{family}|', install)
        for weight in ("Regular", "Medium", "Bold", "ExtraBold"):
            self.assertIn(f'"M PLUS Rounded 1c|{weight}|', install)

    def test_the_tools_are_installed(self):
        install = (REPO / "install").read_text()
        for entry in ("matugen:matugen-bin", "inotifywait:inotify-tools", "zenity:zenity",
                      "magick:imagemagick", "cava:cava", "brightnessctl:brightnessctl",
                      "hyprsunset:hyprsunset", "|qt6-shadertools", "|ttf-jetbrains-mono"):
            self.assertIn(entry, install)
        # yay first, as the user installs with it
        self.assertIn("for h in yay paru; do", install)


STUB_HOME = Path("/tmp/qsstub-home")      # the stand-ins' HOME (tests/qsstub/Quickshell)


def wall(args: list[str], home: Path, **env) -> subprocess.CompletedProcess:
    e = {**os.environ, "HOME": str(home), "XDG_STATE_HOME": str(home / ".local/state"),
         "XDG_DATA_HOME": str(home / ".local/share"), "XDG_CACHE_HOME": str(home / ".cache"),
         "XDG_CONFIG_HOME": str(home / ".config"), "SATSUEI_NO_APPLY": "1", "SATSUEI_QUIET": "1",
         "SATSUEI_MATUGEN": "none", **env}
    return subprocess.run([str(BIN / "satsuei-wall"), *args], env=e, capture_output=True, text=True,
                          timeout=300)


def has_magick() -> bool:
    return bool(shutil.which("magick") or shutil.which("convert"))


rw = load("satsuei_wall", BIN / "satsuei-wall")
rr = load("rice_render_satsuei", REPO / "render/.local/bin/rice-render")


@unittest.skipUnless(has_magick(), "needs ImageMagick")
class Pipeline(unittest.TestCase):
    """satsuei-wall: a picture in, the rice's look out."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.home = Path(cls.tmp.name)
        p = wall(["set", str(RICE / "seed/wall.webp")], cls.home)
        assert p.returncode == 0, p.stderr
        cls.state = cls.home / ".local/state/satsuei"
        cls.theme = json.loads((cls.state / "theme.json").read_text())

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_it_writes_the_state(self):
        t = self.theme
        for f in ("plate", "bloom", "soft"):
            self.assertTrue(Path(t[f]).is_file(), f)
        self.assertTrue((self.state / "plate.webp").is_symlink())
        self.assertTrue((self.home / ".local/share/satsuei/walls/wall.webp").is_file())
        self.assertFalse(t["animated"])
        self.assertEqual((t["width"], t["height"]), (2088, 1080))
        # the blur maps: a quarter and an eighth of the plate
        out = subprocess.run(rw.im("identify", "-format", "%w %h ", t["bloom"], t["soft"]),
                             capture_output=True, text=True).stdout.split()
        self.assertEqual(out, ["522", "270", "261", "135"])

    def test_the_tokens(self):
        t = self.theme
        for k in ("accent", "accent2", "onAccent", "tint", "glass", "ink", "fg", "fgDim"):
            self.assertRegex(t[k], r"^#[0-9a-f]{6}$", k)
        h, s, l = rw.hsl(t["accent"])
        self.assertTrue(0.64 - 4e-3 <= l <= 0.74 + 4e-3, l)
        self.assertGreaterEqual(rw.hue_dist(h, rw.hsl(t["accent2"])[0]), 30)
        self.assertAlmostEqual(rw.hsl(t["tint"])[2], 0.12, delta=0.01)
        self.assertGreaterEqual(rw.contrast(t["onAccent"], t["accent"]), 4.5)
        self.assertEqual(len(t["swatches"]), 6)
        # the mock's light source for its plate: up and to the right
        self.assertGreater(t["lightX"], 0.6)
        self.assertLess(t["lightY"], 0.4)

    def test_the_overlay_renders_and_keeps_the_night_rules(self):
        import test_night
        saved = rr.HOME
        rr.HOME = self.home
        try:
            ctx = rr.load_modes(RICE)
        finally:
            rr.HOME = saved
        self.assertEqual(ctx["dark"]["roles"]["accent"], self.theme["accent"])
        self.assertEqual(ctx["light"]["roles"]["accent"], self.theme["accent"])
        self.assertEqual(test_night.night_violations(ctx["light"], ctx["dark"], ["tint"], ("saturation",)), [])

    def test_any_picture_keeps_the_night_rules(self):
        """Pictures far from the seed: neon, pastel, grey, near black, white."""
        import test_night
        pics = {"neon": "plasma:magenta-lime", "pastel": "gradient:#ffd6e8-#d6f0ff",
                "grey": "xc:#808080", "night": "gradient:#020308-#101830", "snow": "xc:#f4f6f8"}
        for name, spec in pics.items():
            with self.subTest(name), tempfile.TemporaryDirectory() as d:
                home = Path(d)
                pic = home / f"{name}.png"
                subprocess.run(rw.im("convert", "-size", "320x180", "-seed", "4", spec, str(pic)), check=True)
                p = wall(["set", str(pic)], home)
                self.assertEqual(p.returncode, 0, p.stderr)
                saved = rr.HOME
                rr.HOME = home
                try:
                    ctx = rr.load_modes(RICE)
                finally:
                    rr.HOME = saved
                self.assertEqual(test_night.night_violations(ctx["light"], ctx["dark"], ["tint"],
                                                             ("saturation",)), [])

    def test_matugen_output_is_read(self):
        """Both shapes of matugen's JSON: v2 (colors.dark.x) and v3+ (colors.x.dark.color)."""
        with tempfile.TemporaryDirectory() as d:
            for shape in ("v2", "v4"):
                fake = Path(d) / f"matugen-{shape}"
                cols = {"primary": "#ffb4a7", "secondary": "#e7bdb6", "tertiary": "#ddc48c",
                        "surface": "#1a1110", "error": "#ffb4ab", "on_surface": "#f1dfdb"}
                doc = ({"colors": {"dark": cols}} if shape == "v2" else
                       {"colors": {k: {"dark": {"color": v}, "light": {"color": "#000000"}} for k, v in cols.items()}})
                fake.write_text("#!/bin/sh\ncat <<'X'\n" + json.dumps(doc) + "\nX\n")
                fake.chmod(0o755)
                with self.subTest(shape):
                    p = wall(["theme", str(RICE / "seed/wall.webp")], Path(d), SATSUEI_MATUGEN=str(fake))
                    t = json.loads(p.stdout)
                    self.assertEqual(t["source"], "matugen")
                    self.assertAlmostEqual(rw.hsl(t["accent"])[0], rw.hsl("#ffb4a7")[0], delta=2)
                    self.assertAlmostEqual(rw.hsl(t["accent2"])[0], rw.hsl("#ddc48c")[0], delta=2)

    def test_the_light_can_be_picked(self):
        with tempfile.TemporaryDirectory() as d:
            home = Path(d)
            wall(["set", str(RICE / "seed/wall.webp")], home)
            wall(["light", "0.25", "0.1"], home)
            t = json.loads((home / ".local/state/satsuei/theme.json").read_text())
            self.assertEqual((t["lightX"], t["lightY"], t["lightPicked"]), (0.25, 0.1, True))

    def test_the_seed_matches_the_palette(self):
        """palette.toml's colours are the seed plate's (tools/satsuei-seed)."""
        seed = json.loads((RICE / "seed/theme.json").read_text())
        pal = tomllib.loads((RICE / "palette.toml").read_text())["modes"]["dark"]
        for k in ("accent", "accent2", "tint", "fg", "bg", "surface"):
            self.assertEqual(pal["colors"][k], seed[k], "run tools/satsuei-seed")
        self.assertEqual(pal["colors"]["fg_dim"], seed["fgDim"])
        for f in ("wall.webp", "bloom.png", "soft.png"):
            self.assertTrue((RICE / "seed" / f).is_file(), f)

    def test_rice_recolours_the_desktop(self):
        rice = (BIN / "rice").read_text()
        self.assertIn("recolour|recolor) recolour ;;", rice)
        self.assertIn('subprocess.run(["rice", "recolour"]', (BIN / "satsuei-wall").read_text())


class Style(unittest.TestCase):
    def test_the_committed_style_matches_the_palette(self):
        """Style.qml (type, shape, motion, the characters' art) is rendered from
        palette.toml and must not change with the wallpaper."""
        ctxs = rr.load_modes(RICE)
        self.assertEqual(ctxs["dark"]["install"]["quickshell/Style.qml"],
                         ".config/quickshell/satsuei/common/Style.qml")
        src = RICE / "templates/quickshell/Style.qml"
        want = rr.render_text(src.read_text(), ctxs["dark"], str(src))
        self.assertEqual((SAT / "common/Style.qml").read_text(), want, "run: tools/regen")
        # nothing the overlay writes reaches it
        overlay_keys = set(re.findall(r"^(\w+)\s*=", rw.overlay(json.loads((RICE / "seed/theme.json").read_text())), re.M))
        used = set(re.findall(r"colors\.(\w+)", src.read_text()))
        self.assertEqual(used & overlay_keys, set())

    def test_theme_has_no_colour_of_its_own(self):
        text = (SAT / "common/Theme.qml").read_text()
        self.assertNotRegex(text, r"#[0-9a-fA-F]{3,8}\b")
        self.assertIn("watchChanges: true", text)
        self.assertIn("duration: 600", text)


@unittest.skipUnless(has_pyside(), "needs PySide6")
class ThemeFile(unittest.TestCase):
    """The shell's Theme follows theme.json, fading between plates."""

    def test_theme_follows_the_file(self):
        import qs_smoke
        state = STUB_HOME / ".local/state/satsuei"
        seed = STUB_HOME / ".config/rices/satsuei"
        shutil.rmtree(STUB_HOME / ".local/state/satsuei", ignore_errors=True)
        shutil.rmtree(seed, ignore_errors=True)
        seed.mkdir(parents=True)
        shutil.copytree(RICE / "seed", seed / "seed")
        try:
            cmd = [sys.executable, qs_smoke.__file__, str(SAT), "--seconds", "4.2",
                   "--poke", str(REPO / "tests/pokes/satsuei-theme.qml")]
            p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            import time
            time.sleep(1.6 + 0.6)                 # the engine starts in about half a second
            state.mkdir(parents=True)
            t = json.loads((RICE / "seed/theme.json").read_text())
            t.update(accent="#40c0ff", tint="#102030", lightX=0.2, plate="/x/plate.png", seed=False)
            (state / "theme.json").write_text(json.dumps(t))
            out, err = p.communicate(timeout=90)
            res = json.loads(out)
        finally:
            shutil.rmtree(STUB_HOME / ".local/state/satsuei", ignore_errors=True)
            shutil.rmtree(seed, ignore_errors=True)
        self.assertEqual(res["errors"], [])
        pokes = {x["tag"]: x for x in res["pokes"]}
        seedt = json.loads((RICE / "seed/theme.json").read_text())
        self.assertTrue(pokes["first"]["seed"])
        self.assertEqual(pokes["first"]["accent"], seedt["accent"])
        self.assertTrue(pokes["first"]["plate"].endswith("/rices/satsuei/seed/wall.webp"))
        self.assertTrue(pokes["first"]["mode"])
        self.assertIn(pokes["first"]["phase"], ("Night", "Before dawn", "Dawn", "Morning", "Noon",
                                                "Afternoon", "Golden hour", "Dusk"))
        self.assertEqual(pokes["after"]["accent"], "#40c0ff")
        self.assertEqual(pokes["after"]["plate"], "file:///x/plate.png")
        self.assertAlmostEqual(pokes["after"]["lightX"], 0.2, places=3)
        # a 600 ms fade, not a jump
        self.assertNotIn(pokes["fading"]["accent"], ("#40c0ff",))


if __name__ == "__main__":
    unittest.main()
