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
from unittest import mock
from datetime import date
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

    def test_the_folder_is_scanned(self):
        with tempfile.TemporaryDirectory() as d:
            home = Path(d)
            walls = home / "Pictures/Wallpapers"
            (walls / "sky").mkdir(parents=True)
            shutil.copyfile(RICE / "seed/wall.webp", walls / "sky/wall.webp")
            lines = [json.loads(l) for l in wall(["scan", str(walls)], home).stdout.splitlines()]
            self.assertEqual(lines[0], {"path": str(walls / "sky/wall.webp"), "rel": "sky/wall.webp",
                                        "mtime": lines[0]["mtime"], "pending": True})
            done = lines[1]
            self.assertTrue(Path(done["thumb"]).is_file())
            self.assertEqual(len(done["swatches"]), 6)
            self.assertEqual(lines[-1], {"done": True, "count": 1})
            # the second time it's all cached
            again = [json.loads(l) for l in wall(["scan", str(walls)], home).stdout.splitlines()]
            self.assertNotIn("pending", again[0])
            self.assertEqual(again[0]["sha1"], done["sha1"])

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
            cmd = [sys.executable, qs_smoke.__file__, str(SAT), "--seconds", "8.5",
                   "--poke", str(REPO / "tests/pokes/satsuei-theme.qml")]
            p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            import time
            time.sleep(5.0)                       # after the poke's first report, before its last
            state.mkdir(parents=True)
            t = json.loads((RICE / "seed/theme.json").read_text())
            t.update(accent="#40c0ff", tint="#102030", lightX=0.2, plate="/x/plate.png", seed=False)
            (state / "theme.json").write_text(json.dumps(t))
            out, err = p.communicate(timeout=90)
            res = json.loads(out)
        finally:
            # the seed stays: tests/qs_shot.py draws the shell with it
            shutil.rmtree(STUB_HOME / ".local/state/satsuei", ignore_errors=True)
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


class PlateSource(unittest.TestCase):
    """The plate and its pass, as written."""
    PLATE = SAT / "plate"

    def test_the_shaders_are_compiled(self):
        for name in ("satsuei", "rays"):
            src = self.PLATE / f"shaders/{name}.frag"
            qsb = self.PLATE / f"shaders/{name}.frag.qsb"
            self.assertTrue(qsb.exists(), "run tools/shaders")
            self.assertGreaterEqual(qsb.stat().st_mtime, src.stat().st_mtime - 1, "recompile with tools/shaders")

    def test_the_mocks_passes(self):
        frag = (self.PLATE / "shaders/satsuei.frag").read_text()
        for needle in ("0.22 * bloom", "smoothstep(0.5, 0.96", "0.36 * bloom", "1.04", "for (int k = 0; k < 3; k++)",
                       "c * mul + lift", "mix(vec3(luma(g)), g, sat)", "0.42 * dot(cc, cc)", "* 0.07 * grain",
                       "mix(raw, c, pass) * expo"):
            self.assertIn(needle, frag)
        rays = (self.PLATE / "shaders/rays.frag").read_text()
        for needle in ("i < 44", "il *= 0.962", "smoothstep(0.58", "sin(a * 19.0 + time * 0.13)",
                       "sin(a * 7.0 - time * 0.09)", "uniform sampler2D softMap"):
            self.assertIn(needle, rays)

    def test_the_window(self):
        plate = (self.PLATE / "Plate.qml").read_text()
        for needle in ("WlrLayer.Background", '"satsuei-plate"', "ExclusionMode.Ignore", "interval: 33",
                       "Hypr.fullscreenOn(monitor)", "Battery.level < 0.3", "Shell.locked", "duration: 250",
                       "* -0.006", "Motion.reduced", '"satsuei-wall", "light"'):
            self.assertIn(needle, plate)
        for f in SAT.rglob("*.qml"):
            self.assertNotIn("FrameAnimation", f.read_text(), f)

    def test_one_keyframe_table(self):
        grade = (SAT / "common/Grade.qml").read_text()
        for row in ("[17.4, [1.13, 0.95, 0.80], [0.03, 0.01, 0.00], 1.16, 1.05, [1.00, 0.70, 0.42]]",
                    "[6.5,  [1.06, 0.93, 0.93]", "* 0.88, m[2] * 0.7", "* 0.3"):
            self.assertIn(row, grade)
        hits = [f for f in SAT.rglob("*.qml") if "17.4" in f.read_text()]
        self.assertEqual([f.name for f in hits], ["Grade.qml"])

    def test_the_seed_matches_the_mock(self):
        """tools/grab.py draws the seed plate at 07:12 brighter than the raw
        plate, the way the mock's pass does (side by side: mean 153 vs the
        mock's 163 of 255)."""
        self.assertTrue((self.PLATE / "tools/grab.py").exists())


