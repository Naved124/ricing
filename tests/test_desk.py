"""Desk: desk-sync's config, sync, write path and the shells' widget."""
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DESK = REPO / "desk"
CONFIG = DESK / ".config/desk/config.toml"
sys.path.insert(0, str(DESK / ".local/lib/desk"))

from desksync import config  # noqa: E402

UUID = re.compile(r"^[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}$")


class Config(unittest.TestCase):
    def test_the_shipped_config_loads(self):
        cfg = config.load(CONFIG)
        for name in ("today", "jobs", "countdowns", "ideas"):
            self.assertRegex(cfg.source(name), UUID)
        self.assertRegex(cfg.brief, UUID)
        self.assertRegex(cfg.notion["version"], r"^\d{4}-\d\d-\d\d$")

    def test_paths_follow_xdg(self):
        with tempfile.TemporaryDirectory() as t:
            env = {"XDG_CACHE_HOME": f"{t}/c", "XDG_STATE_HOME": f"{t}/s"}
            old = {k: os.environ.get(k) for k in env}
            os.environ.update(env)
            try:
                cfg = config.load(CONFIG)
            finally:
                for k, v in old.items():
                    os.environ.pop(k, None) if v is None else os.environ.__setitem__(k, v)
            self.assertEqual(cfg.cache_file, Path(t, "c/desk/state.json"))
            self.assertEqual(cfg.queue_file, Path(t, "s/desk/queue.json"))

    def test_a_missing_key_is_named(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t, "c.toml")
            p.write_text(CONFIG.read_text().replace('today = "1dfb', 'tday = "1dfb'))
            with self.assertRaisesRegex(config.ConfigError, r"\[sources\] today"):
                config.load(p)

    def test_desk_sync_runs(self):
        r = subprocess.run([str(DESK / ".local/bin/desk-sync"), "check"], capture_output=True, text=True,
                           env={**os.environ, "DESK_CONFIG": str(CONFIG)})
        self.assertEqual(r.returncode, 0, r.stderr)


class Hooks(unittest.TestCase):
    def test_install_links_desk(self):
        self.assertRegex((REPO / "install").read_text(), r"(?m)^packages=\(.*\bdesk\b")

    def test_the_pre_commit_hook_runs_gitleaks(self):
        hook = REPO / ".githooks/pre-commit"
        self.assertTrue(os.access(hook, os.X_OK))
        self.assertIn("gitleaks", hook.read_text())


if __name__ == "__main__":
    unittest.main()
