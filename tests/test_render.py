"""Tests for rice-render. Run from the repo root: python3 -m unittest discover tests"""

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
import unittest.mock
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

    def test_yazi_picks_a_flavour_per_mode(self):
        theme = tomllib.loads((REPO / "render/.local/share/rice/templates/yazi/theme.toml").read_text())
        self.assertEqual(theme, {"flavor": {"light": "rice-light", "dark": "rice-dark"}})
        self.assertIn((".config/yazi/flavors/rice-{mode}.yazi/flavor.toml", "yazi/flavor.toml"), rr.MODE_LINKS)

    def test_kitty_colours_live_in_their_own_file(self):
        # kitty.conf includes them; kitty also reads them as its automatic
        # light/dark theme, which may hold colours only
        for name in ("nacre", "paper"):
            ctxs = rr.load_modes(RICES / name)
            for mode in rr.MODES:
                with self.subTest(f"{name} {mode}"), unittest.mock.patch.object(rr, "SHARED", TEMPLATES):
                    files = rr.template_files(RICES / name, mode)
                    conf = rr.render_text(files["kitty.conf"].read_text(), ctxs[mode], "kitty.conf")
                    colours = rr.render_text(files["kitty-colors.conf"].read_text(), ctxs[mode], "kitty-colors.conf")
                    self.assertIn(f"include {RICES / name}/build/{mode}/kitty-colors.conf", conf)
                    self.assertNotRegex(conf, r"(?m)^(background|foreground|color\d+|cursor) ")
                    keys = {l.split()[0] for l in colours.splitlines() if l.strip() and not l.startswith("#")}
                    self.assertTrue({"background", "foreground", "cursor", "color0", "color15"} <= keys)
                    self.assertFalse(keys & {"background_image", "font_family", "background_opacity"})

    def test_kitty_version_check(self):
        with tempfile.TemporaryDirectory() as d:
            kitty = Path(d) / "kitty"
            for out, want in (("kitty 0.39.1 created by Kovid Goyal", True), ("kitty 0.32.2", False), ("", False)):
                kitty.write_text(f"#!/bin/sh\necho '{out}'\n")
                kitty.chmod(0o755)
                with self.subTest(out), unittest.mock.patch.dict(os.environ, {"PATH": d}):
                    self.assertEqual(rr.kitty_auto_themes(), want)

    def test_firefox_holds_both_modes(self):
        ctxs = rr.load_modes(RICES / "nacre")
        for css in ("userChrome.css", "userContent.css"):
            with self.subTest(css):
                src = TEMPLATES / "firefox" / css
                text = rr.render_text(src.read_text(), ctxs["light"], css)
                self.assertEqual(text, rr.render_text(src.read_text(), ctxs["dark"], css), "the same in both builds")
                light, dark = text.split("@media (prefers-color-scheme: dark)")
                self.assertIn("--rice-bg: #f4f1f6;", light)
                self.assertIn("--rice-bg:", dark)
                # outside the two variable blocks, nothing names a colour
                rules = dark.split("\n}\n", 1)[1]
                self.assertNotRegex(rules, r"#[0-9a-f]{6}")

    def test_spicetify_has_a_scheme_per_mode(self):
        text = rr.render_text((TEMPLATES / "spicetify/color.ini").read_text(), rr.load_modes(RICES / "paper")["light"], "c")
        self.assertIn("[rice-light]", text)
        self.assertIn("[rice-dark]", text)

    def test_yazi_theme_uses_current_keys(self):
        # yazi 25.5+ refuses filetype rules without `url`/`mime` (`name` is gone)
        # and silently ignores the old [mgr] hovered/tab_* keys
        shared = REPO / "render/.local/share/rice/templates/yazi/flavor.toml"
        for name in ("nacre", "paper"):
            with self.subTest(name):
                own = RICES / name / "templates/yazi/flavor.toml"
                src = (own if own.exists() else shared).read_text()
                theme = tomllib.loads(rr.render_text(src, ctx_for(name), "yazi/flavor.toml"))
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
            # no [modes.dark.*]: dark wears the light tables
            (rice / "palette.toml").write_text(text.split("\n# ── dark")[0])
            dark = rr.load_palette(rice, "dark")
            self.assertEqual((dark["mode"], dark["has_mode"], dark["roles"]["bg"]), ("dark", False, "#f4f1f6"))
            with self.assertRaisesRegex(rr.RenderError, r"no mode called 'dusk'"):
                rr.load_palette(rice, "dusk")


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
        for name, mode in ((n, m) for n in ("nacre", "paper") for m in ("light", "dark")):
            name_ = f"{name} {mode}"
            build = self.rices / name / "build" / mode
            for f in ("kitty.conf", "nvim/rice.lua", "gtk/gtk.css", "meta.json", "fastfetch/logo.png",
                      "limine/theme.conf", "plymouth/rice.script", "plymouth/rice.plymouth",
                      "plymouth/logo.png", "plymouth/bar.png"):
                self.assertTrue((build / f).is_file(), f"{name_}: {f}")
            for f in ("kitty.conf", "limine/theme.conf", "plymouth/rice.script"):
                self.assertNotIn("{{", (build / f).read_text(), f"{name_}: {f}")
            limine = (build / "limine/theme.conf").read_text()
            for key in ("term_palette", "term_palette_bright"):
                line = next(l for l in limine.splitlines() if l.startswith(key + ":"))
                colours = line.split(":", 1)[1].strip().split(";")
                self.assertEqual(len(colours), 8, f"{name_}: {key}")
                self.assertTrue(all(len(c) == 6 for c in colours), f"{name_}: {key}")
        self.assertTrue((self.home / ".config/quickshell/nacre/Theme.qml").is_file())
        self.assertEqual(self.run_render("--all", "--check").returncode, 0)

    def test_zsh_colours_and_prompt_glyphs(self):
        self.assertEqual(self.run_render("--all", "-q").returncode, 0)
        for name in ("nacre", "paper"):
            build = self.rices / name / "build/light"
            zsh = (build / "zsh.zsh").read_text()
            self.assertNotIn("{{", zsh, name)
            self.assertRegex(zsh, r"ZSH_HIGHLIGHT_STYLES\[command\]='fg=#[0-9a-f]{6}'", name)
            self.assertRegex(zsh, r"ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#[0-9a-f]{6}'", name)
            prompt = tomllib.loads((build / "starship.toml").read_text())
            self.assertIn("${custom.github}", prompt["format"])
            self.assertIn("Downloads", prompt["directory"]["substitutions"])
            self.assertIn("github.com", prompt["custom"]["github"]["when"])
        if shutil.which("zsh"):
            p = subprocess.run(["zsh", "-n", str(self.rices / "nacre/build/light/zsh.zsh")])
            self.assertEqual(p.returncode, 0)

    def test_leftovers_from_the_flat_build_are_removed(self):
        old = self.rices / "nacre/build"
        (old / "nvim").mkdir(parents=True)
        (old / "kitty.conf").write_text("old\n")
        (old / "nvim/rice.lua").write_text("old\n")
        self.assertEqual(self.run_render("nacre", "-q").returncode, 0)
        self.assertEqual(sorted(p.name for p in old.iterdir()), ["dark", "light"])

    def test_check_reports_stale_output(self):
        self.run_render("--all", "-q")
        (self.rices / "nacre/build/dark/kitty.conf").write_text("stale\n")
        p = self.run_render("nacre", "--check")
        self.assertEqual(p.returncode, 1)
        self.assertIn("kitty.conf", p.stderr)

    def test_rice_templates_override_shared_ones(self):
        (self.rices / "paper/templates").mkdir(parents=True, exist_ok=True)
        (self.rices / "paper/templates/kitty.conf").write_text("bg {{ roles.bg }}\n")
        self.run_render("paper", "-q")
        self.assertEqual((self.rices / "paper/build/light/kitty.conf").read_text(), "bg #f7f5ef\n")

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
        # apps link through active/, which follows the rice (current) and the mode
        active = self.home / ".local/share/rice/active"
        self.assertEqual(Path(os.readlink(active)), self.rices / "current/build/light")
        self.assertEqual(Path(os.readlink(self.home / ".config/btop/themes/rice.theme")),
                         active / "btop.theme")
        (self.home / ".local/state/rice").mkdir(parents=True)
        (self.home / ".local/state/rice/mode").write_text("dark\n")
        self.run_render("--link")
        self.assertEqual(Path(os.readlink(active)), self.rices / "current/build/dark")

        backup = self.home / "backup"
        self.run_render("--link", "--backup", str(backup))
        self.assertTrue(mine.is_symlink())
        self.assertEqual((backup / ".config/starship.toml").read_text(), "my prompt")

    def test_nvim_is_see_through_and_lazyvim_picks_it(self):
        (self.rices / "current").symlink_to("nacre")
        self.run_render("nacre", "-q")
        scheme = (self.rices / "nacre/build/light/nvim/rice.lua").read_text()
        # kitty only frosts cells in its own background colour
        self.assertIn('hl("Normal",       { fg = c.term_fg, bg = "NONE" })', scheme)
        spec = self.home / ".config/nvim/lua/plugins/rice.lua"
        self.run_render("--link")
        self.assertFalse(spec.is_symlink(), "linked into a config that isn't LazyVim")
        lazy = self.home / ".config/nvim/lua/config/lazy.lua"
        lazy.parent.mkdir(parents=True)
        lazy.write_text('require("lazy").setup({ spec = { { "LazyVim/LazyVim", import = "lazyvim.plugins" } } })')
        self.run_render("--link")
        self.assertEqual(Path(os.readlink(spec)), self.home / ".local/share/rice/active/nvim/lazyvim.lua")
        self.assertIn('colorscheme = "rice"', spec.read_text())

    def test_telegram_theme_is_a_stable_zip(self):
        self.run_render("nacre", "-q")
        theme = self.rices / "nacre/build/light/telegram/rice.tdesktop-theme"
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
        """Each shell's committed Theme.qml must be regenerated after palette edits,
        and serves both modes, so it renders the same from either."""
        for name, rel in (("nacre", "nacre/Theme.qml"), ("paper", "paper/common/Theme.qml"), ("abyss", "abyss/Theme.qml")):
            ctxs = rr.load_modes(RICES / name)
            committed = REPO / "quickshell/.config/quickshell" / rel
            # the [install] entry is what puts it there
            self.assertEqual(ctxs["light"]["install"]["quickshell/Theme.qml"], f".config/quickshell/{rel}")
            src = RICES / name / "templates/quickshell/Theme.qml"
            for mode in rr.MODES:
                with self.subTest(f"{name} {mode}"):
                    self.assertEqual(committed.read_text(),
                                     rr.render_text(src.read_text(), ctxs[mode], str(src)),
                                     "run: tools/regen")