@unittest.skipUnless(has_pyside(), "needs PySide6")
class PlateRuns(unittest.TestCase):
    def test_switches_and_pauses(self):
        import qs_smoke
        errors, pokes = qs_smoke.smoke(SAT, seconds=6.0, poke=REPO / "tests/pokes/satsuei-plate.qml")
        self.assertEqual(errors, [])
        by = {p["tag"]: p["screens"] for p in pokes}
        self.assertEqual(len(by["start"]), 2)              # the stand-ins have two screens
        for s in by["start"]:
            self.assertEqual(s["state"], "running")
            self.assertTrue(s["ticking"])
            self.assertEqual(s["effects"]["rays"], 1)
        for s in by["no rays"]:
            self.assertEqual(s["effects"]["rays"], 0)       # eased out within 250 ms
            self.assertTrue(s["ticking"])                   # the motes still move
        for s in by["locked"]:
            self.assertEqual(s["state"], "paused: locked")
            self.assertFalse(s["ticking"])
            self.assertEqual(s["effects"]["motes"], 0)
            self.assertEqual(s["effects"]["grade"], 1)      # the plate keeps its grade
        for s in by["unlocked"]:
            self.assertEqual(s["state"], "running")
            self.assertEqual(s["effects"]["rays"], 1)
        for s in by["raw"]:
            self.assertTrue(s["raw"])
            self.assertEqual(s["effects"]["grade"], 0)
        for s in by["golden"]:
            self.assertEqual(s["grade"]["phase"], "Golden hour")


class Glass(unittest.TestCase):
    """Step 4: Hyprland's glass for Satsuei, the bar and the eyecatch."""

    def hypr(self) -> tuple[str, str]:
        ctx = rr.load_modes(RICE)["dark"]
        out = []
        for name in ("hypr.lua", "hypr-mode.lua"):
            src = RICE / "templates" / name
            out.append(rr.render_text(src.read_text(), ctx, str(src)))
        return out[0], out[1]

    def test_the_plate_frosts_behind_windows(self):
        # Hyprland drew no blur behind GTK windows, so the plate frosts itself
        # inside every window on the screen's workspace, pass or no pass
        win = (SAT / "services/Windows.qml").read_text()
        self.assertIn('["hyprctl", "clients", "-j"]', win)
        for ev in ("openwindow", "closewindow", "movewindowv2", "changefloatingmode", "workspacev2"):
            self.assertIn(f'"{ev}"', win)
        plate = (SAT / "plate/Plate.qml").read_text()
        self.assertIn("Windows.onWorkspace(ws)", plate)
        self.assertIn("windows: win.glass", plate)
        frag = (SAT / "plate/shaders/satsuei.frag").read_text()
        # the frost goes into the raw plate, before the pass is mixed over it
        self.assertLess(frag.index("texture(frostMap, qt_TexCoord0).a * frost"), frag.index("vec3 c = raw;"))
        self.assertIn("property bool frost: true", (SAT / "common/Settings.qml").read_text())

    def test_gtk_windows_let_the_blur_in(self):
        # a solid GTK fill marks the window opaque and Hyprland skips the blur
        # behind it, so Satsuei's gtk.css.append makes the big fills glass
        ctx = rr.load_modes(RICE)["dark"]
        templates = REPO / "render/.local/share/rice/templates"
        with mock.patch.object(rr, "SHARED", templates):
            css = next(v.decode() for k, v in rr.mode_outputs(RICE, ctx).items() if k.name == "gtk.css")
        shared = (templates / "gtk/gtk.css").read_text()
        self.assertTrue(css.startswith(rr.render_text(shared, ctx, "gtk.css")))
        self.assertIn(f"@define-color window_bg_color {rr.Filters(ctx).rgba(ctx['roles']['bg'], '0.6')};", css)
        self.assertIn("@define-color popover_bg_color #", css)

    def test_hyprland(self):
        hypr, mode = self.hypr()
        for needle in ("size              = 8", "passes            = 3", "new_optimizations = true",
                       "rounding         = 16", 'leaf = "workspaces",   enabled = true, speed = 6,',
                       'style = "slide"', "blur = true, ignore_alpha = 0.3",
                       '"^satsuei-(bar|center|studio|subs|walls|cast|launcher|osd|power|toast|keys|stats)$"'):
            self.assertIn(needle, hypr)
        self.assertIn("vibrancy   = 0.2", mode)
        # nothing goes see-through for losing focus; glassy windows are frosted, terminals whole
        self.assertIn("inactive_opacity = 1.0", mode)
        self.assertIn('match = { tag = "glassy" }, opacity = "0.88 override 0.88 override"', hypr)
        self.assertIn('name = "satsuei-terminal"', hypr)
        seed = json.loads((RICE / "seed/theme.json").read_text())
        self.assertIn(f'"rgba({seed["accent"][1:]}ee)", "rgba({seed["accent2"][1:]}ee)"', mode)
        # kitty is glass too
        self.assertEqual(rr.load_modes(RICE)["dark"]["opacity"]["terminal"], 0.72)
        # every Satsuei layer is satsuei-*
        for f in SAT.rglob("*.qml"):
            for ns in re.findall(r'WlrLayershell\.namespace:\s*"([^"]+)"', f.read_text()):
                self.assertTrue(ns.startswith("satsuei-"), f"{f}: {ns}")

    def test_no_rounding_past_hyprlands_limit(self):
        """Hyprland refuses a window rule's rounding over 20 (Satsuei's panels are 22)."""
        rices = REPO / "rices/.config/rices"
        for rice in sorted(p for p in rices.iterdir() if (p / "templates/hypr.lua").exists()):
            ctx = rr.load_modes(rice)["dark"]
            src = rice / "templates/hypr.lua"
            text = rr.render_text(src.read_text(), ctx, str(src))
            for v in re.findall(r"\brounding\s*=\s*(\d+)", text):
                with self.subTest(rice.name):
                    self.assertLessEqual(int(v), 20)

    def test_the_bar(self):
        bar = (SAT / "bar/Bar.qml").read_text()
        for needle in ("pillHeight: 46", "edge: 10", "radius: 16", '"satsuei-bar"', "Shell.toggleStudio()",
                       "Episodes {", '"日月火水木金土"', "Status {", "Hypr.fullscreenOn(monitor)", "IdleInhibitor"):
            self.assertIn(needle, bar)
        eps = (SAT / "bar/Episodes.qml").read_text()
        for needle in ('padStart(2, "0")', "display: true", "Theme.accent", "ep.occupied", "Hypr.focusWorkspace(",
                       "Hypr.cycleWorkspace("):
            self.assertIn(needle, eps)
        status = (SAT / "bar/Status.qml").read_text() + (SAT / "bar/Reel.qml").read_text()
        for needle in ("model: 4", "Beat.levels", "Net.rate(", "Bluetooth.defaultAdapter", "Audio.icon",
                       "Battery.level", "SystemTray.items", '"rice", "lock"', "Shell.toggleCenter()",
                       "Shell.recording"):
            self.assertIn(needle, status)

    def test_the_eyecatch(self):
        eye = (SAT / "bar/Eyecatch.qml").read_text()
        for needle in ('"EP " + String(win.shownId).padStart(2, "0")', "interval: 1300 + 400", "duration: 400",
                       "duration: 500", 'app || "Empty"', "toUpperCase()", "spacing: 0.3", "mask: Region {}",
                       '"satsuei-eyecatch"'):
            self.assertIn(needle, eye)

    @unittest.skipUnless(has_pyside(), "needs PySide6")
    def test_an_episode_change_runs_clean(self):
        import qs_smoke
        errors, _ = qs_smoke.smoke(SAT, seconds=3.0, poke=REPO / "tests/pokes/satsuei-episode.qml")
        self.assertEqual(errors, [])


