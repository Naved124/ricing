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
        args = [HYPRLAND, "--verify-config", "-c", str(self.home / ".config/hypr/hyprland.lua")]
        if os.geteuid() == 0:
            args.insert(1, "--i-am-really-stupid")
        out = subprocess.run(args, env=self.env, capture_output=True, text=True).stdout
        return out.split("Config parsing result:", 1)[-1].strip()

    def test_each_rice(self):
        for rice in ("nacre", "urushi", "paper"):
            with self.subTest(rice):
                self.assertEqual(self.verify(rice), "config ok")

    def test_without_an_active_rice(self):
        self.assertEqual(self.verify("does-not-exist"), "config ok")


if __name__ == "__main__":
    unittest.main()
