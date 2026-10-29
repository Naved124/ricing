"""Desk: desk-sync's read sync (fixtures, normalizing, the cache, stale, backoff)."""
import json
import os
import stat
import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DESK = REPO / "desk"
CONFIG = DESK / ".config/desk/config.toml"
FIXTURES = REPO / "tests/fixtures/desk"
sys.path.insert(0, str(DESK / ".local/lib/desk"))

from desksync import config, fixtures, store, sync  # noqa: E402
from desksync.config import Config  # noqa: E402
from desksync.notion import Client, NetworkError, NotionError, Response  # noqa: E402

NOW = datetime.fromisoformat("2026-10-29T09:00:00+05:30")


class FakeClock:
    def __init__(self):
        self.t = 0.0
        self.slept = []

    def clock(self):
        return self.t

    def sleep(self, s):
        self.slept.append(s)
        self.t += s


class Cached(unittest.TestCase):
    """A config whose cache and state live in a temp folder."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        base = config.load(CONFIG)
        self.cfg = Config(base.raw, root / "cache/desk", root / "state/desk")
        self.logs = []

    def tearDown(self):
        self.tmp.cleanup()

    def client(self, transport=None):
        return Client(transport or fixtures.transport(self.cfg, FIXTURES), rate=1000, retries=0,
                      log=self.logs.append)

    def good_sync(self):
        self.assertEqual(sync.run(self.cfg, self.client(), NOW, self.logs.append), 0)
        return json.loads(self.cfg.cache_file.read_text())


class Normalize(Cached):
    def test_today_order_and_what_is_left_out(self):
        today = self.good_sync()["today"]
        self.assertEqual([t["state"] for t in today], ["overdue", "today", "high", "open", "open", "done"])
        titles = [t["title"] for t in today]
        self.assertIn("Renew the bus pass", titles, "the second page of the query was read")
        self.assertNotIn("Trashed task", titles)
        self.assertNotIn("Done last week", titles)

    def test_titles_stay_text(self):
        today = self.good_sync()["today"]
        self.assertIn("<b>Fix</b> the <a href='javascript:alert(1)'>rice</a> bar", [t["title"] for t in today])

    def test_countdowns(self):
        cds = self.good_sync()["countdowns"]
        self.assertEqual([(c["event"], c["days"], c["soon"]) for c in cds],
                         [("Placement drive", 4, True), ("OS end-sem", 20, False), ("AWS SAA exam", 44, False)])
        self.assertEqual(cds[0]["link"], "https://example.org/prep")

    def test_jobs_keep_only_https_links_and_closed_last(self):
        groups = self.good_sync()["jobs"]
        self.assertEqual([g["status"] for g in groups], ["Applied", "Interviewing", "Rejected"])
        links = {j["company"]: j["link"] for g in groups for j in g["items"]}
        self.assertEqual(links, {"Postman": "https://www.postman.com/company/careers/", "AWS": None,
                                 "Razorpay": "https://razorpay.com/jobs/", "Acme": None})

    def test_brief(self):
        brief = self.good_sync()["brief"]
        self.assertEqual(brief["title"], "Daily brief · Thu 29 Oct")
        kinds = [b["kind"] for b in brief["blocks"]]
        self.assertEqual(kinds, ["h2", "p", "todo", "todo", "divider", "h3", "bullet", "quote"])
        self.assertEqual([b.get("checked") for b in brief["blocks"] if b["kind"] == "todo"], [False, True])

    def test_summary(self):
        s = self.good_sync()["summary"]
        self.assertEqual(s, {"open": 5, "overdue": 1, "next": {"event": "Placement drive", "days": 4}})


class Cache(Cached):
    def test_modes(self):
        self.good_sync()
        self.assertEqual(stat.S_IMODE(self.cfg.cache_file.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.cfg.cache_dir.stat().st_mode), 0o700)
        self.assertEqual([p.name for p in self.cfg.cache_dir.iterdir()], ["state.json"])

    def test_a_failure_keeps_the_last_good_cache(self):
        good = self.good_sync()

        def offline(*a):
            raise NetworkError("offline")
        later = datetime.fromisoformat("2026-10-29T09:20:00+05:30")
        self.assertEqual(sync.run(self.cfg, self.client(offline), later, self.logs.append), 1)
        after = json.loads(self.cfg.cache_file.read_text())
        self.assertTrue(after["stale"])
        self.assertEqual(after["error"], "offline")
        self.assertEqual(after["synced_at"], good["synced_at"])
        self.assertEqual(after["attempted_at"], "2026-10-29T09:20:00+05:30")
        for k in ("today", "countdowns", "jobs", "brief", "summary"):
            self.assertEqual(after[k], good[k], k)

    def test_one_failing_source_writes_nothing_new(self):
        good = self.good_sync()
        inner = fixtures.transport(self.cfg, FIXTURES)

        def jobs_fail(method, path, body, params):
            if self.cfg.source("jobs") in path:
                return Response(404, {"code": "object_not_found"})
            return inner(method, path, body, params)
        sync.run(self.cfg, self.client(jobs_fail), NOW, self.logs.append)
        after = json.loads(self.cfg.cache_file.read_text())
        self.assertEqual(after["today"], good["today"])
        self.assertIn("share the Desk page", after["error"])

    def test_with_no_cache_a_failure_writes_an_empty_stale_one(self):
        sync.run(self.cfg, None, NOW, self.logs.append, failure=RuntimeError("the keyring is locked"))
        doc = json.loads(self.cfg.cache_file.read_text())
        self.assertTrue(doc["stale"])
        self.assertEqual(doc["error"], "the keyring is locked")
        self.assertEqual(doc["today"], [])

    def test_a_write_that_fails_leaves_the_old_file(self):
        self.good_sync()
        before = self.cfg.cache_file.read_text()
        with self.assertRaises(TypeError):
            store.write(self.cfg.cache_file, {"bad": object()})
        self.assertEqual(self.cfg.cache_file.read_text(), before)
        self.assertEqual([p.name for p in self.cfg.cache_dir.iterdir()], ["state.json"])

    def test_logs_carry_counts_not_content(self):
        self.good_sync()
        text = "\n".join(self.logs)
        self.assertIn("6 tasks", text)
        for word in ("internship", "Placement", "Razorpay", "brief ·"):
            self.assertNotIn(word, text)


class Backoff(unittest.TestCase):
    def client(self, answers, retries=4):
        self.clock = FakeClock()
        it = iter(answers)

        def send(*a):
            r = next(it)
            if isinstance(r, Exception):
                raise r
            return r
        return Client(send, rate=3, retries=retries, sleep=self.clock.sleep, clock=self.clock.clock,
                      rand=lambda: 0.5)

    def test_requests_are_spaced(self):
        c = self.client([Response(200, {})] * 3)
        for _ in range(3):
            c.request("GET", "pages/x")
        self.assertEqual(len(self.clock.slept), 2)
        self.assertTrue(all(abs(s - 1 / 3) < 1e-9 for s in self.clock.slept))

    def test_429_honours_retry_after(self):
        c = self.client([Response(429, {}, {"retry-after": "7"}), Response(200, {"ok": 1})])
        self.assertEqual(c.request("GET", "pages/x"), {"ok": 1})
        self.assertGreaterEqual(max(self.clock.slept), 7)

    def test_5xx_and_network_errors_back_off_exponentially(self):
        c = self.client([Response(502, {}), NetworkError("timeout"), Response(503, {}), Response(200, {})])
        c.request("GET", "pages/x")
        waits = [s for s in self.clock.slept if s > 0.34]
        self.assertEqual(waits, [0.75, 1.5, 3.0])

    def test_it_gives_up(self):
        c = self.client([Response(500, {})] * 3, retries=2)
        with self.assertRaises(NotionError):
            c.request("GET", "pages/x")

    def test_a_4xx_is_not_retried(self):
        c = self.client([Response(400, {"code": "validation_error"})])
        with self.assertRaisesRegex(NotionError, "validation_error"):
            c.request("GET", "pages/x")


class DryRun(unittest.TestCase):
    def test_no_network(self):
        import subprocess
        with tempfile.TemporaryDirectory() as t:
            out = Path(t, "state.json")
            code = ("import sys,runpy; sys.argv=['desk-sync','sync','--dry-run','--out',%r];"
                    "import builtins; real=builtins.__import__\n"
                    "def guard(n,*a,**k):\n"
                    "    if n.split('.')[0] in ('httpx','socket','http','urllib'): raise ImportError('network: '+n)\n"
                    "    return real(n,*a,**k)\n"
                    "builtins.__import__=guard\n"
                    "runpy.run_path(%r, run_name='__main__')") % (str(out), str(DESK / ".local/bin/desk-sync"))
            r = subprocess.run([sys.executable, "-c", code], capture_output=True, text=True,
                               env={**os.environ, "DESK_CONFIG": str(CONFIG), "DESK_NOW": NOW.isoformat()})
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(json.loads(out.read_text())["summary"]["open"], 5)


if __name__ == "__main__":
    unittest.main()