class SharedSurfaces(unittest.TestCase):
    """The entry points every shell has (the shared binds reach them)."""

    def test_the_shortcuts_and_ipc(self):
        shell = (SAT / "shell.qml").read_text()
        have = set(re.findall(r'GlobalShortcut \{(?:\s*id: \w+)?\s*name: "([\w-]+)"', shell))
        self.assertTrue({"launcher", "launcher-tap", "clipboard", "center", "keybinds", "power"} <= have)
        self.assertIn('target: "shell"', shell)
        self.assertIn("function recording(on: bool)", shell)
        self.assertIn('target: "osd"', (SAT / "osd/Osd.qml").read_text())
        for f in ("launcher/Launcher.qml", "keys/KeySheet.qml", "power/Power.qml", "osd/Osd.qml", "osd/Toast.qml"):
            text = (SAT / f).read_text()
            self.assertNotIn("abyss", text.lower(), f)
            self.assertNotIn("Reefs", text, f)

    def test_the_volume_goes_to_150(self):
        self.assertIn("maxVolume: 1.5", (SAT / "services/Audio.qml").read_text())

    @unittest.skipUnless(has_pyside(), "needs PySide6")
    def test_every_surface_opens_clean(self):
        import qs_smoke
        errors, pokes = qs_smoke.smoke(SAT, seconds=7, poke=REPO / "tests/pokes/satsuei-walk.qml")
        self.assertEqual(errors, [])
        self.assertEqual(pokes[-1]["mode"], "dark")


class Center(unittest.TestCase):
    """Step 5: the control centre."""

    def test_the_drawer(self):
        c = (SAT / "center/Center.qml").read_text()
        for needle in ("width: 372", '"satsuei-center"', "radius: 22", "Style.bloom", "duration: win.open ? 550",
                       "drawer.width + 30", "MediaCard {", '"/proc/uptime"', "Shell.togglePower()",
                       "rice-rec", "interval: 350", "Keys.onEscapePressed"):
            self.assertIn(needle.replace("rice-rec", "Shell.toggleRecording("), c)
        # the shared toggles, then Satsuei's own
        titles = re.findall(r'title: "([^"]+)"', c)
        self.assertEqual(titles, ["Wi-Fi", "Bluetooth", "Quiet", "Night light", "Microphone", "Performance", "Caffeine",
                                  "Screenshot", "Compositing", "Mascot", "Timesheet"])
        self.assertIn('title: Shell.recording ? "Recording" : "Record"', c)
        self.assertIn("to: 150", c)                                  # volume to 150%
        self.assertIn("Settings.s.expo", c)                          # brightness feeds the pass's expo
        self.assertIn("NoteList {", c)
        self.assertIn("Notifs.all.slice(-4)", (SAT / "center/NoteList.qml").read_text())

    def test_the_media_card(self):
        m = (SAT / "center/MediaCard.qml").read_text()
        for needle in ("model: Beat.bars", "trackArtUrl", "Media.fmt(", "previous()", "togglePlaying()", "next()",
                       "id: stage", "width: 112", "height: 128", "anchors.bottomMargin: -16", "positionChanged()"):
            self.assertIn(needle, m)

    def test_one_cava_of_its_own(self):
        beat = (SAT / "services/Beat.qml").read_text()
        self.assertIn("readonly property int bars: 30", beat)
        self.assertIn("data_format = ascii", beat)
        self.assertIn("method = raw", beat)
        self.assertIn('/satsuei"', beat)
        self.assertIn("running: Media.playing", beat)
        runs = [f.relative_to(SAT).as_posix() for f in SAT.rglob("*.qml") if "exec cava" in f.read_text()]
        self.assertEqual(runs, ["services/Beat.qml"])

    @unittest.skipUnless(has_pyside(), "needs PySide6")
    def test_it_opens_clean(self):
        import qs_smoke
        errors, pokes = qs_smoke.smoke(SAT, seconds=2.5, poke=REPO / "tests/pokes/satsuei-center.qml")
        self.assertEqual(errors, [])
        self.assertEqual(pokes[0]["open"], True)
        self.assertEqual(pokes[0]["notes"], 2)          # the stand-in server sends two


