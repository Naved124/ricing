"""Tests for rice-render. Run from the repo root: python3 -m unittest discover tests"""

import importlib.machinery
import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCRIPT = REPO / "render/.local/bin/rice-render"
TEMPLATES = REPO / "render/.local/share/rice/templates"
RICES = REPO / "rices/.config/rices"

loader = importlib.machinery.SourceFileLoader("rice_render", str(SCRIPT))
spec = importlib.util.spec_from_loader("rice_render", loader)
rr = importlib.util.module_from_spec(spec)
loader.exec_module(rr)


def ctx_for(name: str) -> dict:
    return rr.load_palette(RICES / name)


class Filters(unittest.TestCase):
    def setUp(self):
        self.ctx = ctx_for("nacre")

    def r(self, text: str) -> str:
        return rr.render_text(text, self.ctx, "test")

    def test_plain_lookup(self):
        self.assertEqual(self.r("{{ colors.pearl }}"), "#f4f1f6")
        self.assertEqual(self.r("{{roles.fg}}"), "#3b3548")  # role resolved by name

    def test_colour_formats(self):
        self.assertEqual(self.r("{{ colors.ink | nohash }}"), "3b3548")
        self.assertEqual(self.r("{{ colors.ink | rgb }}"), "59, 53, 72")
        self.assertEqual(self.r("{{ colors.ink | rgba(0.5) }}"), "rgba(59, 53, 72, 0.5)")
        self.assertEqual(self.r("{{ colors.lilac | hypr(55) }}"), "rgba(c9bfd855)")
        self.assertEqual(self.r("{{ colors.ink | alpha(0.88) }}"), "#3b3548e0")
        self.assertEqual(self.r("{{ colors.ink | argb(ff) }}"), "#ff3b3548")

    def test_arguments_can_name_palette_values(self):
        self.assertEqual(self.r("{{ roles.bg | argb(opacity.glass) }}"), "#b8f4f1f6")
        self.assertEqual(self.r("{{ colors.pearl | mix(colors.ink, 1) }}"), "#3b3548")

    def test_mix_lighten_darken(self):
        self.assertEqual(self.r("{{ colors.ink | mix(#ffffff, 0) }}"), "#3b3548")
        self.assertEqual(self.r("{{ colors.ink | lighten(1) }}"), "#ffffff")
        self.assertEqual(self.r("{{ colors.ink | darken(1) }}"), "#000000")

    def test_lists_map_then_join(self):
        self.assertEqual(
            self.r('{{ gradient.stops | hypr(ee) | join(" ") }}'),
            "rgba(f2c3d6ee) rgba(c3dff3ee) rgba(cdeedbee) rgba(f3e2b0ee) rgba(dcc6f2ee)",
        )
        self.assertEqual(
            self.r("{{ gradient.stops | closed | len }}"), "6"
        )
        self.assertEqual(self.r("{{ gradient.stops | closed | last }}"), "#f2c3d6")

    def test_quoted_separator_keeps_spaces(self):
        self.assertEqual(self.r('{{ gradient.stops | first | quote }}'), '"#f2c3d6"')
        self.assertEqual(self.r("{{ motion.bloom | join(' , ') }}"), "0.2 , 0.9 , 0.2 , 1")

    def test_numbers(self):
        self.assertEqual(self.r("{{ fonts.mono_size }}"), "12.5")
        self.assertEqual(self.r("{{ motion.bloom | curve }}"), "[0.2, 0.9, 0.2, 1, 1, 1]")
        self.assertEqual(self.r("{{ motion.border_loop | div(100) }}"), "600")
        self.assertEqual(self.r("{{ derived.is_light | bool }}"), "true")

    def test_non_tags_are_left_alone(self):
        lua = "points = { {0.2, 0.9}, {0.2, 1} }"
        self.assertEqual(self.r(lua), lua)
        self.assertEqual(self.r("{{0.2, 1}}"), "{{0.2, 1}}")

    def test_errors_name_file_and_line(self):
        with self.assertRaisesRegex(rr.RenderError, r"test:2: no value 'colors.nope'"):
            self.r("ok\n{{ colors.nope }}")
        with self.assertRaisesRegex(rr.RenderError, "unknown filter 'sparkle'"):
            self.r("{{ colors.ink | sparkle }}")
        with self.assertRaisesRegex(rr.RenderError, "expected a colour"):
            self.r("{{ fonts.ui | hypr }}")


