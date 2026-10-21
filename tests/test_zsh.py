"""Sources zsh/.config/zsh/rice.zsh in a scratch HOME (no plugins or starship
needed) and checks it loads the rice's colours and follows a rice or mode switch."""

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
                for mode, c in (("light", colour), ("dark", colour[:-2] + "dd")):
                    (rices / name / "build" / mode).mkdir(parents=True)
                    (rices / name / "build" / mode / "zsh.zsh").write_text(
                        f"typeset -gA ZSH_HIGHLIGHT_STYLES\nZSH_HIGHLIGHT_STYLES[command]='fg={c}'\n")
            (rices / "current").symlink_to("one")
            active = home / ".local/share/rice/active"
            active.parent.mkdir(parents=True)
            active.symlink_to(rices / "current/build/light")
            script = (f"source {RICE_ZSH}; print -r -- $ZSH_HIGHLIGHT_STYLES[command]; "
                      "ln -sfn two ~/.config/rices/current; _rice_colours_reload; "
                      "print -r -- $ZSH_HIGHLIGHT_STYLES[command]; "
                      f"ln -sfn {rices}/current/build/dark {active}; _rice_colours_reload; "
                      "print -r -- $ZSH_HIGHLIGHT_STYLES[command]")
            p = subprocess.run(["zsh", "-f", "-i", "-c", script], capture_output=True, text=True,
                               env=dict(os.environ, HOME=str(home), ZDOTDIR=str(home),
                                        XDG_DATA_HOME=str(home / ".local/share")), timeout=30)
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertEqual(p.stdout.split(), ["fg=#111111", "fg=#222222", "fg=#2222dd"], p.stderr)


if __name__ == "__main__":
    unittest.main()