class Subtitles(unittest.TestCase):
    """Step 6: notifications as subtitles."""

    def test_the_look(self):
        sub = (SAT / "subs/Subtitles.qml").read_text()
        for needle in ('"satsuei-subs"', "anchors { bottom: true }", "margins.bottom: 46", "size: 18",
                       "toUpperCase()", "spacing: 0.2", "Text.Outline", "duration: 450", "duration: 350",
                       "Notifs.lifetime", "Notifs.critical(note)"):
            self.assertIn(needle, sub)
        self.assertIn("readonly property int lifetime: 5200", (SAT / "services/Notifs.qml").read_text())
        self.assertIn("Subtitles {}", (SAT / "shell.qml").read_text())

    @unittest.skipUnless(has_pyside(), "needs PySide6")
    def test_one_at_a_time_and_critical_stays(self):
        import qs_smoke
        errors, pokes = qs_smoke.smoke(SAT, seconds=17, poke=REPO / "tests/pokes/satsuei-subs.qml")
        self.assertEqual(errors, [])
        by = {p["tag"]: p for p in pokes}
        self.assertEqual((by["first"]["queue"], by["first"]["current"]), (2, 1))
        self.assertEqual((by["second"]["queue"], by["second"]["current"]), (1, 2))   # 5.2 s on, the next
        self.assertEqual((by["later"]["queue"], by["later"]["current"]), (1, 2))     # critical: still there
        self.assertEqual(by["later"]["all"], 2)                                      # both kept in the list


class Characters(unittest.TestCase):
    """Step 7: the rig and Hana, dancing on the media card."""

    def test_the_rig_is_the_mocks_pose(self):
        rig = (SAT / "chars/Rig.qml").read_text()
        for needle in ("bo = -Math.abs(Math.sin(b)) * 7 * e;", "ti = Math.sin(b) * 10 * e;", "sw = Math.sin(b) * 4 * e;",
                       "l = 20 + 80 * (0.5 + 0.5 * Math.sin(b)) * e;", "x = Math.sin(b * 2) * 18;",
                       "r = -150 + Math.sin(t * 12) * 22;", "ti = 14;", "ey = 0.08;",
                       "blinkAt = t + 2.5 + Math.random() * 3", "t > blinkAt + 0.13",
                       "phase += dt * (bpm / 60) / 2 * (0.75 + energy * 0.6)", "property int interval: 33", "interval: rig.interval",
                       "running: rig.running && rig.visible"):
            self.assertIn(needle, rig)
        # every motion can be scaled per character
        for k in ("bob", "tilt", "sway", "arms", "legs", "extra", "speed"):
            self.assertIn(f'k("{k}")', rig)

    def test_hana(self):
        hana = (SAT / "chars/Hana.qml").read_text()
        # drawn with Shapes on the 120 × 160 canvas, her clothes the plate's
        self.assertIn("Rig {", hana)
        for needle in ("angle: r.aL", "angle: r.aR", "dy: r.lL", "dy: r.lR", "angle: r.tilt", "sy: r.eyes",
                       "angle: r.ex", "dy: r.bob", "fill: Theme.accent2", "stroke: Theme.accent", "fill: Theme.hair"):
            self.assertIn(needle, hana)
        self.assertIn("preferredRendererType: Shape.CurveRenderer", (SAT / "chars/Blob.qml").read_text())

    def test_the_dancer_stands_on_the_media_card(self):
        center = (SAT / "center/Center.qml").read_text()
        self.assertIn("parent: media.stage", center)
        self.assertIn("running: win.open", center)
        dancer = (SAT / "chars/Dancer.qml").read_text()
        self.assertIn('Media.playing ? "dance" : "idle"', dancer)
        self.assertIn("Theme.at(Theme.ink, 0.25)", dancer)          # the contact shadow
        chars = (SAT / "chars/Characters.qml").read_text()
        self.assertIn('id: "hana"', chars)
        self.assertIn("Settings.s.dancer", chars)
        tempo = (SAT / "services/Tempo.qml").read_text()
        self.assertIn("while (b < 70) b *= 2;", tempo)


    def test_the_cast(self):
        chars = (SAT / "chars/Characters.qml").read_text()
        for c in ("hana", "mochi", "kon", "bit", "yuki"):
            self.assertIn(f'id: "{c}"', chars)
            self.assertTrue((SAT / f"chars/{c.capitalize()}.qml").exists())
        # each dances its own way
        self.assertIn("0.99 + 0.07 * Math.sin(r.beat * 2)", (SAT / "chars/Mochi.qml").read_text())   # squash 0.92-1.06
        self.assertIn("Math.max(0, Math.sin(beat)) * 14", (SAT / "chars/Kon.qml").read_text())       # every other beat
        bit = (SAT / "chars/Bit.qml").read_text()
        self.assertIn("steps: 4", bit)
        self.assertIn("Tempo.kick", bit)
        self.assertIn("Math.cos(phase * Math.PI)", (SAT / "chars/Yuki.qml").read_text())             # a turn in 4 beats
        shell = (SAT / "shell.qml").read_text()
        self.assertIn("function setCharacter(role: string, id: string)", shell)
        self.assertIn("function nextCharacter(role: string)", shell)
        base = (REPO / "hypr/.config/hypr/base.lua").read_text()
        for k, name in (("ALT + SHIFT + C", "satsuei-dancer-next"), ("ALT + M", "satsuei-mascot-next")):
            self.assertRegex(base, rf'key\("{re.escape(k)}"\),\s+hl\.dsp\.global\("quickshell:{name}"\)')
            self.assertIn(f'name: "{name}"', shell)

