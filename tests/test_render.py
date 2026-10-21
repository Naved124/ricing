"""Tests for rice-render. Run from the repo root: python3 -m unittest discover tests"""

import importlib.machinery
import importlib.util
import os
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
import unittest
import zipfile
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
        self.assertEqual(self.r("{{ roles.bg | argb(opacity.glass) }}"), "#8cf4f1f6")   # 0.55
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
        self.assertEqual(self.r("{{ fonts.mono_size }}"), "15.5")
        self.assertEqual(self.r("{{ motion.bloom | curve }}"), "[0.2, 0.9, 0.2, 1, 1, 1]")
        self.assertEqual(self.r("{{ motion.border_loop | div(100) }}"), "600")
        self.assertEqual(self.r("{{ derived.is_light | bool }}"), "true")

    def test_readable_text_on_a_colour(self):
        # Nacre's ink reads on its pastels; Paper's pencil doesn't read on ink blue
        self.assertEqual(self.r("{{ roles.accent | readable }}"), "#3b3548")
        paper = ctx_for("paper")
        self.assertEqual(rr.render_text("{{ roles.accent | readable }}", paper, "t"), "#f7f5ef")
        self.assertEqual(rr.render_text("{{ roles.selection | readable }}", paper, "t"), "#4b4a46")

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
        for name in ("nacre", "paper"):
            with self.subTest(name):
                ctx = ctx_for(name)
                for role in rr.ROLES:
                    self.assertRegex(ctx["roles"][role], r"^#[0-9a-f]{6}$")

    def test_yazi_theme_uses_current_keys(self):
        # yazi 25.5+ refuses filetype rules without `url`/`mime` (`name` is gone)
        # and silently ignores the old [mgr] hovered/tab_* keys
        shared = REPO / "render/.local/share/rice/templates/yazi/theme.toml"
        for name in ("nacre", "paper"):
            with self.subTest(name):
                own = RICES / name / "templates/yazi/theme.toml"
                src = (own if own.exists() else shared).read_text()
                theme = tomllib.loads(rr.render_text(src, ctx_for(name), "yazi/theme.toml"))
                for gone in ("hovered", "preview_hovered", "tab_active", "tab_inactive"):
                    self.assertNotIn(gone, theme["mgr"])
                self.assertIn("current", theme["indicator"])
                self.assertIn("active", theme["tabs"])
                for rule in theme["filetype"]["rules"]:
                    self.assertTrue({"url", "mime"} & rule.keys(), rule)
                    self.assertNotIn("name", rule)

    def test_variant(self):
        self.assertEqual(ctx_for("nacre")["derived"]["variant"], "light")
        self.assertEqual(ctx_for("paper")["derived"]["variant"], "light")
        with tempfile.TemporaryDirectory() as d:
            rice = Path(d) / "night"
            shutil.copytree(RICES / "nacre", rice, ignore=shutil.ignore_patterns("build"))
            text = (rice / "palette.toml").read_text()
            text = text.replace("[modes.light.colors]\n", '[modes.light.colors]\nnight    = "#141110"\n', 1)
            text = re.sub(r'(?m)^bg(\s*)= "pearl"', r'bg\1= "night"', text)
            (rice / "palette.toml").write_text(text)
            self.assertEqual(rr.load_palette(rice)["derived"]["variant"], "dark")

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
            # a schema-v1 palette, with its colours at the top level
            (rice / "palette.toml").write_text(re.sub(r"(?m)^\[modes\.light\.(?!meta)", "[", text))
            with self.assertRaisesRegex(rr.RenderError, r"\[colors\] belongs under \[modes.<mode>.colors\]"):
                rr.load_palette(rice)
            (rice / "palette.toml").write_text(text + '\n[colors]\nextra = "#000000"\n')
            with self.assertRaisesRegex(rr.RenderError, r"\[colors\] belongs under \[modes.<mode>.colors\]"):
                rr.load_palette(rice)
            (rice / "palette.toml").write_text(text)
            with self.assertRaisesRegex(rr.RenderError, r"no \[modes.dark.\*\] tables"):
                rr.load_palette(rice, "dark")


