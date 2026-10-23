"""Golden Gate: macOS 27 on Hyprland (docs/goldengate/PLAN.md).

What it must keep so that leaving it leaves no trace:
  · gg-theme saves the user's GTK, Qt, Kvantum, icon and cursor settings
    once, applies MacTahoe in the mode and accent, and puts every one back
"""

import json
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GG_THEME = REPO / "switcher/.local/bin/gg-theme"

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


if __name__ == "__main__":
    unittest.main()