class Custom(unittest.TestCase):
    """Step 9: the user's own characters, and the strip that casts them."""

    def test_the_folder(self):
        chars = (SAT / "chars/Characters.qml").read_text()
        for needle in ('"/satsuei/characters"', "FolderListModel", "watchChanges: true", '["mkdir", "-p", root.dir]',
                       "baseBpm: 100", "scale: 1", "offsetX: 0", "offsetY: 0", "flip: false", "trimBottom: 0",
                       "puppet: 0.6", "frames: 0", '"thumb.png"', "libwebp_anim", "info.frames > 0",
                       "builtins.concat(customs)", "Settings.s.shuffleDaily", "Settings.s.shuffledOn = today()"):
            self.assertIn(needle, chars)
        # a folder named like a built-in, or with no dance, isn't cast
        self.assertIn("root.builtins.some(c => c.id === id)", chars)
        self.assertIn("entry = clips.dance ?", chars)

    def test_it_plays_like_a_builtin(self):
        c = (SAT / "chars/Custom.qml").read_text()
        self.assertIn("Rig {", c)
        for needle in ("AnimatedImage", "AnimatedSprite", "playing: r.playing", "(clipName !== \"dance\" || Media.playing)",
                       "Math.max(0.6, Math.min(1.6, Tempo.bpm / (meta.baseBpm || 100))) * (0.75 + 0.6 * Math.min(1, Beat.level))",
                       "1 - 0.07 * Tempo.kick * r.puppet", "Tempo.drop", "xScale: r.meta.flip ? -1 : 1",
                       "r.meta.trimBottom", "r.meta.offsetX", "r.meta.offsetY", "0.75 : 1", '"Z" : "z"'):
            self.assertIn(needle, c)
        # one way in for every host
        actor = (SAT / "chars/Actor.qml").read_text()
        self.assertIn("item.cast = Qt.binding(() => root.cast)", actor)
        for f in ("chars/Dancer.qml", "desk/Stats.qml", "center/Strip.qml"):
            self.assertIn("Actor {", (SAT / f).read_text(), f)

    def test_the_strip(self):
        strip = (SAT / "center/Strip.qml").read_text()
        for needle in ("Segmented {", "options: Characters.roles", '"Shuffle daily"', '"+add"', "xdg-open", "Characters.set(root.role",
                       "Characters.all.concat", "running: root.open && !tile.add", "interval: 66"):
            self.assertIn(needle, strip)
        self.assertIn("Strip {", (SAT / "center/Center.qml").read_text())
        install = (REPO / "install").read_text()
        self.assertIn("|qt6-imageformats", install)
        self.assertIn("ffmpeg:ffmpeg", install)

    def test_every_shader_is_there(self):
        for f in SAT.rglob("*.qml"):
            for url in re.findall(r'resolvedUrl\("([^"]+\.qsb)"\)', f.read_text()):
                self.assertTrue((f.parent / url).resolve().exists(), f"{f.relative_to(SAT)}: {url}")

    @unittest.skipUnless(has_pyside(), "needs PySide6")
    def test_a_gif_takes_the_stage(self):
        import qs_smoke
        folder = STUB_HOME / ".config/satsuei/characters"
        shutil.rmtree(folder / "test", ignore_errors=True)
        folder.mkdir(parents=True, exist_ok=True)
        shutil.copytree(REPO / "tests/fixtures/satsuei-char/test", folder / "test")
        try:
            errors, pokes = qs_smoke.smoke(SAT, seconds=4.5, poke=REPO / "tests/pokes/satsuei-cast.qml")
        finally:
            shutil.rmtree(folder / "test", ignore_errors=True)
        self.assertEqual(errors, [])
        found, cast = pokes[0], pokes[1]
        self.assertEqual(found["ids"], ["hana", "mochi", "kon", "bit", "yuki", "test"])
        t = found["test"]
        self.assertEqual((t["name"], t["ja"], t["file"]), ("Testy", "テスト", "Custom.qml"))
        self.assertEqual(t["meta"]["baseBpm"], 110)
        self.assertEqual(t["meta"]["puppet"], 0.6)            # a default filled in
        self.assertTrue(t["clips"]["dance"]["path"].endswith("/test/dance.gif"))
        self.assertEqual((cast["dancer"], cast["mascot"], cast["open"]), ("test", "bit", True))