class EndToEnd(unittest.TestCase):
    def run_render(self, *args, env_extra=None):
        env = dict(os.environ, RICE_DIR=str(self.rices), RICE_TEMPLATES=str(TEMPLATES),
                   RICE_INSTALL_ROOT=str(self.home), HOME=str(self.home), **(env_extra or {}))
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
        for name in ("nacre", "paper"):
            build = self.rices / name / "build"
            for f in ("kitty.conf", "nvim/rice.lua", "gtk/gtk.css", "meta.json", "fastfetch/logo.png",
                      "limine/theme.conf", "plymouth/rice.script", "plymouth/rice.plymouth",
                      "plymouth/logo.png", "plymouth/bar.png"):
                self.assertTrue((build / f).is_file(), f"{name}: {f}")
            for f in ("kitty.conf", "limine/theme.conf", "plymouth/rice.script"):
                self.assertNotIn("{{", (build / f).read_text(), f"{name}: {f}")
            limine = (build / "limine/theme.conf").read_text()
            for key in ("term_palette", "term_palette_bright"):
                line = next(l for l in limine.splitlines() if l.startswith(key + ":"))
                colours = line.split(":", 1)[1].strip().split(";")
                self.assertEqual(len(colours), 8, f"{name}: {key}")
                self.assertTrue(all(len(c) == 6 for c in colours), f"{name}: {key}")
        self.assertTrue((self.home / ".config/quickshell/nacre/Theme.qml").is_file())
        self.assertEqual(self.run_render("--all", "--check").returncode, 0)

    def test_zsh_colours_and_prompt_glyphs(self):
        self.assertEqual(self.run_render("--all", "-q").returncode, 0)
        for name in ("nacre", "paper"):
            build = self.rices / name / "build"
            zsh = (build / "zsh.zsh").read_text()
            self.assertNotIn("{{", zsh, name)
            self.assertRegex(zsh, r"ZSH_HIGHLIGHT_STYLES\[command\]='fg=#[0-9a-f]{6}'", name)
            self.assertRegex(zsh, r"ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#[0-9a-f]{6}'", name)
            prompt = tomllib.loads((build / "starship.toml").read_text())
            self.assertIn("${custom.github}", prompt["format"])
            self.assertIn("Downloads", prompt["directory"]["substitutions"])
            self.assertIn("github.com", prompt["custom"]["github"]["when"])
        if shutil.which("zsh"):
            p = subprocess.run(["zsh", "-n", str(self.rices / "nacre/build/zsh.zsh")])
            self.assertEqual(p.returncode, 0)

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
        self.assertEqual((self.rices / "paper/build/kitty.conf").read_text(), "bg #f7f5ef\n")

    def test_install_writes_through_stow_symlinks(self):
        real = self.home / "repo-theme.qml"
        real.write_text("old")
        dest = self.home / ".config/quickshell/nacre/Theme.qml"
        dest.parent.mkdir(parents=True)
        dest.symlink_to(real)
        self.run_render("nacre", "-q")
        self.assertTrue(dest.is_symlink())
        self.assertIn("pragma Singleton", real.read_text())

    def test_link_skips_or_backs_up_real_files(self):
        (self.rices / "current").symlink_to("nacre")
        mine = self.home / ".config/starship.toml"
        mine.parent.mkdir(parents=True, exist_ok=True)
        mine.write_text("my prompt")
        out = self.run_render("--link")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("skip", out.stdout)
        self.assertFalse(mine.is_symlink())

        backup = self.home / "backup"
        self.run_render("--link", "--backup", str(backup))
        self.assertTrue(mine.is_symlink())
        self.assertEqual((backup / ".config/starship.toml").read_text(), "my prompt")

    def test_telegram_theme_is_a_stable_zip(self):
        self.run_render("nacre", "-q")
        theme = self.rices / "nacre/build/telegram/rice.tdesktop-theme"
        with zipfile.ZipFile(theme) as z:
            self.assertEqual(sorted(z.namelist()), ["colors.tdesktop-theme", "tiled.png"])
            colors = z.read("colors.tdesktop-theme").decode()
        self.assertIn("windowBg: #f4f1f6;", colors)
        self.assertNotIn("{{", colors)
        # same palette, same bytes: a re-render changes nothing
        self.assertEqual(self.run_render("nacre", "--check").returncode, 0)

    def test_link_configures_apps(self):
        (self.rices / "current").symlink_to("nacre")
        self.run_render("nacre", "-q")
        ff = self.home / ".config/mozilla/firefox"
        (ff / "abc.default").mkdir(parents=True)
        (ff / "profiles.ini").write_text("[Profile0]\nName=default\nIsRelative=1\nPath=abc.default\n")
        mpv = self.home / ".config/mpv/mpv.conf"
        mpv.parent.mkdir(parents=True)
        mpv.write_text("hwdec=auto")
        qt = self.home / ".config/qt6ct/qt6ct.conf"
        qt.parent.mkdir(parents=True)
        qt.write_text("[Appearance]\ncustom_palette=false\nicon_theme=Papirus\n\n[Fonts]\nfixed=@Variant(\\0)\n")

        for _ in range(2):   # running it twice must not duplicate anything
            p = self.run_render("--link", "--firefox")
            self.assertEqual(p.returncode, 0, p.stderr)

        prof = ff / "abc.default"
        self.assertEqual((prof / "user.js").read_text().count("legacyUserProfileCustomizations"), 1)
        self.assertTrue((prof / "chrome/userChrome.css").is_symlink())
        self.assertEqual(mpv.read_text(), 'hwdec=auto\ninclude="~~/rice.conf"\n')
        self.assertTrue((self.home / ".config/mpv/script-opts/osc.conf").is_symlink())
        self.assertTrue((self.home / ".config/cava/config").is_symlink())
        text = qt.read_text()
        self.assertIn("custom_palette=true", text)
        self.assertIn("style=Fusion", text)
        self.assertFalse((self.home / ".config/Kvantum/Rice").exists())
        self.assertIn("icon_theme=Papirus", text)
        self.assertIn('fixed="IBM Plex Mono,15.5,-1,5,600,', text)   # fonts follow the rice
        self.assertIn('general="Manrope,14,-1,5,600,', text)
        self.assertEqual(text.count("color_scheme_path="), 1)


