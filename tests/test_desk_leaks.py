"""Desk: the Notion credential never leaves the keyring and desk-sync's memory.

The repo, the cache, the queue and desk-sync's output must hold nothing
shaped like a Notion secret (the `ntn_` / `secret_` prefixes).
"""
import io
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

from desksync import secret  # noqa: E402
from desksync.log import log  # noqa: E402

LEAK = re.compile(r"\b(?:ntn|secret)_[A-Za-z0-9]{20,}")
# built at run time so this file holds no such string itself
FAKE = "ntn" + "_" + "T3stOnlyN0tAR3alS3cr3t0123456789abcdef"


def leaks(text: str) -> list[str]:
    return LEAK.findall(text)


class FakeKeyring:
    """A secret-tool on PATH that answers with FAKE, or fails like a locked keyring."""

    def __init__(self, root: Path, mode: str = "ok"):
        self.bin = root / "bin"
        self.bin.mkdir()
        tool = self.bin / "secret-tool"
        body = {"ok": f'printf "%s\\n" "{FAKE}"',
                "locked": 'echo "Cannot get secret of a locked object" >&2; exit 1',
                "empty": "exit 1"}[mode]
        tool.write_text(f"#!/bin/sh\n{body}\n")
        tool.chmod(0o755)

    def env(self, root: Path) -> dict:
        return {**os.environ, "PATH": f"{self.bin}:{os.environ['PATH']}", "DESK_CONFIG": str(CONFIG),
                "XDG_CACHE_HOME": str(root / "cache"), "XDG_STATE_HOME": str(root / "state")}


def run_desk(env: dict, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run([str(DESK / ".local/bin/desk-sync"), *args], capture_output=True, text=True, env=env)


class Repo(unittest.TestCase):
    def test_no_tracked_file_holds_a_secret(self):
        files = subprocess.run(["git", "ls-files", "-z"], cwd=REPO, capture_output=True, check=True).stdout
        found = []
        for rel in filter(None, files.decode().split("\0")):
            p = REPO / rel
            if not p.is_file() or p.is_symlink():
                continue
            try:
                text = p.read_text(errors="ignore")
            except OSError:
                continue
            found += [f"{rel}: {m[:8]}…" for m in leaks(text)]
        self.assertEqual(found, [])


class Keyring(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def output_and_files(self, r: subprocess.CompletedProcess) -> str:
        text = r.stdout + r.stderr
        for d in (self.root / "cache", self.root / "state"):
            for p in d.rglob("*") if d.exists() else []:
                if p.is_file():
                    text += p.read_text(errors="ignore")
        return text

    def test_check_finds_it_without_printing_it(self):
        r = run_desk(FakeKeyring(self.root).env(self.root), "check")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("found in the keyring", r.stdout)
        self.assertEqual(leaks(self.output_and_files(r)), [])

    def test_a_locked_keyring_is_an_error_with_no_fallback(self):
        r = run_desk(FakeKeyring(self.root, "locked").env(self.root), "check")
        self.assertEqual(r.returncode, 1)
        self.assertIn("locked", r.stdout)

    def test_no_entry_says_how_to_store_one(self):
        r = run_desk(FakeKeyring(self.root, "empty").env(self.root), "check")
        self.assertEqual(r.returncode, 1)
        self.assertIn("secret-tool store", r.stdout)

    def test_no_secret_tool(self):
        def run(*a, **k):
            raise FileNotFoundError
        with self.assertRaisesRegex(secret.SecretError, "libsecret"):
            secret.read(run=run)

    def test_a_hung_keyring_times_out(self):
        def run(*a, **k):
            raise subprocess.TimeoutExpired(a[0], 1)
        with self.assertRaisesRegex(secret.SecretError, "locked"):
            secret.read(run=run)

    def test_it_is_never_passed_on_a_command_line(self):
        self.assertNotIn(FAKE, " ".join(secret.LOOKUP))
        src = "".join(p.read_text() for p in (DESK / ".local/lib/desk/desksync").glob("*.py"))
        # desk-sync never sets an environment variable (children would inherit it)
        self.assertNotRegex(src, r"environ\[[^\]]+\]\s*=[^=]|putenv|environ\.(update|setdefault)|env=")


class Sync(unittest.TestCase):
    def test_a_sync_writes_no_secret_into_the_cache_the_queue_or_the_log(self):
        from desksync import cli, fixtures
        from desksync.notion import Client
        seen = []

        def client_for(cfg, credential):
            seen.append(credential)
            return Client(fixtures.transport(cfg, REPO / "tests/fixtures/desk"), rate=1000, retries=0,
                          log=lambda m: log(m, err))
        with tempfile.TemporaryDirectory() as t:
            err = io.StringIO()
            env = {"DESK_CONFIG": str(CONFIG), "XDG_CACHE_HOME": f"{t}/c", "XDG_STATE_HOME": f"{t}/s",
                   "DESK_NO_KICK": "1"}
            saved = {k: os.environ.get(k) for k in env}
            os.environ.update(env)
            orig = (cli.secret.read, cli.client_for, cli.log)
            cli.secret.read, cli.client_for, cli.log = (lambda: FAKE), client_for, (lambda m: log(m, err))
            try:
                self.assertEqual(cli.main(["sync"]), 0)
                self.assertEqual(cli.main(["capture", "--", "a task"]), 0)
            finally:
                cli.secret.read, cli.client_for, cli.log = orig
                for k, v in saved.items():
                    os.environ.pop(k, None) if v is None else os.environ.__setitem__(k, v)
            self.assertEqual(seen, [FAKE])
            text = err.getvalue() + "".join(p.read_text() for p in Path(t).rglob("*") if p.is_file())
            self.assertIn("synced:", text)
            self.assertIn("a task", text, "the queue was written and read")
            self.assertEqual(leaks(text), [])


class Log(unittest.TestCase):
    def test_the_log_masks_anything_secret_shaped(self):
        out = io.StringIO()
        log(f"oops {FAKE} here", out)
        self.assertEqual(leaks(out.getvalue()), [])
        self.assertIn("[masked]", out.getvalue())


if __name__ == "__main__":
    unittest.main()
