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


# a hyprctl that keeps the loaded plugins in a file and logs every call;
# GG_FAKE_PAUSED names a plugin that loads paused (built for another Hyprland)
HYPRCTL = r"""#!/bin/bash
d="$GG_FAKE_HYPR"; touch "$d/loaded"
echo "$*" >> "$d/calls"
name() { case "$(basename "$1")" in hyprglass.so) echo hyprglass ;; libhyprliquid.so) echo hyprliquid ;; esac; }
[[ "$1" == -j ]] && shift
case "$1 $2" in
    "plugin list")
        jq -R -s --arg p "${GG_FAKE_PAUSED:-}" 'split("\n") | map(select(. != "")) | map({name: ., version: "1",
            description: (if . == $p then "Paused (hyprland_version): built for Hyprland 0.56, running 0.57" else "glass" end)})' "$d/loaded" ;;
    "plugin load") n="$(name "$3")"; grep -qx "$n" "$d/loaded" || echo "$n" >> "$d/loaded"; echo ok ;;
    "plugin unload") n="$(name "$3")"; grep -vx "$n" "$d/loaded" > "$d/l2"; mv "$d/l2" "$d/loaded"; echo ok ;;
    "hyprglass status") echo '{"schema":1,"active":true,"shaders":"ready"}' ;;
    *) echo ok ;;
esac
"""