class SceneMatch(unittest.TestCase):
    """Step 11: a custom character drawn into the plate's light."""

    def test_the_shader(self):
        frag = (SAT / "shaders/scenematch.frag").read_text()
        for needle in ("vec3 oklab(", "smoothstep(t * 0.5, t, d)", "near(lab, prot0)", "mul.rgb + lift.rgb", "* expo",
                       "lightDir * texel * 2.5", "texel * 1.5", "hash(", "s.rgb / a"):
            self.assertIn(needle, frag)
        qsb = SAT / "shaders/scenematch.frag.qsb"
        self.assertGreaterEqual(qsb.stat().st_mtime, (SAT / "shaders/scenematch.frag").stat().st_mtime - 1, "run tools/shaders")
        custom = (SAT / "chars/Custom.qml").read_text()
        for needle in ("layer.effect: SceneMatch", "meta.match ?? true", "meta.recolor ?? []", "r.meta.protect",
                       "r.meta.ambient ?? 0.7", "r.meta.rim ?? 0.5", "Theme.grade.rays", "Theme.grade.rayCol",
                       "Theme.at(Theme.tint, 0.6)", "Settings.s.grain", "r.tokens.includes(x.to) ? Theme[x.to] : x.to"):
            self.assertIn(needle, custom)

    @unittest.skipUnless(has_pyside(), "needs PySide6")
    def test_it_follows_three_wallpapers_and_keeps_what_is_protected(self):
        """The fixture's teal head is recoloured to three different accents, each
        time to that accent's hue; its pink body, protected, never moves."""
        for accent in ("#ff8e7a", "#b280f9", "#7ad0ff"):
            p = subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 640x480x24", sys.executable,
                                str(REPO / "tests/scenematch_probe.py"), accent],
                               capture_output=True, text=True, timeout=120,
                               env={**os.environ, "QSG_RHI_BACKEND": "opengl"})
            got = json.loads(p.stdout.strip().splitlines()[-1])
            self.assertLess(rw.hue_dist(rw.hsl(got["head"])[0], rw.hsl(accent)[0]), 8, (accent, got))
            self.assertEqual(got["body"], "#e12885", accent)


class Lock(unittest.TestCase):
    """Step 17: the lock screen, an episode's title card."""

    def test_the_card(self):
        lock = (SAT / "lock/Lock.qml").read_text()
        for needle in ("WlSessionLock", "PamContext", 'config: "login"', 'target: "lock"', "function lock(): void",
                       "/rices/satsuei/lock-titles.json", "titles[(day - 1) % titles.length]", "new Date(2000, d.getMonth(), d.getDate())", "Shell.locked = true", "Shell.locked = false"):
            self.assertIn(needle, lock)
        self.assertNotIn('property: "locked"', lock)
        surf = (SAT / "lock/LockSurface.qml").read_text()
        for needle in ("Pass {", "pass: Settings.s.pass ? 1 : 0", "Settings.s.pass && Settings.s.grade ? 1 : 0", "rays: 0", "blurEnabled: true", "Theme.at(Theme.ink, 0.7)", "第${root.ep.n}話 · EPISODE ${root.ep.n}",
                       "display: true", "root.ep.ja", "root.ep.en", '"HH:mm"', '"dddd, d MMMM"', "Glass {", "radius: 24",
                       "echoMode: TextInput.Password", '"Press Enter to unlock"', "root.lock.submit()", "Theme.accent"):
            self.assertIn(needle, surf)
        titles = json.loads((RICE / "lock-titles.json").read_text())
        # one for each date of a leap year, in order, none twice
        self.assertEqual(len(titles), 366)
        for t in titles:
            self.assertTrue(isinstance(t, list) and len(t) == 2 and all(isinstance(x, str) and x.strip() for x in t), t)
        for i in (0, 1):
            names = [t[i] for t in titles]
            self.assertEqual(len(set(names)), len(names), [n for n in names if names.count(n) > 1])
        day = lambda m, d: (date(2000, m, d) - date(2000, 1, 1)).days
        self.assertEqual(titles[day(1, 1)][0], "初日の出")
        self.assertEqual(titles[day(7, 7)][0], "七夕")
        self.assertEqual(titles[day(12, 31)][0], "大晦日")
        self.assertIn("Lock {}", (SAT / "shell.qml").read_text())

    @unittest.skipUnless(has_pyside(), "needs PySide6")
    def test_it_locks_and_unlocks(self):
        import qs_smoke
        with tempfile.TemporaryDirectory() as d:
            shell = Path(d) / "satsuei"
            shutil.copytree(SAT, shell)
            lock = shell / "lock/Lock.qml"
            hook = "        function isLocked(): bool {"
            text = lock.read_text()
            self.assertIn(hook, text)
            lock.write_text(text.replace(hook, "        function testUnlock(p: string): void { root.password = p; root.submit(); }\n" + hook))
            found, pokes = qs_smoke.smoke(shell, 5.5, REPO / "tests/pokes/satsuei-unlock.qml")
        self.assertEqual(found, [])
        by = {p["tag"]: p for p in pokes}
        self.assertEqual(set(by), {"before", "locked", "wrong", "after"}, pokes)
        self.assertTrue(by["locked"]["locked"])
        self.assertTrue(all(s == "paused: locked" for s in by["locked"]["plates"]))
        self.assertTrue(by["wrong"]["locked"])
        self.assertFalse(by["after"]["locked"])
        self.assertFalse(any(s == "paused: locked" for s in by["after"]["plates"]))


