"""Desk: desk-sync's config, sync, write path and the shells' widget."""
import os
import re
import shutil
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
        self.assertIn("config:     ok", r.stdout, r.stderr)


UNITS = REPO / "systemd/.config/systemd/user"
HARDENING = {"NoNewPrivileges": "yes", "PrivateTmp": "yes", "ProtectSystem": "strict",
             "ProtectHome": "read-only", "RestrictAddressFamilies": "AF_INET AF_INET6 AF_UNIX",
             "LockPersonality": "yes", "MemoryDenyWriteExecute": "yes"}


def unit(name: str) -> dict:
    out = {}
    for line in (UNITS / name).read_text().splitlines():
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            out.setdefault(k, []).append(v)
    return out


class Units(unittest.TestCase):
    def test_the_service_is_hardened(self):
        u = unit("desk-sync.service")
        for k, v in HARDENING.items():
            self.assertEqual(u.get(k), [v], k)
        self.assertEqual(u["ReadWritePaths"], ["%C/desk %S/desk"])
        self.assertEqual(u["ExecStart"], ["%h/.local/bin/desk-sync run"])

    def test_the_service_holds_no_credential(self):
        text = (UNITS / "desk-sync.service").read_text()
        self.assertNotRegex(text, r"(?i)(token|secret|bearer|EnvironmentFile)\s*=")
        self.assertEqual(unit("desk-sync.service").get("Environment"), ["PYTHONDONTWRITEBYTECODE=1"])

    def test_the_timer_runs_every_5_minutes(self):
        self.assertEqual(unit("desk-sync.timer")["OnUnitActiveSec"], ["5min"])
        self.assertIn("systemctl --user enable --now desk-sync.timer", (REPO / "install").read_text())

    @unittest.skipUnless(shutil.which("systemd-analyze"), "systemd-analyze needed")
    def test_the_exposure_score(self):
        with tempfile.TemporaryDirectory() as t:
            os.chmod(t, 0o700)
            r = subprocess.run(["systemd-analyze", "security", "--offline=true", "--user",
                                str(UNITS / "desk-sync.service")], capture_output=True, text=True,
                               env={**os.environ, "XDG_RUNTIME_DIR": t})
        m = re.search(r"exposure level for desk-sync.service: ([\d.]+)", r.stdout + r.stderr)
        if not m:
            self.skipTest("this systemd-analyze can't score offline")
        self.assertLessEqual(float(m.group(1)), 2.5)


class Hooks(unittest.TestCase):
    def test_install_links_desk(self):
        self.assertRegex((REPO / "install").read_text(), r"(?m)^packages=\(.*\bdesk\b")

    def test_the_pre_commit_hook_runs_gitleaks(self):
        hook = REPO / ".githooks/pre-commit"
        self.assertTrue(os.access(hook, os.X_OK))
        self.assertIn("gitleaks", hook.read_text())


if __name__ == "__main__":
    unittest.main()