class ShellModes(unittest.TestCase):
    """Every shell follows the mode the same way."""
    SHELLS = REPO / "quickshell/.config/quickshell"
    MODE = ["nacre/Mode.qml", "paper/common/Mode.qml", "rice/Mode.qml", "abyss/Mode.qml", "satsuei/common/Mode.qml",
            "goldengate/common/Mode.qml"]

    def test_the_mode_copies_are_identical(self):
        first = (self.SHELLS / self.MODE[0]).read_text()
        for rel in self.MODE[1:]:
            with self.subTest(rel):
                self.assertEqual((self.SHELLS / rel).read_text(), first, f"copy {self.MODE[0]} to {rel}")
        for needle in ('target: "mode"', "function set(m: string)", "function jump(m: string)",
                       "function fade(m: string, ms: int)", "function toggle()", "function get(): string",
                       "blockLoading: true", "watchChanges: true", '"/rice/mode"'):
            self.assertIn(needle, first)

    def test_every_theme_mixes_both_modes(self):
        for rel in ("nacre/Theme.qml", "paper/common/Theme.qml", "rice/Theme.qml", "abyss/Theme.qml",
                    "goldengate/common/Theme.qml"):
            with self.subTest(rel):
                text = (self.SHELLS / rel).read_text()
                self.assertIn("readonly property Mode mode: Mode", text)
                self.assertIn("readonly property bool dark: mode.dark", text)
                self.assertIn("readonly property real k: mode.k", text)
                # no colour is fixed to one mode: each one goes through the mix
                for line in text.splitlines():
                    if "readonly property color" in line:
                        self.assertRegex(line, r"(cc|c|role)\(\"\w+\"", line)

    def test_meta_json_carries_both_modes(self):
        ctxs = rr.load_modes(RICES / "nacre")
        with tempfile.TemporaryDirectory() as d:
            saved = rr.SHARED, rr.INSTALL_ROOT
            rr.SHARED, rr.INSTALL_ROOT = TEMPLATES, Path(d)
            try:
                out = rr.mode_outputs(RICES / "nacre", ctxs["light"])
            finally:
                rr.SHARED, rr.INSTALL_ROOT = saved
        meta = json.loads(out[RICES / "nacre/build/light/meta.json"])
        self.assertEqual(sorted(meta["modes"]), ["dark", "light"])
        self.assertEqual(meta["modes"]["light"]["roles"]["bg"], "#f4f1f6")
        self.assertEqual(len(meta["modes"]["dark"]["gradient"]), 5)

    def test_each_rice_reveals_a_mode_change_with_its_own_shader(self):
        for rice, shader in (("paper", "lamp"), ("nacre", "orient")):
            with self.subTest(rice):
                ctxs = rr.load_modes(RICES / rice)
                with tempfile.TemporaryDirectory() as d:
                    saved = rr.SHARED, rr.INSTALL_ROOT
                    rr.SHARED, rr.INSTALL_ROOT = TEMPLATES, Path(d)
                    try:
                        out = rr.mode_outputs(RICES / rice, ctxs["dark"])
                    finally:
                        rr.SHARED, rr.INSTALL_ROOT = saved
                t = json.loads(out[RICES / f"{rice}/build/dark/meta.json"])["mode_transition"]
                self.assertEqual(t["shader"], shader)
                self.assertEqual(len(t["origin"]), 2)
                self.assertTrue(all(0 <= v <= 1 for v in t["origin"]))
                for m in ("light", "dark"):
                    self.assertRegex(t["tint"][m], r"^#[0-9a-f]{6}$")
                src = RICES / rice / f"{shader}.frag"
                qsb = RICES / rice / f"{shader}.frag.qsb"
                self.assertTrue(qsb.exists(), "run tools/shaders")
                self.assertGreaterEqual(qsb.stat().st_mtime, src.stat().st_mtime - 1, "recompile with tools/shaders")


