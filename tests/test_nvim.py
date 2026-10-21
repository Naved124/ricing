"""nvim follows `rice mode` by itself: the rendered nvim/mode.lua watches
~/.local/state/rice and re-applies the colourscheme, whose link now leads to
the other mode's build. Runs a headless nvim; skipped without one."""

import importlib.machinery
import importlib.util
import os
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCRIPT = REPO / "render/.local/bin/rice-render"
MODE_LUA = REPO / "render/.local/share/rice/templates/nvim/mode.lua"
NVIM = shutil.which("nvim")

loader = importlib.machinery.SourceFileLoader("rice_render_nvim", str(SCRIPT))
spec = importlib.util.spec_from_loader("rice_render_nvim", loader)
rr = importlib.util.module_from_spec(spec)
loader.exec_module(rr)

# a colourscheme per mode that says which one it is, and starts the watcher
SCHEME = """vim.cmd("highlight clear")
vim.g.colors_name = "rice"
vim.o.background = "{mode}"
pcall(function() require("rice.mode").watch() end)
"""


@unittest.skipUnless(NVIM, "nvim not installed")
class NvimFollowsTheMode(unittest.TestCase):
    def test_background_follows_the_state_file(self):
        with tempfile.TemporaryDirectory() as d:
            home = Path(d)
            ctx = rr.load_palette(REPO / "rices/.config/rices/nacre")
            mode_lua = rr.render_text(MODE_LUA.read_text(), ctx, "nvim/mode.lua")
            for mode in ("light", "dark"):
                build = home / "build" / mode / "nvim"
                build.mkdir(parents=True)
                (build / "rice.lua").write_text(SCHEME.format(mode=mode))
                (build / "mode.lua").write_text(mode_lua)
            active = home / ".local/share/rice/active"
            active.parent.mkdir(parents=True)
            active.symlink_to(home / "build/light")
            state = home / ".local/state/rice"
            state.mkdir(parents=True)
            (state / "mode").write_text("light\n")
            nvim = home / ".config/nvim"
            (nvim / "colors").mkdir(parents=True)
            (nvim / "lua/rice").mkdir(parents=True)
            (nvim / "colors/rice.lua").symlink_to(active / "nvim/rice.lua")
            (nvim / "lua/rice/mode.lua").symlink_to(active / "nvim/mode.lua")
            out = home / "seen"

            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"),
                       XDG_STATE_HOME=str(home / ".local/state"), XDG_DATA_HOME=str(home / ".local/share"))
            # note the background now, wait for the switch below, note it again
            probe = (f"lua vim.fn.writefile({{vim.o.background}}, '{out}');"
                     f" vim.defer_fn(function() vim.fn.writefile({{vim.o.background}}, '{out}', 'a');"
                     " vim.cmd('qa!') end, 2500)")
            proc = subprocess.Popen([NVIM, "--headless", "-u", "NONE", "-i", "NONE",
                                     "--cmd", f"set rtp^={nvim}", "-c", "colorscheme rice", "-c", probe],
                                    env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            for _ in range(50):          # wait for nvim to start watching
                if out.exists():
                    break
                time.sleep(0.05)
            # what `rice mode dark` does: re-point active, rename a new file over mode
            tmp = home / ".local/share/rice/.active.tmp"
            tmp.symlink_to(home / "build/dark")
            os.replace(tmp, active)
            (state / ".mode.tmp").write_text("dark\n")
            os.replace(state / ".mode.tmp", state / "mode")
            _, err = proc.communicate(timeout=20)
            self.assertEqual(out.read_text().split(), ["light", "dark"], err.decode())


if __name__ == "__main__":
    unittest.main()