class Palettes(unittest.TestCase):
    def test_every_rice_loads(self):
        for name in ("nacre", "urushi", "paper"):
            with self.subTest(name):
                ctx = ctx_for(name)
                for role in rr.ROLES:
                    self.assertRegex(ctx["roles"][role], r"^#[0-9a-f]{6}$")

    def test_variant(self):
        self.assertEqual(ctx_for("nacre")["derived"]["variant"], "light")
        self.assertEqual(ctx_for("urushi")["derived"]["variant"], "dark")

    def test_bad_palettes_are_explained(self):
        with tempfile.TemporaryDirectory() as d:
            rice = Path(d) / "broken"
            shutil.copytree(RICES / "nacre", rice, ignore=shutil.ignore_patterns("build"))
            text = (rice / "palette.toml").read_text()
            (rice / "palette.toml").write_text(text.replace('accent    = "orchid"', 'accent    = "teal"'))
            with self.assertRaisesRegex(rr.RenderError, r"roles.accent = 'teal' names no colour"):
                rr.load_palette(rice)
            (rice / "palette.toml").write_text(text.replace('pearl    = "#f4f1f6"', 'pearl    = "f4f1f6"'))
            with self.assertRaisesRegex(rr.RenderError, "colors.pearl .* is not #rrggbb"):
                rr.load_palette(rice)


class EndToEnd(unittest.TestCase):
    def run_render(self, *args, env_extra=None):
        env = dict(os.environ, RICE_DIR=str(self.rices), RICE_TEMPLATES=str(TEMPLATES),
                   RICE_INSTALL_ROOT=str(self.home))
        return subprocess.run([sys.executable, str(SCRIPT), *args], env=env,
                              capture_output=True, text=True)

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.rices, self.home = root / "rices", root / "home"
        shutil.copytree(RICES, self.rices, ignore=shutil.ignore_patterns("build", "current"))
        self.home.mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def test_renders_every_rice_and_check_is_clean_after(self):
        p = self.run_render("--all", "-q")
        self.assertEqual(p.returncode, 0, p.stderr)
        for name in ("nacre", "urushi", "paper"):
            build = self.rices / name / "build"
            for f in ("kitty.conf", "nvim/rice.lua", "gtk/gtk.css", "meta.json", "fastfetch/logo.png"):
                self.assertTrue((build / f).is_file(), f"{name}: {f}")
            self.assertNotIn("{{", (build / "kitty.conf").read_text())
        self.assertTrue((self.home / ".config/quickshell/nacre/Theme.qml").is_file())
        self.assertEqual(self.run_render("--all", "--check").returncode, 0)

    def test_check_reports_stale_output(self):
        self.run_render("--all", "-q")
        (self.rices / "nacre/build/kitty.conf").write_text("stale\n")
        p = self.run_render("nacre", "--check")
        self.assertEqual(p.returncode, 1)
        self.assertIn("kitty.conf", p.stderr)

    def test_rice_templates_override_shared_ones(self):
        (self.rices / "paper/templates").mkdir(parents=True, exist_ok=True)
        (self.rices / "paper/templates/kitty.conf").write_text("bg {{ roles.bg }}\n")
        self.run_render("paper", "-q")
        self.assertEqual((self.rices / "paper/build/kitty.conf").read_text(), "bg #f4efe4\n")

    def test_install_writes_through_stow_symlinks(self):
        real = self.home / "repo-theme.qml"
        real.write_text("old")
        dest = self.home / ".config/quickshell/nacre/Theme.qml"
        dest.parent.mkdir(parents=True)
        dest.symlink_to(real)
        self.run_render("nacre", "-q")
        self.assertTrue(dest.is_symlink())
        self.assertIn("pragma Singleton", real.read_text())


class CommittedOutputs(unittest.TestCase):
    def test_committed_theme_qml_matches_palette(self):
        """quickshell/.config/quickshell/nacre/Theme.qml must be regenerated after palette edits."""
        committed = REPO / "quickshell/.config/quickshell/nacre/Theme.qml"
        if not committed.exists():
            self.skipTest("Theme.qml not committed yet")
        ctx = ctx_for("nacre")
        src = RICES / "nacre/templates/quickshell/Theme.qml"
        self.assertEqual(committed.read_text(), rr.render_text(src.read_text(), ctx, str(src)),
                         "run: rice-render nacre (or tests/regen.sh)")


if __name__ == "__main__":
    unittest.main()