@unittest.skipUnless(shutil.which("jq"), "jq not installed")
class Glass(unittest.TestCase):
    """gg glass: Liquid through a plugin it loads itself, Frosted when it can't."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.root = root
        self.hypr = root / "hypr"
        self.hypr.mkdir()
        rices = root / "rices"
        (rices / "goldengate").mkdir(parents=True)
        (rices / "current").symlink_to("goldengate")              # on screen
        bin_ = root / "bin"
        bin_.mkdir()
        (bin_ / "hyprctl").write_text(HYPRCTL)
        (bin_ / "hyprctl").chmod(0o755)
        for name in ("rice", "rice-render", "gg-theme", "gsettings"):      # recolour's, not under test
            (bin_ / name).write_text("#!/bin/sh\nexit 0\n")
            (bin_ / name).chmod(0o755)
        for so in ("hyprglass.so", "libhyprliquid.so"):
            (root / so).write_text("")
        active = root / "data/rice/active"
        active.mkdir(parents=True)
        (active / "glass.lua").write_text("-- rendered\n")
        self.env = {
            "PATH": f"{bin_}:/usr/bin:/bin", "HOME": str(root), "RICE_DIR": str(rices),
            "XDG_CONFIG_HOME": str(root / "config"), "XDG_STATE_HOME": str(root / "state"),
            "XDG_DATA_HOME": str(root / "data"), "GG_FAKE_HYPR": str(self.hypr),
            "GG_HYPRGLASS": str(root / "hyprglass.so"), "GG_HYPRLIQUID": str(root / "libhyprliquid.so"),
        }

    def tearDown(self):
        self.tmp.cleanup()

    def gg(self, *args, **env):
        r = subprocess.run([str(GG), *args], env={**self.env, **env}, capture_output=True, text=True, timeout=60)
        self.assertEqual(r.returncode, 0, r.stderr)
        # never two glass plugins at once
        self.assertLessEqual(len(self.loaded()), 1, self.loaded())
        return r

    def loaded(self):
        return (self.hypr / "loaded").read_text().split() if (self.hypr / "loaded").exists() else []

    def calls(self):
        return (self.hypr / "calls").read_text() if (self.hypr / "calls").exists() else ""

    def state(self):
        return json.loads((self.root / "state/goldengate/glass.json").read_text())

    def test_liquid_loads_hyprglass_and_sends_the_glass(self):
        self.gg("glass", "liquid")
        self.assertEqual(self.loaded(), ["hyprglass"])
        self.assertEqual((self.state()["mode"], self.state()["backend"], self.state()["reason"]), ("liquid", "hyprglass", ""))
        self.assertIn(f"eval dofile([[{self.root}/data/rice/active/glass.lua]])", self.calls())
        lua = (self.root / "state/goldengate/glass-state.lua").read_text()
        self.assertIn('mode = "liquid", backend = "hyprglass", clarity = 0.35', lua)

    def test_frosted_and_solid_load_nothing(self):
        self.gg("glass", "liquid")
        for mode in ("frosted", "solid"):
            self.gg("glass", mode)
            self.assertEqual(self.loaded(), [])
            self.assertEqual(self.state()["mode"], mode)
        # Reduce transparency is Solid, whatever the glass says
        self.gg("glass", "liquid")
        self.gg("set", "accessibility.reduceTransparency", "true")
        self.assertEqual((self.state()["mode"], self.loaded()), ("solid", []))

    def test_a_paused_hyprglass_falls_back(self):
        # auto: hyprliquid stands in
        self.gg("glass", "liquid", GG_FAKE_PAUSED="hyprglass")
        self.assertEqual((self.state()["backend"], self.loaded()), ("hyprliquid", ["hyprliquid"]))
        # hyprglass only: Frosted, with the reason for the shell's banner
        self.gg("glass", "backend", "hyprglass", GG_FAKE_PAUSED="hyprglass")
        s = self.state()
        self.assertEqual((s["want"], s["mode"], s["backend"], self.loaded()), ("liquid", "frosted", "hyprland", []))
        self.assertIn("paused", s["reason"])
        # hyprliquid's rules outlived it: Hyprland was reloaded to clear them
        self.assertIn("reload", self.calls())

    def test_a_missing_plugin_falls_back(self):
        os.remove(self.root / "hyprglass.so")
        os.remove(self.root / "libhyprliquid.so")
        self.gg("glass", "liquid")
        self.assertEqual((self.state()["mode"], self.state()["reason"]),
                         ("frosted", "hyprglass isn't installed; hyprliquid isn't installed"))

    def test_clarity_is_live(self):
        self.gg("glass", "liquid")
        (self.hypr / "calls").write_text("")
        self.gg("glass", "clarity", "0.8")
        self.assertIn("GG_GLASS_LIVE = true", self.calls())
        self.assertNotIn("reload", self.calls())
        self.assertNotIn("plugin load", self.calls())
        self.assertEqual(self.state()["clarity"], 0.8)
        r = subprocess.run([str(GG), "glass", "clarity", "2"], env=self.env, capture_output=True, text=True)
        self.assertNotEqual(r.returncode, 0)

    def test_leaving_unloads_the_plugins(self):
        self.gg("glass", "liquid")
        self.gg("hook", "leave", "paper")
        self.assertEqual(self.loaded(), [])

    def test_off_screen_it_only_remembers(self):
        (Path(self.env["RICE_DIR"]) / "current").unlink()
        (Path(self.env["RICE_DIR"]) / "current").symlink_to("paper")
        self.gg("glass", "frosted")
        self.assertEqual(self.calls(), "")


def has_pyside():
    return importlib.util.find_spec("PySide6") is not None


@unittest.skipUnless(has_pyside(), "needs PySide6")
class Shell(unittest.TestCase):
    """The shell starts clean against the Quickshell stand-ins, and wears the glass gg reports."""

    def test_it_starts_clean_and_follows_the_glass(self):
        import sys
        sys.path.insert(0, str(REPO / "tests"))
        import qs_smoke
        found, pokes = qs_smoke.smoke(SHELL, 3, REPO / "tests/pokes/goldengate-glass.qml")
        self.assertEqual(found, [])
        by = {p["state"]: p for p in pokes}
        self.assertEqual(set(by), {"liquid", "fell back", "solid"}, pokes)
        self.assertEqual((by["liquid"]["glass"], by["liquid"]["plugin"]), ("liquid", True))
        # under a plugin the shadow stays out of its mask (0.06)
        self.assertLess(by["liquid"]["shadow"], 0.06)
        self.assertEqual((by["fell back"]["glass"], by["fell back"]["plugin"], by["fell back"]["fellBack"]),
                         ("frosted", False, True))
        self.assertGreater(by["fell back"]["shadow"], 0.1)
        self.assertEqual((by["solid"]["glass"], by["solid"]["tint"]), ("solid", 1))


@unittest.skipUnless(shutil.which("lua"), "lua not installed")
class GlassLua(unittest.TestCase):
    """The rendered glass.lua against a stub of Hyprland's `hl`."""

    STUB = r"""
calls = {}
local function rec(name) return function(...) table.insert(calls, { name, ... }) end end
hl = { config = rec("config"), layer_rule = rec("layer_rule"), plugin = {} }
if PLUGIN == "hyprglass" then
    hl.plugin.hyprglass = { config = rec("hg.config"), layer = rec("hg.layer"), preset = rec("hg.preset") }
elseif PLUGIN == "hyprliquid" then
    hl.plugin.hyprliquid = {}
end
dofile(GLASS)
local function dump(v)
    if type(v) ~= "table" then return tostring(v) end
    local keys, out = {}, {}
    for k in pairs(v) do table.insert(keys, tostring(k)) end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local val = v[k] if val == nil then val = v[tonumber(k)] end
        table.insert(out, k .. "=" .. dump(val))
    end
    return "{" .. table.concat(out, ",") .. "}"
end
for _, c in ipairs(calls) do print(c[1], dump(c[2]), dump(c[3])) end
"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        ctx = rr.load_modes(RICE)
        src = (RICE / "templates/glass.lua").read_text()
        self.lua = {m: rr.render_text(src, ctx[m], "glass.lua") for m in ("light", "dark")}
        (self.root / "glass.lua").write_text(self.lua["light"])
        (self.root / "goldengate").mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def run_lua(self, state, plugin="", live=False):
        (self.root / "goldengate/glass-state.lua").write_text(f"return {state}\n")
        pre = f'GLASS = [[{self.root}/glass.lua]]; PLUGIN = "{plugin}"; ' + ("GG_GLASS_LIVE = true; " if live else "")
        r = subprocess.run(["lua", "-e", pre + self.STUB], capture_output=True, text=True,
                           env={**os.environ, "XDG_STATE_HOME": str(self.root)})
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout

    def test_it_renders_the_same_in_both_modes(self):
        self.assertEqual(self.lua["light"], self.lua["dark"])

    def test_liquid_glasses_the_shells_panels(self):
        out = self.run_lua('{ mode = "liquid", backend = "hyprglass", clarity = 0.35, menubar = false }', "hyprglass")
        self.assertIn("hg.config", out)
        self.assertIn("enabled=true", out.split("hg.config")[1])
        layers = [l for l in out.splitlines() if l.startswith("hg.layer")]
        names = {l.split()[1] for l in layers}
        self.assertEqual(names, {f"goldengate:{n}" for n in
                                 ("dock", "controlcenter", "notifications", "widgets", "spotlight", "osd")})
        self.assertTrue(all("mask_mode=contour" in l for l in layers))
        # the menu bar only with its background: else the glass would sit on its letters
        out = self.run_lua('{ mode = "liquid", backend = "hyprglass", clarity = 0.35, menubar = true }', "hyprglass")
        self.assertIn("hg.layer\tgoldengate:menubar\t{mask_mode=alpha", out)

    def test_a_clarity_change_adds_no_rules(self):
        out = self.run_lua('{ mode = "liquid", backend = "hyprglass", clarity = 0.9 }', "hyprglass", live=True)
        self.assertIn("hg.preset", out)
        self.assertNotIn("hg.layer", out)
        out = self.run_lua('{ mode = "liquid", backend = "hyprliquid", clarity = 0.9 }', "hyprliquid", live=True)
        self.assertNotIn("layer_rule", out)

    def test_frosted_and_solid(self):
        frosted = self.run_lua('{ mode = "frosted", backend = "hyprland", clarity = 0 }')
        self.assertIn("enabled=true", frosted)
        self.assertIn("size=5", frosted)
        self.assertIn("size=12", self.run_lua('{ mode = "frosted", backend = "hyprland", clarity = 1 }'))
        self.assertIn("enabled=false", self.run_lua('{ mode = "solid", backend = "hyprland", clarity = 0.5 }'))
        # a plugin that isn't there is never configured
        self.assertNotIn("hg.", self.run_lua('{ mode = "liquid", backend = "hyprglass", clarity = 0.5 }'))

    def test_hyprliquid_rules_every_panel(self):
        out = self.run_lua('{ mode = "liquid", backend = "hyprliquid", clarity = 0.35 }', "hyprliquid")
        rules = [l for l in out.splitlines() if l.startswith("layer_rule")]
        self.assertEqual(len(rules), 6)
        self.assertTrue(all("hyprliquid:effect=liquid_glass" in r for r in rules))


if __name__ == "__main__":
    unittest.main()