class Integration(unittest.TestCase):
    """Steps 18 and 19: the chooser, the switch, the docs; and the bar's battery."""

    def test_the_chooser_and_the_switch(self):
        card = (RICE / "card.qml").read_text()
        for needle in ("property url base", "/satsuei/theme.json", "watchChanges: true", '"撮"', "root.selected"):
            self.assertIn(needle, card)
        self.assertTrue((RICE / "preview.png").is_file())
        frag = RICE / "transition.frag"
        self.assertIn("light leak", frag.read_text())
        qsb = RICE / "transition.frag.qsb"
        self.assertGreaterEqual(qsb.stat().st_mtime, frag.stat().st_mtime - 1, "run tools/shaders")
        palette = tomllib.loads((RICE / "palette.toml").read_text())
        self.assertEqual(palette["meta"]["transition"], "leak")
        self.assertEqual(palette["meta"]["lock"], "shell")

    def test_the_battery_is_a_strip_of_film(self):
        reel = (SAT / "bar/Reel.qml").read_text()
        for needle in ("readonly property int frames: 4", "root.level * film.frames - index", "Battery.charging",
                       "Battery.low", "Battery.timeLeft", "HoverHandler"):
            self.assertIn(needle, reel)
        self.assertIn("Reel {", (SAT / "bar/Status.qml").read_text())

    def test_the_docs(self):
        doc = (REPO / "docs/satsuei/README.md").read_text()
        for needle in ("~/Pictures/Wallpapers", "~/.config/satsuei/characters/", "meta.json", "recolor", "protect",
                       "qs -c satsuei ipc call satsuei wallpaper", "setCharacter", "lock-titles.json", "Super+Ctrl+W"):
            self.assertIn(needle, doc)
        readme = (REPO / "README.md").read_text()
        self.assertIn("Four rices ship today", readme)
        self.assertIn("| **Satsuei** |", readme)


class CastPicker(unittest.TestCase):
    """Step 12: the Cast picker, slimmed (no tweak drawer)."""

    def test_the_picker(self):
        cast = (SAT / "cast/Cast.qml").read_text()
        for needle in ('"satsuei-cast"', "WlrLayer.Overlay", "WlrKeyboardFocus.Exclusive", '"キャスト"', "Segmented {",
                       "GridView", "Characters.all", "Actor {", '"dance" : "idle"', '"built-in" : "custom"',
                       "Characters.states", "Qt.Key_Tab", "Qt.Key_Return", "Qt.Key_Escape", "Characters.set(role, c.id)",
                       "zenity --file-selection", 'cp "$f" "$dir/dance.$ext"', "xdg-open"):
            self.assertIn(needle, cast)
        self.assertIn('{ value: "dancer", text: "Dancer" }, { value: "mascot", text: "Edge mascot" }',
                      (SAT / "chars/Characters.qml").read_text())
        shell = (SAT / "shell.qml").read_text()
        for needle in ("Cast {}", 'name: "satsuei-cast"', "function cast(role: string)"):
            self.assertIn(needle, shell)
        base = (REPO / "hypr/.config/hypr/base.lua").read_text()
        self.assertRegex(base, r'key\("ALT \+ C"\),\s+hl\.dsp\.global\("quickshell:satsuei-cast"\)')

    @unittest.skipUnless(has_pyside(), "needs PySide6")
    def test_it_opens_clean(self):
        import qs_smoke
        errors, pokes = qs_smoke.smoke(SAT, seconds=3.5, poke=REPO / "tests/pokes/satsuei-picker.qml")
        self.assertEqual(errors, [])
        self.assertEqual((pokes[0]["open"], pokes[0]["role"]), (True, "mascot"))
        self.assertEqual((pokes[1]["open"], pokes[1]["mascot"]), (False, "kon"))


class Mascot(unittest.TestCase):
    """Step 13: the edge mascot."""

    def test_the_mascot(self):
        m = (SAT / "mascot/Mascot.qml").read_text()
        for needle in ('"satsuei-mascot"', "anchors { bottom: true; right: true }", "* 0.08", "mask: Region { item: head }",
                       "cast: Characters.mascot", "IdleMonitor", "timeout: 40", "interval: 4200", "function onArrived(n)",
                       "!waving ? 114 :", "waving ? 34", "!shown ? 170", "Settings.s.mascot", "Hypr.fullscreenOn(monitor)",
                       '"z z Z"', "hopping.restart()", "[0.3, 1.5, 0.5, 1, 1, 1]"):
            self.assertIn(needle.replace("!waving ? 114 :", "114"), m)
        self.assertIn("Mascot {}", (SAT / "shell.qml").read_text())


