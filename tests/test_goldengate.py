"""Golden Gate: macOS 27 on Hyprland (docs/goldengate/PLAN.md).

What it must keep:
  · gg-theme saves the user's GTK, Qt, Kvantum, icon and cursor settings
    once, applies MacTahoe in the mode and accent, and puts every one back
  · the accents are Apple's, and `gg accent` reaches the apps through the
    palette overlay without touching the committed Theme.qml
  · GTK 4 (libadwaita) gets MacTahoe's sheet; GTK 3 keeps the theme's own
"""

import importlib.machinery
import importlib.util
import json
import os
import shutil
import stat
import subprocess
import tempfile
import unittest
import unittest.mock
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GG = REPO / "switcher/.local/bin/gg"
GG_THEME = REPO / "switcher/.local/bin/gg-theme"
RICES = REPO / "rices/.config/rices"
RICE = RICES / "goldengate"
SHELL = REPO / "quickshell/.config/quickshell/goldengate"
TEMPLATES = REPO / "render/.local/share/rice/templates"

loader = importlib.machinery.SourceFileLoader("rice_render_gg", str(REPO / "render/.local/bin/rice-render"))
spec = importlib.util.spec_from_loader("rice_render_gg", loader)
rr = importlib.util.module_from_spec(spec)
loader.exec_module(rr)

# Apple's system accents, light and dark (the brief's numbers)
APPLE = {
    "blue": ("#007aff", "#0a84ff"), "purple": ("#af52de", "#bf5af2"), "pink": ("#ff2d55", "#ff375f"),
    "red": ("#ff3b30", "#ff453a"), "orange": ("#ff9500", "#ff9f0a"), "yellow": ("#ffcc00", "#ffd60a"),
    "green": ("#28cd41", "#32d74b"), "graphite": ("#8e8e93", "#98989d"),
}

# a gsettings that keeps its values in files, one per key
GSETTINGS = r"""#!/bin/sh
d="$GG_TEST_GSETTINGS"
case "$1" in
    get) cat "$d/$3" 2>/dev/null || echo "''" ;;
    set) printf '%s\n' "$4" > "$d/$3" ;;
esac
"""