class SystemCard(unittest.TestCase):
    """The draggable cpu / memory / disk card on both desktops."""
    SHELLS = REPO / "quickshell/.config/quickshell"

    def test_the_sys_copies_are_identical(self):
        paper = (self.SHELLS / "paper/services/Sys.qml").read_text()
        for shell in ("nacre", "abyss"):
            self.assertEqual((self.SHELLS / f"{shell}/services/Sys.qml").read_text(), paper,
                             f"copy paper/services/Sys.qml to {shell}/services/Sys.qml")
        # one long-lived reader, not a process per sample
        self.assertEqual(paper.count("Process {"), 1)
        self.assertIn("while :; do", paper)
        for needle in ("/proc/stat", "MemAvailable", "df -B1 --output=size,used,avail /"):
            self.assertIn(needle, paper)
        # Paper's bar reads the same numbers
        self.assertIn("Sys.cpu", (self.SHELLS / "paper/services/Cpu.qml").read_text())

    def test_both_shells_put_it_on_the_desk(self):
        for shell, ns in (("paper", "paper-stats"), ("nacre", "nacre-stats"), ("abyss", "abyss-stats")):
            with self.subTest(shell):
                self.assertRegex((self.SHELLS / shell / "shell.qml").read_text(), r"\n\s*Stats \{\}")
                card = (self.SHELLS / shell / "desk/Stats.qml").read_text()
                for needle in ("WlrLayer.Bottom", f'"{ns}"', "DragHandler", "Shell.setStatsAt(",
                               "Shell.statsShown", "Hypr.fullscreenOn", "mask: Region { item: card }"):
                    self.assertIn(needle, card)
                self.assertIn("Shell.setStatsShown(", (self.SHELLS / shell / "center/Center.qml").read_text())
                saved = (self.SHELLS / shell / "services/Shell.qml").read_text()
                for needle in ("property bool statsShown: true", "property real statsX", "property real statsY"):
                    self.assertIn(needle, saved)
        # Nacre's card is glass: Hyprland blurs its layer
        self.assertIn("|stats)$", (RICES / "nacre/templates/hypr.lua").read_text())