class Walls(unittest.TestCase):
    """Steps 14 and 15: the wallpaper folder, and the selector."""

    def test_the_library(self):
        lib = (SAT / "walls/Library.qml").read_text()
        for needle in ('"satsuei-wall", "scan"', "inotifywait -mrq", "Settings.s.wallDir", "Settings.s.sort", "Settings.s.rotate",
                       '"15m": 15, "30m": 30, "1h": 60', '"daily"', '"satsuei-wall", "set", path', "Theme.endPreview()",
                       "function step(by)", "function random()", "function previewTokens(w)"):
            self.assertIn(needle, lib)

    def test_the_selector(self):
        sel = (SAT / "walls/Selector.qml").read_text()
        for needle in ('"satsuei-walls"', "WlrKeyboardFocus.Exclusive", "interval: 250", "Theme.preview(Library.previewTokens(",
                       "Library.apply(focused.path)", "Theme.endPreview()", "Qt.Key_Slash", "Qt.Key_Escape", "scale: card.lit ? 1.15 : 1",
                       "Shimmer", '"wl-copy"', "lightX", '"Name"', '"Date added"', '"Colour"', '"Daily"', '"Shuffle"', '"Open folder"',
                       '"Change folder…"', "--directory", "Actor {"):
            self.assertIn(needle, sel)
        # the scan renews the list a few times a second: you stay on your picture
        # (by its path), and the strip's reset to its first card isn't followed
        self.assertIn("function focusOn(i)", sel)
        self.assertIn("Library.indexOf(focusedPath)", sel)
        self.assertNotIn("onCurrentIndexChanged", sel)
        self.assertIn("strip.currentIndex = current;", sel)              # it follows every move
        self.assertNotIn("currentIndex: win.current", sel)
        self.assertIn("Timer { id: flush; interval: 300", (SAT / "walls/Library.qml").read_text())
        shell = (SAT / "shell.qml").read_text()
        for needle in ("Selector {}", 'name: "satsuei-walls"', "function wallpaper(action: string)", "function setWallpaper(path: string)"):
            self.assertIn(needle, shell)
        base = (REPO / "hypr/.config/hypr/base.lua").read_text()
        self.assertRegex(base, r'key\("CTRL \+ W"\),\s+hl\.dsp\.global\("quickshell:satsuei-walls"\)')


class Studio(unittest.TestCase):
    """Step 16: the Satsuei panel."""

    def test_the_panel(self):
        st = (SAT / "panel/Studio.qml").read_text()
        for needle in ('"satsuei-studio"', "width: 340", '"撮影"', '"SATSUEI"', '"Diffusion bloom"', '"Light rays"', '"Dust motes"',
                       '"Film grain"', '"Time-of-day grade"', "Settings.setFx(", "Theme.grade.phase", "Theme.grade.fmt(", "to: 24",
                       '"Follow the clock"', '"Choose wallpaper…"', "Shell.toggleWalls()", '"accent 2"', '"glass"', "Theme.swatches",
                       '"Pick on wallpaper"', "Shell.pickingLight = true", "Plates.pick(", '"Hold to compare"',
                       "Shell.comparing = true", "Shell.comparing = false"):
            self.assertIn(needle, st)
        self.assertIn("function pickAt(px, py)", (SAT / "plate/Plate.qml").read_text())
        self.assertIn("Studio {}", (SAT / "shell.qml").read_text())

    @unittest.skipUnless(has_pyside(), "needs PySide6")
    def test_mascot_walls_and_panel_open_clean(self):
        import qs_smoke
        errors, pokes = qs_smoke.smoke(SAT, seconds=6.5, poke=REPO / "tests/pokes/satsuei-desk.qml")
        self.assertEqual([e for e in errors if "Cannot open: file:///w/" not in e], [])
        walls, studio = pokes
        self.assertEqual((walls["open"], walls["shown"], walls["folders"]), (True, 2, ["b"]))
        self.assertEqual((studio["open"], studio["grain"], studio["previewing"]), (False, True, False))


class Desk(unittest.TestCase):
    """The system card every shell has, as Satsuei's timesheet."""

    def test_the_timesheet(self):
        st = (SAT / "desk/Stats.qml").read_text()
        # the shared contract: under the windows, draggable, remembered, put away by right-click
        for needle in ("WlrLayer.Bottom", '"satsuei-stats"', "mask: Region { item: card }", "DragHandler",
                       "Shell.setStatsAt(", "Shell.statsAt.x", "Shell.setStatsShown(false)", "Qt.RightButton",
                       "!Hypr.fullscreenOn(monitor)", "Sys.cpu", "Sys.mem", "Sys.disk"):
            self.assertIn(needle, st)
        # its own flavour: CUT, ten frames, three columns, a playhead stepping once a second
        for needle in ('"CUT "', '"タイムシート"', "model: 10", '"CPU"', '"MEM"', '"DSK"', "interval: 1000",
                       "(win.frame + 1) % 10", "color: Theme.urgent"):
            self.assertIn(needle, st)
        # the little dancer: slow ticks, still while covered, fanning when hot
        for needle in ("interval: 66", 'win.hot ? "wave" : "idle"', "!win.covered", "v < 0.7 : v > 0.8",
                       "win.streak >= 3"):
            self.assertIn(needle, st)
        shell = (SAT / "services/Shell.qml").read_text()
        for needle in ("readonly property bool statsShown", "readonly property point statsAt",
                       "function setStatsShown(on)", "function setStatsAt(x, y)"):
            self.assertIn(needle, shell)
        settings = (SAT / "common/Settings.qml").read_text()
        for needle in ("property bool statsShown: true", "property real statsX: 1", "property real statsY: 0"):
            self.assertIn(needle, settings)
        center = (SAT / "center/Center.qml").read_text()
        self.assertIn('title: "Timesheet"', center)
        self.assertIn("Shell.setStatsShown(!Shell.statsShown)", center)
        self.assertIn("Stats {}", (SAT / "shell.qml").read_text())

if __name__ == "__main__":
    unittest.main()