@unittest.skipUnless(shutil.which("jq"), "jq not installed")
class Theme(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.home = root
        bin_ = root / "bin"
        bin_.mkdir()
        gs = bin_ / "gsettings"
        gs.write_text(GSETTINGS)
        gs.chmod(gs.stat().st_mode | stat.S_IXUSR)
        self.gs = root / "gsettings"
        self.gs.mkdir()
        for key, value in {
            "gtk-theme": "'adw-gtk3-dark'", "icon-theme": "'Colloid-Dark'",
            "cursor-theme": "'Bibata-Modern-Ice'", "cursor-size": "24",
            "color-scheme": "'prefer-dark'", "accent-color": "'teal'",
            "font-name": "'Manrope Medium 14'", "document-font-name": "'Manrope Medium 14'",
            "monospace-font-name": "'JetBrains Mono Medium 15'",
        }.items():
            (self.gs / key).write_text(value + "\n")
        self.conf = root / "config"
        qt = self.conf / "qt6ct/qt6ct.conf"
        qt.parent.mkdir(parents=True)
        qt.write_text("[Appearance]\nstyle=Fusion\ncustom_palette=true\n\n[Fonts]\ngeneral=x\n")
        kv = self.conf / "Kvantum"
        (kv / "MacTahoe").mkdir(parents=True)
        for name in ("MacTahoe", "MacTahoeDark"):
            (kv / "MacTahoe" / f"{name}.kvconfig").write_text("[GeneralColors]\nhighlight.color=#3484e2\n")
            (kv / "MacTahoe" / f"{name}.svg").write_text('<rect fill="#0860F2"/>\n')
        (kv / "kvantum.kvconfig").write_text("[General]\ntheme=MaterialAdw\n")
        self.env = {
            "PATH": f"{bin_}:/usr/bin:/bin",
            "HOME": str(root),
            "XDG_CONFIG_HOME": str(self.conf),
            "XDG_STATE_HOME": str(root / "state"),
            "XDG_DATA_HOME": str(root / "data"),
            "GG_TEST_GSETTINGS": str(self.gs),
        }

    def tearDown(self):
        self.tmp.cleanup()

    def gg(self, *args):
        r = subprocess.run([str(GG_THEME), *args], env=self.env, capture_output=True, text=True, timeout=30)
        self.assertEqual(r.returncode, 0, r.stderr)
        return r

    def snapshot(self):
        files = [self.conf / "qt6ct/qt6ct.conf", self.conf / "Kvantum/kvantum.kvconfig"]
        return ({p.name: p.read_text() for p in self.gs.iterdir()},
                {p.name: p.read_text() for p in files})

    def test_apply_then_restore_leaves_no_trace(self):
        before = self.snapshot()
        self.gg("save")
        self.gg("apply", "dark", "purple")
        self.assertEqual((self.gs / "gtk-theme").read_text().strip(), "MacTahoe-Dark-purple")
        self.assertEqual((self.gs / "cursor-theme").read_text().strip(), "macOS")
        self.assertEqual((self.gs / "accent-color").read_text().strip(), "purple")
        qt = (self.conf / "qt6ct/qt6ct.conf").read_text()
        self.assertIn("style=kvantum", qt)
        self.assertIn("theme=GoldenGateDark", (self.conf / "Kvantum/kvantum.kvconfig").read_text())
        # MacTahoe's blue became the accent in the Kvantum copy
        svg = (self.conf / "Kvantum/GoldenGateDark/GoldenGateDark.svg").read_text()
        self.assertIn("#bf5af2", svg)
        self.assertNotIn("0860", svg.lower())
        self.gg("restore")
        self.assertEqual(self.snapshot(), before)
        self.assertFalse((self.home / "state/goldengate/restore.json").exists())

    def test_a_second_save_keeps_the_first(self):
        self.gg("save")
        self.gg("apply", "light", "blue")
        self.gg("save")          # a re-entered Golden Gate must not save its own look
        saved = json.loads((self.home / "state/goldengate/restore.json").read_text())
        self.assertEqual(saved["gsettings"]["gtk-theme"], "'adw-gtk3-dark'")
        self.assertEqual(saved["qt6ct"]["style"], "Fusion")

    def test_names(self):
        names = lambda m, a: json.loads(self.gg("names", m, a).stdout)
        self.assertEqual(names("light", "graphite")["gtk"], "MacTahoe-Light-grey")
        self.assertEqual(names("light", "graphite")["gnome"], "slate")
        self.assertEqual(names("dark", "multicolor")["gtk"], "MacTahoe-Dark")
        self.assertEqual(names("dark", "blue")["hex"], "#0a84ff")
        self.assertEqual(names("light", "blue")["hex"], "#007aff")
        self.assertTrue(names("dark", "blue")["icons"].endswith("-dark"))

    def test_restore_without_a_save_changes_nothing(self):
        before = self.snapshot()
        self.gg("restore")
        self.assertEqual(self.snapshot(), before)


class Palette(unittest.TestCase):
    def setUp(self):
        # the user's own overlay (their accent) mustn't decide these
        self.saved = os.environ.get("XDG_STATE_HOME")
        self.tmp = tempfile.TemporaryDirectory()
        os.environ["XDG_STATE_HOME"] = self.tmp.name

    def tearDown(self):
        if self.saved is None:
            os.environ.pop("XDG_STATE_HOME", None)
        else:
            os.environ["XDG_STATE_HOME"] = self.saved
        self.tmp.cleanup()

    def test_the_accents_are_apples(self):
        ctxs = rr.load_modes(RICE)
        for name, (light, dark) in APPLE.items():
            with self.subTest(name):
                self.assertEqual(ctxs["light"]["colors"][name], light)
                self.assertEqual(ctxs["dark"]["colors"][name], dark)
        # gg-theme (Kvantum's accent) says the same
        for name, (light, dark) in APPLE.items():
            for mode, want in (("light", light), ("dark", dark)):
                out = subprocess.run([str(GG_THEME), "names", mode, name], capture_output=True, text=True,
                                     env={**os.environ, "XDG_DATA_HOME": self.tmp.name})
                self.assertEqual(json.loads(out.stdout)["hex"], want, f"{name} {mode}")

    def test_the_labels_are_black_and_white_at_apples_alphas(self):
        theme = (SHELL / "common/Theme.qml").read_text()
        for alpha in ("0.85", "0.5", "0.25", "0.1"):
            self.assertIn(f'Qt.alpha(c("ink"), contrast ? ', theme)
            self.assertIn(f": {alpha})", theme)
        ctxs = rr.load_modes(RICE)
        self.assertEqual(ctxs["light"]["colors"]["ink"], "#000000")
        self.assertEqual(ctxs["dark"]["colors"]["ink"], "#ffffff")

    def test_the_theme_never_reads_what_the_overlay_writes(self):
        # the overlay sets roles, opacity and meta; the installed Theme.qml is
        # committed, so it must render the same whatever accent is chosen
        tpl = (RICE / "templates/quickshell/Theme.qml").read_text()
        for written in ("roles.", "opacity.", "meta.", "gtk."):
            self.assertNotIn(f"light.{written}", tpl)
            self.assertNotIn(f"dark.{written}", tpl)
        self.assertIn("Settings.appearance.accent", tpl)

    def test_gtk4_gets_mactahoes_libadwaita_sheet(self):
        self.assertIn((".config/gtk-4.0/gtk.css", "gtk/gtk4.css"), rr.LINKS)
        self.assertIn((".config/gtk-3.0/gtk.css", "gtk/gtk.css"), rr.LINKS)
        ctxs = rr.load_modes(RICE)
        with unittest.mock.patch.object(rr, "SHARED", TEMPLATES):
            for mode, theme in (("light", "MacTahoe-Light-blue"), ("dark", "MacTahoe-Dark-blue")):
                files = rr.template_files(RICE, mode)
                css = rr.render_text(files["gtk/gtk4.css"].read_text(), ctxs[mode], "gtk4.css")
                self.assertIn(f"/.local/share/themes/{theme}/gtk-4.0/gtk.css", css)
                gtk3 = rr.render_text(files["gtk/gtk.css"].read_text(), ctxs[mode], "gtk.css")
                self.assertNotIn("@import", gtk3)
            # every other rice: GTK 4 reads the same colours as GTK 3
            paper = rr.load_modes(RICES / "paper")["light"]
            files = rr.template_files(RICES / "paper", "light")
            css = rr.render_text(files["gtk/gtk4.css"].read_text(), paper, "gtk4.css")
            self.assertIn("/paper/build/light/gtk/gtk.css", css)

    def test_one_cursor_the_apple_one(self):
        ctxs = rr.load_modes(RICE)
        self.assertEqual(ctxs["light"]["gtk"]["cursor"], "macOS")
        self.assertEqual(ctxs["dark"]["gtk"]["cursor"], "macOS")


@unittest.skipUnless(shutil.which("jq"), "jq not installed")
class Accent(unittest.TestCase):
    """gg accent: settings.json for the shell, the overlay for the apps."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.rices = root / "rices"
        shutil.copytree(RICES, self.rices, ignore=shutil.ignore_patterns("build", "current"))
        (self.rices / "current").symlink_to("paper")          # Golden Gate isn't on screen
        bin_ = root / "bin"
        bin_.mkdir()
        for name, target in (("rice-render", REPO / "render/.local/bin/rice-render"), ("gg-theme", GG_THEME)):
            (bin_ / name).symlink_to(target)
        self.env = {
            "PATH": f"{bin_}:/usr/bin:/bin", "HOME": str(root), "RICE_DIR": str(self.rices),
            "RICE_TEMPLATES": str(TEMPLATES), "RICE_INSTALL_ROOT": str(root / "install"),
            "XDG_CONFIG_HOME": str(root / "config"), "XDG_STATE_HOME": str(root / "state"),
            "XDG_DATA_HOME": str(root / "data"),
        }
        self.root = root

    def tearDown(self):
        self.tmp.cleanup()

    def gg(self, *args):
        r = subprocess.run([str(GG), *args], env=self.env, capture_output=True, text=True, timeout=60)
        self.assertEqual(r.returncode, 0, r.stderr)
        return r

    def settings(self):
        return json.loads((self.root / "config/goldengate/settings.json").read_text())

    def test_an_accent_reaches_the_apps(self):
        self.gg("accent", "purple")
        self.assertEqual(self.settings()["appearance"]["accent"], "purple")
        overlay = (self.root / "state/goldengate/palette.toml").read_text()
        self.assertIn('gtk_theme  = "MacTahoe-Light-purple"', overlay)
        self.assertIn('gtk_theme  = "MacTahoe-Dark-purple"', overlay)
        self.assertIn('accent = "purple"', overlay)
        for mode, hexa in (("light", "#af52de"), ("dark", "#bf5af2")):
            kitty = (self.rices / f"goldengate/build/{mode}/kitty-colors.conf").read_text()
            self.assertIn(f"cursor                {hexa}", kitty)
            meta = json.loads((self.rices / f"goldengate/build/{mode}/meta.json").read_text())
            self.assertEqual(meta["roles"]["accent"], hexa)
        # graphite is MacTahoe's grey; multicolor is blue for the system
        self.gg("accent", "graphite")
        self.assertIn('gtk_theme  = "MacTahoe-Light-grey"', (self.root / "state/goldengate/palette.toml").read_text())
        self.gg("accent", "multicolor")
        overlay = (self.root / "state/goldengate/palette.toml").read_text()
        self.assertIn('gtk_theme  = "MacTahoe-Light"', overlay)
        self.assertIn('accent = "blue"', overlay)

    def test_the_committed_theme_doesnt_change(self):
        before = (SHELL / "common/Theme.qml").read_bytes()
        self.gg("accent", "orange")
        self.assertEqual((self.root / "install/.config/quickshell/goldengate/common/Theme.qml").read_bytes(), before)

    def test_clarity_reaches_the_terminal(self):
        self.gg("set", "glass.clarity", "0")
        self.assertIn("terminal = 0.70", (self.root / "state/goldengate/palette.toml").read_text())
        self.gg("set", "glass.clarity", "1")
        self.assertIn("terminal = 0.97", (self.root / "state/goldengate/palette.toml").read_text())
        self.assertIn("background_opacity    0.97",
                      (self.rices / "goldengate/build/light/kitty.conf").read_text())

    @unittest.skipUnless(shutil.which("magick"), "ImageMagick not installed")
    def test_the_wallpaper_accent_snaps_to_an_apple_hue(self):
        pic = self.root / "walls/teal-light.png"
        pic.parent.mkdir()
        # mostly grey, with a field of a vivid green-teal: the grey says nothing
        subprocess.run(["magick", "-size", "200x100", "xc:#7a7a7a", "-fill", "#13c49a",
                        "-draw", "rectangle 0,0 120,100", str(pic)], check=True)
        self.gg("set", "wallpaper.dir", json.dumps(str(pic.parent)))
        self.gg("wall", "set", str(pic))
        self.gg("accent", "wallpaper")
        a = self.settings()["appearance"]
        self.assertEqual(a["accent"], "wallpaper")
        self.assertEqual(a["accentBase"], "green")
        overlay = (self.root / "state/goldengate/palette.toml").read_text()
        self.assertIn(f'accent = "{a["accentWall"]["light"]}"', overlay)
        self.assertIn('gtk_theme  = "MacTahoe-Light-green"', overlay)

    def test_a_pair_of_pictures_is_one_wallpaper(self):
        walls = self.root / "walls"
        walls.mkdir()
        for name in ("bay-light.png", "bay-dark.png", "fog.png"):
            subprocess.run(["cp", str(RICES / "paper/assets/wall.png"), str(walls / name)], check=True)
        self.gg("set", "wallpaper.dir", json.dumps(str(walls)))
        self.gg("wall", "set", str(walls / "bay-dark.png"))
        w = self.settings()["wallpaper"]
        self.assertEqual(w["current"], str(walls / "bay-light.png"))
        self.assertEqual(w["currentDark"], str(walls / "bay-dark.png"))
        self.gg("wall", "next")
        self.assertEqual(self.settings()["wallpaper"]["current"], str(walls / "fog.png"))
        self.assertEqual(self.settings()["wallpaper"]["currentDark"], "")
        self.gg("wall", "next")          # the pair is one stop
        self.assertEqual(self.settings()["wallpaper"]["current"], str(walls / "bay-light.png"))


if __name__ == "__main__":
    unittest.main()
