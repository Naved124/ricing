"""Sources zsh/.config/zsh/rice.zsh in a scratch HOME (no plugins or starship
needed) and checks it loads the rice's colours and follows a rice switch."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RICE_ZSH = REPO / "zsh/.config/zsh/rice.zsh"


@unittest.skipUnless(shutil.which("zsh"), "zsh isn't installed")
class RiceZsh(unittest.TestCase):
    def test_loads_colours_and_follows_a_switch(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            rices = home / ".config/rices"
            for name, colour in (("one", "#111111"), ("two", "#222222")):
                (rices / name / "build").mkdir(parents=True)
                (rices / name / "build/zsh.zsh").write_text(
                    f"typeset -gA ZSH_HIGHLIGHT_STYLES\nZSH_HIGHLIGHT_STYLES[command]='fg={colour}'\n")
            (rices / "current").symlink_to("one")
            script = (f"source {RICE_ZSH}; print -r -- $ZSH_HIGHLIGHT_STYLES[command]; "
                      "ln -sfn two ~/.config/rices/current; _rice_colours_reload; "
                      "print -r -- $ZSH_HIGHLIGHT_STYLES[command]")
            p = subprocess.run(["zsh", "-f", "-i", "-c", script], capture_output=True, text=True,
                               env=dict(os.environ, HOME=str(home), ZDOTDIR=str(home)), timeout=30)
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertEqual(p.stdout.split(), ["fg=#111111", "fg=#222222"], p.stderr)


if __name__ == "__main__":
    unittest.main()
