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


if __name__ == "__main__":
    unittest.main()
