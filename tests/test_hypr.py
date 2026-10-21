"""Checks every rice's Hyprland config with the real parser (`Hyprland --verify-config`).

Skipped when Hyprland isn't installed. Set HYPRLAND_BIN to use a specific binary.
"""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
HYPRLAND = os.environ.get("HYPRLAND_BIN") or shutil.which("Hyprland")
MIGRATE = REPO / "tools/hypr-migrate"


@unittest.skipUnless(HYPRLAND, "Hyprland not installed")
class VerifyConfig(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.home = Path(cls.tmp.name)
        cfg = cls.home / ".config"
        shutil.copytree(REPO / "hypr/.config/hypr", cfg / "hypr")
        shutil.copytree(REPO / "rices/.config/rices", cfg / "rices",
                        ignore=shutil.ignore_patterns("build", "current"))
        runtime = cls.home / "run"
        runtime.mkdir(mode=0o700)
        cls.env = dict(os.environ, HOME=str(cls.home), XDG_CONFIG_HOME=str(cfg),
                       XDG_RUNTIME_DIR=str(runtime),
                       RICE_TEMPLATES=str(REPO / "render/.local/share/rice/templates"))
        subprocess.run([str(REPO / "render/.local/bin/rice-render"), "--all", "-q"],
                       env=cls.env, check=True)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def verify(self, rice: str) -> str:
        current = self.home / ".config/rices/current"
        if current.is_symlink():
            current.unlink()
        current.symlink_to(rice)
        active = self.home / ".local/share/rice/active"
        if not active.is_symlink():
            active.parent.mkdir(parents=True, exist_ok=True)
            active.symlink_to(current / "build/light")
        args = [HYPRLAND, "--verify-config", "-c", str(self.home / ".config/hypr/hyprland.lua")]
        if os.geteuid() == 0:
            args.insert(1, "--i-am-really-stupid")
        out = subprocess.run(args, env=self.env, capture_output=True, text=True).stdout
        return out.split("Config parsing result:", 1)[-1].strip()

    def test_each_rice(self):
        for rice in ("nacre", "paper"):
            with self.subTest(rice):
                self.assertEqual(self.verify(rice), "config ok")

    def test_without_an_active_rice(self):
        self.assertEqual(self.verify("does-not-exist"), "config ok")

    def test_migrated_local_lua(self):
        old = self.home / "old.conf"
        old.write_text(SAMPLE_CONF)
        local = self.home / ".config/hypr/local.lua"
        subprocess.run([str(MIGRATE), str(old), str(local)], check=True, capture_output=True)
        try:
            self.assertIn("hl.monitor(", local.read_text())
            self.assertEqual(self.verify("nacre"), "config ok")
        finally:
            local.unlink()


SAMPLE_CONF = """\
monitor=eDP-1,1920x1080@60,0x0,1  # laptop
monitor = HDMI-A-1, 2560x1440@144, 1920x0, 1.25, transform, 1, vrr, 1
monitor=DP-2,disable
monitor=,preferred,auto,auto
monitor=DP-3,addreserved,10,0,0,0
monitor=DP-4,preferred,auto,1,nonsense,3
input {
    kb_layout = us,in
    kb_options = grp:alt_shift_toggle
    touchpad {
        natural_scroll = true
    }
}
"""


LUA = shutil.which("lua5.4") or shutil.which("lua")

# a stand-in `hl` that accepts any call, so the config runs as plain Lua
HL_STUB = r"""
local function any() return setmetatable({}, { __index = function() return any() end, __call = function() return any() end }) end
hl = setmetatable({ get = function() return "dwindle" end }, { __index = function() return any() end })
dofile(arg[1])
"""


@unittest.skipUnless(LUA, "lua not installed")
class LuaSmoke(unittest.TestCase):
    """Without Hyprland, at least run every rice's rendered Lua (syntax, nil calls)."""

    def test_every_rice_runs(self):
        with tempfile.TemporaryDirectory() as d:
            rices = Path(d) / "rices"
            shutil.copytree(REPO / "rices/.config/rices", rices, ignore=shutil.ignore_patterns("build", "current"))
            env = dict(os.environ, RICE_DIR=str(rices), HOME=d, RICE_INSTALL_ROOT=d,
                       RICE_TEMPLATES=str(REPO / "render/.local/share/rice/templates"))
            subprocess.run([str(REPO / "render/.local/bin/rice-render"), "--all", "-q"], env=env, check=True)
            stub = Path(d) / "stub.lua"
            stub.write_text(HL_STUB)
            files = [REPO / "hypr/.config/hypr/base.lua"] + sorted(rices.glob("*/build/*/hypr*.lua"))
            self.assertGreaterEqual(len(files), 9)   # base.lua; each rice's hypr.lua and hypr-mode.lua (what `rice mode` evals), both modes
            for f in files:
                with self.subTest(f"{f.parent.parent.parent.name} {f.parent.name} {f.name}"):
                    r = subprocess.run([LUA, str(stub), str(f)], capture_output=True, text=True, env=env)
                    self.assertEqual(r.returncode, 0, r.stderr)


class Migrate(unittest.TestCase):
    def run_migrate(self, conf: str, *extra: str) -> str:
        with tempfile.TemporaryDirectory() as d:
            old = Path(d) / "hyprland.conf"
            old.write_text(conf)
            return subprocess.run([str(MIGRATE), str(old), *extra], check=True,
                                  capture_output=True, text=True).stdout

    def test_translates_monitors_and_keyboard(self):
        out = self.run_migrate(SAMPLE_CONF)
        self.assertIn('hl.monitor({ output = "eDP-1", mode = "1920x1080@60", '
                      'position = "0x0", scale = 1 })', out)
        self.assertIn("scale = 1.25, transform = 1, vrr = 1", out)
        self.assertIn('hl.monitor({ output = "DP-2", disabled = true })', out)
        self.assertIn('scale = "auto"', out)
        self.assertIn("reserved_area = { top = 10, bottom = 0, left = 0, right = 0 }", out)
        self.assertIn("-- couldn't translate (nonsense)", out)
        self.assertIn('kb_layout = "us,in", kb_options = "grp:alt_shift_toggle"', out)
        self.assertNotIn("natural_scroll", out)

    def test_follows_source(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "monitors.conf").write_text("monitor=DP-1,preferred,auto,2\n")
            old = Path(d) / "hyprland.conf"
            old.write_text("source = ./monitors.conf\n")
            out = subprocess.run([str(MIGRATE), str(old)], capture_output=True, text=True).stdout
        self.assertIn('output = "DP-1"', out)

    def test_leaves_a_local_lua_with_monitors_alone(self):
        with tempfile.TemporaryDirectory() as d:
            local = Path(d) / "local.lua"
            local.write_text('hl.monitor({ output = "X", scale = 2 })\n')
            self.run_migrate(SAMPLE_CONF, str(local))
            self.assertEqual(local.read_text(), 'hl.monitor({ output = "X", scale = 2 })\n')


if __name__ == "__main__":
    unittest.main()