class Island(unittest.TestCase):
    """The island over the bar's middle: the time, what's playing, notifications."""
    SHELLS = REPO / "quickshell/.config/quickshell"

    def test_one_cava_per_shell(self):
        beat = (self.SHELLS / "paper/services/Beat.qml").read_text()
        for shell in ("nacre", "abyss"):
            self.assertEqual((self.SHELLS / f"{shell}/services/Beat.qml").read_text(), beat,
                             f"copy paper/services/Beat.qml to {shell}/services/Beat.qml")
        self.assertIn("running: Media.playing", beat)
        for shell in ("paper", "nacre", "abyss"):
            with self.subTest(shell):
                runs = [f.relative_to(self.SHELLS / shell).as_posix()
                        for f in (self.SHELLS / shell).rglob("*.qml") if "exec cava" in f.read_text()]
                self.assertEqual(runs, ["services/Beat.qml"])

    def test_each_shell_has_an_island(self):
        for shell in ("paper", "nacre", "abyss"):
            with self.subTest(shell):
                self.assertIn("Island {}", (self.SHELLS / shell / "shell.qml").read_text())
                island = (self.SHELLS / shell / "bar/Island.qml").read_text()
                for needle in ("PanelWindow", f'"{shell}-island"', "WlrLayer.Overlay", "mask: Region",
                               "Beat.level", "Beat.levels", "Media.playing", "trackArtUrl", "MultiEffect",
                               "HoverHandler", "Notifs.current", "Notifs.dismiss(", "Notifs.done(",
                               "Notifs.seen()", "Notifs.all.length", "SystemClock", "Marquee",
                               "Shell.toggleIsland(", "Keys.onEscapePressed"):
                    self.assertIn(needle, island)
                # the time moved into the island; the bar keeps the title, scrolling
                bar = (self.SHELLS / shell / "bar/Bar.qml").read_text()
                self.assertNotIn("Island {", bar)
                self.assertNotIn("Clock {", bar)
                self.assertFalse((self.SHELLS / shell / "bar/Clock.qml").exists())
                self.assertIn("Title {", bar)
                self.assertIn("Marquee", (self.SHELLS / shell / "bar/Title.qml").read_text())
        self.assertIn("Iridescent", (self.SHELLS / "nacre/bar/Island.qml").read_text())
        self.assertIn("Theme.warmth", (self.SHELLS / "paper/bar/Island.qml").read_text())
        self.assertFalse((self.SHELLS / "nacre/bar/MediaMini.qml").exists())

    def test_every_control_centre_has_the_shared_controls(self):
        # what each one's code does, so a rice can't quietly drop one
        shared = {"Wi-Fi": "Net.setWifi(", "network widget": '"network", "open"', "Bluetooth": "win.adapter",
                  "Do Not Disturb": "Shell.setDnd(", "night light": "Shell.setNightLight(", "microphone": "Audio.toggleMic()",
                  "power profile": "PowerProfiles.profile =", "caffeine": "Shell.caffeine = !Shell.caffeine",
                  "screenshot": '"rice-shot", "region"', "recording": 'Shell.toggleRecording("region")',
                  "system card": "Shell.setStatsShown(", "Notion": '"notion", "toggle"', "volume to 150%": "1.5|150"}
        for shell in ("nacre", "paper", "abyss", "satsuei", "goldengate"):
            folder = "controlcenter" if shell == "goldengate" else "center"
            center = "".join(f.read_text() for f in (self.SHELLS / shell / folder).glob("*.qml"))
            for what, code in shared.items():
                with self.subTest(shell=shell, control=what):
                    self.assertTrue(any(c in center for c in code.split("|")) or
                                    (what == "volume to 150%" and "maxVolume" in center), f"{shell}'s centre has no {what}")

    def test_notifications_go_to_the_island(self):
        for shell in ("paper", "nacre", "abyss"):
            with self.subTest(shell):
                notifs = (self.SHELLS / shell / "services/Notifs.qml").read_text()
                self.assertIn("readonly property int lifetime: 4000", notifs)
                self.assertIn("root.queue = [...root.queue, n]", notifs)
                # no other popups, and the control centre keeps neither media nor history
                center = (self.SHELLS / shell / "center/Center.qml").read_text()
                for gone in ("MediaCard", "NowPlaying", "History", "Notifs.all", "Cava"):
                    self.assertNotIn(gone, center)
                for f in (self.SHELLS / shell).rglob("*.qml"):
                    self.assertNotIn("Notifs.popups", f.read_text(), f)
                    self.assertNotIn("Notifs.shown", f.read_text(), f)
        self.assertFalse((self.SHELLS / "nacre/notifs/Popups.qml").exists())
        self.assertFalse((self.SHELLS / "paper/notes/Notes.qml").exists())
        # the island is glass in Nacre (blurred) and still in Paper (no slide-in)
        self.assertIn("|island|", (RICES / "nacre/templates/hypr.lua").read_text())
        self.assertIn("|island|", (RICES / "paper/templates/hypr.lua").read_text())

    def test_title_follows_hyprland_events(self):
        hypr = (self.SHELLS / "paper/services/Hypr.qml").read_text()
        for shell in ("nacre", "abyss"):
            self.assertEqual((self.SHELLS / f"{shell}/services/Hypr.qml").read_text(), hypr,
                             f"copy paper/services/Hypr.qml to {shell}/services/Hypr.qml")
        for event in ('"activewindow"', '"activewindowv2"', '"windowtitlev2"'):
            self.assertIn(event, hypr)
        for shell in ("paper", "nacre", "abyss"):
            with self.subTest(shell):
                title = (self.SHELLS / shell / "bar/Title.qml").read_text()
                self.assertIn("Hypr.activeTitle", title)
                self.assertNotIn("activeToplevel", title)
                # a PropertyAction bound to the title swaps in the previous one
                self.assertNotIn("PropertyAction", title)

    def test_nacre_tray_is_always_out(self):
        tray = (self.SHELLS / "nacre/bar/Tray.qml").read_text()
        self.assertNotIn("Pearl", tray)
        self.assertNotIn("property bool open", tray)


