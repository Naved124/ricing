"""Runs rice-rec with a fake wf-recorder (waits for SIGINT, then writes its -f
file), hyprctl, jq, pactl, qs and notify-send, and checks start, status, the
file in ~/Videos, the shell being told, and toggle stopping a recording."""

import os
import stat
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REC = REPO / "switcher/.local/bin/rice-rec"

LOG = '#!/bin/sh\necho "$(basename "$0") $*" >> "$RICE_TEST_LOG"\n'
FAKES = {
    "wf-recorder": LOG + r"""
out=""
while [ $# -gt 0 ]; do [ "$1" = -f ] && out=$2; shift; done
trap 'echo video > "$out"; exit 0' INT
while :; do sleep 0.05; done
""",
    "hyprctl": LOG + "echo '[{\"name\":\"eDP-1\",\"focused\":true}]'\n",
    "pactl": LOG + "echo alsa_output.speakers\n",
    "qs": LOG,
    "notify-send": LOG,
    "xdg-open": LOG,
}


class RiceRec(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.home, bin_, run = t / "home", t / "bin", t / "run"
        for d in (self.home, bin_, run):
            d.mkdir()
        palette = self.home / ".config/rices/current/palette.toml"
        palette.parent.mkdir(parents=True)
        palette.write_text('[meta]\nshell = "nacre"\n')
        for name, body in FAKES.items():
            p = bin_ / name
            p.write_text(body)
            p.chmod(p.stat().st_mode | stat.S_IXUSR)
        self.log = t / "calls.log"
        self.env = dict(os.environ, HOME=str(self.home), XDG_RUNTIME_DIR=str(run),
                        PATH=f"{bin_}:/usr/bin:/bin", RICE_TEST_LOG=str(self.log))
        self.env.pop("XDG_VIDEOS_DIR", None)
        self.env.pop("RICE_REC_DIR", None)

    def tearDown(self):
        subprocess.run([str(REC), "stop"], env=self.env, capture_output=True)
        self.tmp.cleanup()

    def rec(self, *args):
        return subprocess.run([str(REC), *args], env=self.env, capture_output=True, text=True, timeout=30)

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_records_to_videos_and_tells_the_shell(self):
        self.assertEqual(self.rec("status").stdout.strip(), "idle")
        p = self.rec("toggle")
        self.assertEqual(p.returncode, 0, p.stderr)
        status = self.rec("status")
        self.assertEqual(status.returncode, 0)
        self.assertTrue(status.stdout.startswith("recording "), status.stdout)
        rec = next(c for c in self.calls() if c.startswith("wf-recorder"))
        self.assertIn("-o eDP-1", rec)
        self.assertIn("--audio=alsa_output.speakers.monitor", rec)
        self.assertIn("qs -c nacre ipc call shell recording true", self.calls())

        time.sleep(0.2)
        p = self.rec("toggle")                     # a second toggle stops
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.rec("status").stdout.strip(), "idle")
        files = list((self.home / "Videos").glob("Recording_*.mp4"))
        self.assertEqual(len(files), 1)
        self.assertEqual(files[0].read_text(), "video\n")
        self.assertIn("qs -c nacre ipc call shell recording false", self.calls())
        self.assertEqual(sum(c.startswith("wf-recorder") for c in self.calls()), 1)

    def test_stale_state_is_ignored(self):
        state = Path(self.env["XDG_RUNTIME_DIR"]) / "rice/rec"
        state.parent.mkdir(parents=True)
        state.write_text("999999 0 /nowhere.mp4\n")
        self.assertEqual(self.rec("status").stdout.strip(), "idle")
        self.assertFalse(state.exists())


if __name__ == "__main__":
    unittest.main()