class CommittedOutputs(unittest.TestCase):
    def test_committed_theme_qml_matches_palette(self):
        """Each shell's committed Theme.qml must be regenerated after palette edits."""
        for name, rel in (("nacre", "nacre/Theme.qml"), ("paper", "paper/common/Theme.qml")):
            with self.subTest(name):
                committed = REPO / "quickshell/.config/quickshell" / rel
                ctx = ctx_for(name)
                # the [install] entry is what puts it there
                self.assertEqual(ctx["install"]["quickshell/Theme.qml"], f".config/quickshell/{rel}")
                src = RICES / name / "templates/quickshell/Theme.qml"
                self.assertEqual(committed.read_text(), rr.render_text(src.read_text(), ctx, str(src)),
                                 "run: tools/regen")


def contrast(a: str, b: str) -> float:
    hi, lo = sorted((rr.luminance(a), rr.luminance(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


class Paper(unittest.TestCase):
    def setUp(self):
        self.ctx = ctx_for("paper")

    def test_normal_ansi_colours_read_on_the_paper(self):
        bg = self.ctx["roles"]["term_bg"]
        self.assertEqual(bg, "#f7f5ef")
        for i in range(8):
            c = self.ctx["ansi"][f"color{i}"]
            with self.subTest(f"color{i} {c}"):
                self.assertGreaterEqual(contrast(c, bg), 4.5)

    def test_text_roles_read_on_the_paper(self):
        r = self.ctx["roles"]
        for role in ("fg", "accent", "urgent", "success", "warning", "cursor", "term_fg"):
            with self.subTest(role):
                self.assertGreaterEqual(contrast(r[role], r["bg"]), 4.5)
        # carbon type on the highlighter
        self.assertGreaterEqual(contrast(r["term_fg"], r["selection"]), 4.5)

    def test_mood(self):
        m = self.ctx["meta"]
        self.assertEqual((m["shell"], m["notifications"], m["wallpaper"], m["lock"]),
                         ("paper", "shell", "shell", "shell"))
        self.assertEqual(self.ctx["derived"]["variant"], "light")
        self.assertTrue(all(v == 1.0 for v in self.ctx["opacity"].values()), "Paper has no transparency")
        self.assertTrue((RICES / "paper" / m["screen_shader"]).is_file())

    def test_grain_never_redraws_on_its_own(self):
        """A `time` uniform would make Hyprland drop damage tracking and redraw every frame."""
        src = (RICES / "paper/grain.frag").read_text()
        code = "\n".join(l.split("//")[0] for l in src.splitlines())
        self.assertNotRegex(code, r"\btime\b")
        self.assertTrue(src.startswith("#version 300 es"))

    def test_hypr_layer(self):
        rendered = rr.render_text((RICES / "paper/templates/hypr.lua").read_text(), self.ctx, "hypr.lua")
        for want in ('border_size = 0', 'blur = { enabled = false }', 'range          = 18',
                     'offset         = { 3, 8 }', '"rgba(3c2d1438)"', '"rgba(3c2d1420)"',
                     'gaps_in     = 10', 'gaps_out    = 22', 'rounding         = 3',
                     '{ { 0.2, 1.3 }, { 0.4, 1 } }', '{ { 0.5, 0 }, { 0.75, 0.4 } }',
                     'leaf = "windowsIn",   enabled = true, speed = 5,      bezier = "drop", style = "slide top"',
                     'leaf = "windowsOut",  enabled = true, speed = 4,     bezier = "toss", style = "popin 60%"',
                     'leaf = "workspaces",  enabled = true, speed = 7, bezier = "turn", style = "slide"',
                     '"^paper-wallpaper$" }, no_anim = true'):
            self.assertIn(want, rendered)
        self.assertNotIn("blur = true", rendered)
        self.assertNotRegex(rendered, r"hl\.(bind|monitor|env|exec_cmd)\b", "visuals only")

    def render(self, rel):
        return rr.render_text((RICES / "paper/templates" / rel).read_text(), self.ctx, rel)

    def test_typewriter_terminal(self):
        k = self.render("kitty.conf")
        for want in ('family="Courier Prime"', "background_image_layout tiled", "background_tint       0.92",
                     "window_padding_width  22 26", "cursor_shape          underline",
                     "background_opacity    1", "/assets/paper-tex.png"):
            self.assertIn(want, k)
        self.assertNotIn("bold_is_bright", k)    # not a kitty option; kitty never brightens bold

    def test_nvim_scheme(self):
        n = self.render("nvim/rice.lua")
        self.assertIn('hl("Keyword",    { fg = c.ink, bold = true })', n)
        self.assertIn('hl("Comment",    { fg = c.note, italic = true })', n)
        self.assertIn('hl("DiagnosticWarn",  { fg = c.ochre })', n)
        self.assertIn('ruled    = "#e9eced"', n)          # #a8c3e4 at 18% over the paper
        self.assertIn('vim.g.colors_name = "rice"', n)    # the linked name every rice shares

    def test_fonts_are_vendored_with_their_licences(self):
        fonts = REPO / "fonts/.local/share/fonts/paper"
        files = {f.name for f in fonts.iterdir()}
        f = self.ctx["fonts"]
        for family, prefix in ((f["type"], "CourierPrime"), (f["hand"], "Kalam"), (f["serif"], "Newsreader")):
            with self.subTest(family):
                self.assertTrue(any(n.startswith(prefix) and n.endswith(".ttf") for n in files))
                self.assertIn(f"OFL-{prefix}.txt", files)
        for weight in ("Light", "Regular", "Bold"):
            self.assertIn(f"Kalam-{weight}.ttf", files)
        self.assertEqual({f["display"], f["ui"], f["mono"]} - {f["type"], f["hand"], f["serif"]}, set())


if __name__ == "__main__":
    unittest.main()