class BlackPearl(unittest.TestCase):
    """Nacre at night: the Hyprland half and the wallpaper's still."""

    def test_hypr_mode_at_night(self):
        ctx = rr.load_modes(RICES / "nacre")["dark"]
        mode = rr.render_text((RICES / "nacre/templates/hypr-mode.lua").read_text(), ctx, "hypr-mode.lua")
        for want in ('"rgba(c06b94ff)", "rgba(5a86c8ff)", "rgba(46a394ff)", "rgba(bdb39aff)", "rgba(9367b8ff)"',
                     '"rgba(4a445880)"', 'brightness = 0.82', 'vibrancy   = 0.15', 'range          = 40',
                     'background_color = "rgba(18171eff)"', '"rgba(f4f1f62e)"'):
            self.assertIn(want, mode)
        self.assertNotIn("ffffff", mode, "no white at night")

    def test_the_wallpaper_still_is_committed(self):
        still = RICES / "nacre/assets/wall-static-dark.png"
        self.assertTrue(still.exists(), "tools/render-wall dark")
        src = REPO / "quickshell/.config/quickshell/nacre/shaders/wallpaper.frag"
        self.assertIn("uniform", src.read_text())
        self.assertIn("orientWalk", src.read_text())


class Modes(unittest.TestCase):
    """Every rice renders in both modes, from the same templates."""

    def test_hypr_lua_is_the_same_in_both_modes(self):
        # everything mode-dependent sits in hypr-mode.lua, which `rice mode`
        # sends with hyprctl eval; the rest (window rules too) never changes,
        # so a mode switch never needs a reload
        for name in ("nacre", "paper", "abyss"):
            with self.subTest(name):
                out = self.outputs(name)
                # a one-mode rice (Abyss) renders dark only; light links to it
                self.assertEqual(out.get("build/light/hypr.lua", out["build/dark/hypr.lua"]), out["build/dark/hypr.lua"])
                self.assertIn(b"hl.config({", out["build/dark/hypr-mode.lua"])
                self.assertNotRegex(out["build/dark/hypr-mode.lua"].decode(),
                                    r"hl\.(window_rule|layer_rule|bind|animation|curve)\b")

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.rices = root / "rices"
        shutil.copytree(RICES, self.rices, ignore=shutil.ignore_patterns("build", "current"))
        self.saved = rr.SHARED, rr.INSTALL_ROOT
        rr.SHARED, rr.INSTALL_ROOT = TEMPLATES, root / "home"

    def tearDown(self):
        rr.SHARED, rr.INSTALL_ROOT = self.saved
        self.tmp.cleanup()

    def outputs(self, name: str) -> dict[str, bytes]:
        rice = self.rices / name
        return {p.relative_to(rice).as_posix(): d
                for p, d in rr.outputs_for(rice, rr.load_modes(rice)).items() if p.is_relative_to(rice)}

    def test_every_template_renders_in_both_modes(self):
        for name in ("nacre", "paper"):
            with self.subTest(name):
                out = self.outputs(name)   # an unresolved key would raise here
                light = {k.removeprefix("build/light/") for k in out if k.startswith("build/light/")}
                dark = {k.removeprefix("build/dark/") for k in out if k.startswith("build/dark/")}
                self.assertGreater(len(light), 30)
                self.assertEqual(light, dark)
                self.assertEqual(len(out), len(light) + len(dark))
                meta = json.loads(out["build/dark/meta.json"])
                self.assertEqual(meta["mode"], "dark")

    def test_templates_see_the_mode_and_both_palettes(self):
        ctxs = rr.load_modes(self.rices / "paper")
        text = "{{ mode }} {{ light.roles.bg }} {{ dark.mode }} {{ light.gtk.theme }}"
        self.assertEqual(rr.render_text(text, ctxs["dark"], "t"), "dark #f7f5ef dark adw-gtk3")
        self.assertEqual(rr.render_text(text, ctxs["light"], "t"), "light #f7f5ef dark adw-gtk3")

    def test_a_template_that_differs_by_mode_is_a_pair(self):
        tpl = self.rices / "paper/templates/notes"
        tpl.mkdir()
        (tpl / "pad@light.conf").write_text("{{ mode }} pad {{ roles.bg }}\n")
        (tpl / "pad@dark.conf").write_text("{{ mode }} blotter\n")
        (tpl / "pad.conf").write_text("the plain one loses\n")
        out = self.outputs("paper")
        self.assertEqual(out["build/light/notes/pad.conf"], b"light pad #f7f5ef\n")
        self.assertEqual(out["build/dark/notes/pad.conf"], b"dark blotter\n")
        self.assertNotIn("build/light/notes/pad@light.conf", out)
        # a light-only template fails the build, whichever mode is rendered
        (tpl / "pad@dark.conf").unlink()
        with self.assertRaisesRegex(rr.RenderError, r"pad@light.conf: has no dark twin"):
            self.outputs("paper")
        (tpl / "pad@dark.conf").write_text("x\n")
        (tpl / "pad@dusk.conf").write_text("x\n")
        with self.assertRaisesRegex(rr.RenderError, r"no mode called 'dusk'"):
            self.outputs("paper")

    def test_an_installed_file_has_to_serve_both_modes(self):
        (self.rices / "paper/templates/quickshell/Theme.qml").write_text("// {{ mode }}\n")
        with self.assertRaisesRegex(rr.RenderError, r"\[install\] 'quickshell/Theme.qml' differs between modes"):
            self.outputs("paper")


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

    def test_apps_read_bigger_than_the_shell(self):
        """Newsreader runs small: apps get app_size, the shell keeps ui_size."""
        f = self.ctx["fonts"]
        self.assertEqual((f["ui_size"], f["app_size"]), (14, 16))
        shared = REPO / "render/.local/share/rice/templates"
        z = rr.render_text((shared / "zathurarc").read_text(), self.ctx, "zathurarc")
        self.assertIn('set font                    "Newsreader 17"', z)
        theme = (REPO / "quickshell/.config/quickshell/paper/common/Theme.qml").read_text()
        self.assertRegex(theme, r"uiSize:\s+14\b")
        # a rice without app_size keeps one size for both
        self.assertEqual(ctx_for("nacre")["fonts"]["app_size"], ctx_for("nacre")["fonts"]["ui_size"])

    def test_grain_never_redraws_on_its_own(self):
        """A `time` uniform would make Hyprland drop damage tracking and redraw every frame."""
        src = (RICES / "paper/grain.frag").read_text()
        code = "\n".join(l.split("//")[0] for l in src.splitlines())
        self.assertNotRegex(code, r"\btime\b")
        self.assertTrue(src.startswith("#version 300 es"))

    def test_hypr_layer(self):
        rendered = rr.render_text((RICES / "paper/templates/hypr.lua").read_text(), self.ctx, "hypr.lua")
        mode = rr.render_text((RICES / "paper/templates/hypr-mode.lua").read_text(), self.ctx, "hypr-mode.lua")
        for want in ('range          = 18', 'offset         = { 3, 8 }', '"rgba(3c2d1438)"', '"rgba(3c2d1420)"',
                     'background_color = "rgba(d9d6ccff)"', '/grain.frag"'):
            self.assertIn(want, mode)
        for want in ('border_size = 0', 'blur = { enabled = false }', 'dofile(here .. "hypr-mode.lua")',
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
        n = self.render("nvim/rice@light.lua")
        self.assertIn('hl("Keyword",    { fg = c.ink, bold = true })', n)
        self.assertIn('hl("Comment",    { fg = c.note, italic = true })', n)
        self.assertIn('hl("DiagnosticWarn",  { fg = c.ochre })', n)
        self.assertIn('ruled    = "#e9eced"', n)          # #a8c3e4 at 18% over the paper
        self.assertIn('vim.g.colors_name = "rice"', n)    # the linked name every rice shares

    def test_paper_night(self):
        """The dark build: notebook nvim, the dark sheet under kitty, the lamp's
        grain, and the night shadow."""
        ctx = rr.load_modes(RICES / "paper")["dark"]
        r = lambda rel: rr.render_text((RICES / "paper/templates" / rel).read_text(), ctx, rel)
        n = r("nvim/rice@dark.lua")
        for want in ('vim.o.background = "dark"', 'paper    = "#1f1c19"', 'hl("Keyword",    { fg = c.ink, bold = true })',
                     'ink      = "#a3b4f0"', 'hl("CursorLineNr", { fg = c.red, bold = true })',
                     'hl("CursorLine",   { bg = c.ruled })', 'ruled    = "#2f3a4c"', 'hl("FloatBorder",  { fg = c.kraft, bg = c.card })'):
            self.assertIn(want, n)
        self.assertIn("/assets/sheet-dark.png", r("kitty.conf"))
        grain = r("grain-dark.frag")
        self.assertIn("const float VIGNETTE = 0.04;", grain)
        self.assertIn("vec2(0.18, 1.0 - 0.12)", grain)
        code = "\n".join(l.split("//")[0] for l in grain.splitlines())
        self.assertNotRegex(code, r"\btime\b")
        mode = r("hypr-mode.lua")
        for want in ('range          = 22', 'offset         = { 3, 10 }', '"rgba(0b0a08aa)"',
                     'background_color = "rgba(161411ff)"', '/build/dark/grain-dark.frag"'):
            self.assertIn(want, mode)
        # the day keeps its highlighter; the night its kraft
        self.assertIn('theme[selected_bg]="#3b3024"', r("btop.theme"))
        self.assertIn('theme[selected_bg]="#f6e15f"', self.render("btop.theme"))
        self.assertTrue((RICES / "paper/assets/wall-dark.png").exists())
        self.assertTrue((RICES / "paper/assets/sheet-dark.png").exists())

    def test_night_filter_keeps_the_day(self):
        light, dark = rr.load_modes(RICES / "paper")["light"], rr.load_modes(RICES / "paper")["dark"]
        t = "{{ colors.sticky | night(colors.kraft_hi) }}"
        self.assertEqual(rr.render_text(t, light, "t"), "#f6e15f")   # kraft_hi is dark-only
        self.assertEqual(rr.render_text(t, dark, "t"), "#4d3e2c")

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


def make_dark_only(rices: Path, name: str = "deep") -> Path:
    """A dark-only rice for the tests: Nacre with its light tables cut and
    [meta] modes = ["dark"] (what Abyss declares)."""
    rice = rices / name
    shutil.copytree(rices / "nacre", rice, ignore=shutil.ignore_patterns("build"))
    text = (rice / "palette.toml").read_text()
    # drop every [modes.light.*] table, up to the next table that isn't one
    text = re.sub(r"(?ms)^\[modes\.light\.[^\]]*\].*?(?=^\[(?!modes\.light\.))", "", text)
    text = text.replace('name          = "nacre"', f'name          = "{name}"', 1)
    text = text.replace('title         = "Nacre"', f'title         = "{name.title()}"', 1)
    text = text.replace("[meta]\n", '[meta]\nmodes         = ["dark"]\n', 1)
    text = text.replace('".config/quickshell/nacre/Theme.qml"', f'".config/quickshell/{name}/Theme.qml"')
    (rice / "palette.toml").write_text(text)
    return rice


class DarkOnly(unittest.TestCase):
    """A rice that declares [meta] modes = ["dark"] renders that mode only."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.rices, self.home = root / "rices", root / "home"
        shutil.copytree(RICES, self.rices, ignore=shutil.ignore_patterns("build", "current"))
        self.home.mkdir()
        self.rice = make_dark_only(self.rices)
        self.saved = rr.SHARED, rr.INSTALL_ROOT
        rr.SHARED, rr.INSTALL_ROOT = TEMPLATES, self.home

    def tearDown(self):
        rr.SHARED, rr.INSTALL_ROOT = self.saved
        self.tmp.cleanup()

    def outputs(self, rice=None) -> dict[str, bytes]:
        rice = rice or self.rice
        return {p.relative_to(rice).as_posix() if p.is_relative_to(rice) else str(p): d
                for p, d in rr.outputs_for(rice, rr.load_modes(rice)).items()}

    def run_render(self, *args):
        env = dict(os.environ, RICE_DIR=str(self.rices), RICE_TEMPLATES=str(TEMPLATES),
                   RICE_INSTALL_ROOT=str(self.home), HOME=str(self.home))
        return subprocess.run([sys.executable, str(SCRIPT), *args], env=env, capture_output=True, text=True)

    def test_the_fixture_has_no_light_tables(self):
        text = (self.rice / "palette.toml").read_text()
        self.assertNotIn("[modes.light.", text)
        self.assertIn("[modes.dark.colors]", text)
        self.assertEqual(rr.load_modes(self.rice)["light"]["modes"], ["dark"])

    def test_only_the_dark_build_is_rendered(self):
        out = self.outputs()
        builds = {k.split("/")[1] for k in out if k.startswith("build/")}
        self.assertEqual(builds, {"dark"})
        self.assertGreater(len(out), 30)
        self.assertEqual(json.loads(out["build/dark/meta.json"])["mode"], "dark")

    def test_build_light_links_to_dark(self):
        p = self.run_render("deep", "-q")
        self.assertEqual(p.returncode, 0, p.stderr)
        light = self.rice / "build/light"
        self.assertTrue(light.is_symlink())
        self.assertEqual(os.readlink(light), "dark")
        self.assertEqual((light / "kitty.conf").read_text(), (self.rice / "build/dark/kitty.conf").read_text())
        self.assertEqual(self.run_render("deep", "--check").returncode, 0)
        # a real light build left from before is replaced by the link
        os.unlink(light)
        (light / "old").mkdir(parents=True)
        self.assertEqual(self.run_render("deep", "--check").returncode, 1)
        self.assertEqual(self.run_render("deep", "-q").returncode, 0)
        self.assertTrue(light.is_symlink())
        # a rice with both modes keeps two real builds
        self.assertEqual(self.run_render("nacre", "-q").returncode, 0)
        self.assertFalse((self.rices / "nacre/build/light").is_symlink())

    def test_meta_says_which_mode_it_keeps(self):
        meta = json.loads(self.outputs()["build/dark/meta.json"])
        self.assertEqual(meta["fixed_mode"], "dark")
        self.assertEqual(meta["modes"]["light"], meta["modes"]["dark"])
        self.assertNotIn("fixed_mode", json.loads(Modes.outputs(self, self.rices / "nacre")["build/dark/meta.json"]))

    def test_the_installed_theme_carries_the_dark_palette_twice(self):
        theme = self.outputs()[str(self.home / ".config/quickshell/deep/Theme.qml")].decode()
        light = re.search(r"lightPalette: \(\{(.*?)\}\)", theme, re.S)[1]
        dark = re.search(r"darkPalette: \(\{(.*?)\}\)", theme, re.S)[1]
        self.assertEqual(light, dark)
        self.assertIn('"bg": "#18171e"', dark)

    def test_its_own_dark_template_needs_no_light_twin(self):
        tpl = self.rice / "templates/notes"
        tpl.mkdir()
        (tpl / "pad@dark.conf").write_text("{{ mode }} {{ roles.bg }}\n")
        self.assertEqual(self.outputs()["build/dark/notes/pad.conf"], b"dark #18171e\n")
        # every template still has a dark version
        (tpl / "pad@dark.conf").rename(tpl / "pad@light.conf")
        with self.assertRaisesRegex(rr.RenderError, r"pad@light.conf: has no dark twin"):
            self.outputs()
        # and a rice with both modes still needs both twins
        (tpl / "pad@light.conf").unlink()
        mine = self.rices / "nacre/templates/notes"
        mine.mkdir()
        (mine / "pad@dark.conf").write_text("x\n")
        with self.assertRaisesRegex(rr.RenderError, r"pad@dark.conf: has no light twin"):
            self.outputs(self.rices / "nacre")

    def test_shared_templates_still_come_in_pairs(self):
        shared = Path(self.tmp.name) / "shared"
        shutil.copytree(TEMPLATES, shared)
        (shared / "only@dark.conf").write_text("x\n")
        rr.SHARED = shared
        with self.assertRaisesRegex(rr.RenderError, r"only@dark.conf: has no light twin"):
            self.outputs()

    def test_bad_declarations_are_explained(self):
        palette = self.rice / "palette.toml"
        text = palette.read_text()
        palette.write_text(text.replace('modes         = ["dark"]', 'modes         = ["dusk"]'))
        with self.assertRaisesRegex(rr.RenderError, r"modes = \['dusk'\]"):
            rr.load_modes(self.rice)
        palette.write_text(text.replace('modes         = ["dark"]', 'modes         = ["light"]'))
        with self.assertRaisesRegex(rr.RenderError, r"no \[modes.light.\*\] tables"):
            rr.load_modes(self.rice)
        nacre = (self.rices / "nacre/palette.toml").read_text()
        palette.write_text(nacre.replace("[meta]\n", '[meta]\nmodes = ["dark"]\n', 1))
        with self.assertRaisesRegex(rr.RenderError, r"\[modes.light.\*\] tables, but \[meta\] modes"):
            rr.load_modes(self.rice)

    def test_the_active_link_reaches_the_dark_build_by_day(self):
        self.assertEqual(self.run_render("deep", "-q").returncode, 0)
        (self.rices / "current").symlink_to(self.rice)
        env = dict(os.environ, RICE_DIR=str(self.rices), RICE_TEMPLATES=str(TEMPLATES),
                   RICE_INSTALL_ROOT=str(self.home), HOME=str(self.home),
                   XDG_DATA_HOME=str(self.home / "data"), XDG_STATE_HOME=str(self.home / "state"),
                   PATH="/usr/bin:/bin")
        (self.home / "state/rice").mkdir(parents=True)
        (self.home / "state/rice/mode").write_text("light\n")
        p = subprocess.run([sys.executable, str(SCRIPT), "--link"], env=env, capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        active = self.home / "data/rice/active"
        self.assertTrue(str(os.readlink(active)).endswith("current/build/light"))
        self.assertEqual(active.resolve(), (self.rice / "build/dark").resolve())

    def test_the_chooser_gives_it_no_sun_or_moon(self):
        chooser = (REPO / "quickshell/.config/quickshell/rice/Chooser.qml").read_text()
        self.assertIn("visible: !slot.modelData.meta?.fixed_mode", chooser)
        self.assertIn("slot.modelData.meta?.fixed_mode ?? (Theme.dark", chooser)
        mode = (REPO / "quickshell/.config/quickshell/rice/Mode.qml").read_text()
        self.assertIn('property string only: ""', mode)
        self.assertIn("if (only)\n            m = only;", mode)
