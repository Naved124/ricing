"""Desk: the write path (queue, allowlist, toggle and capture) and every refusal."""
import json
import os
import subprocess
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

from desksync import allow, config, fixtures, queue, store, sync  # noqa: E402
from desksync.config import Config  # noqa: E402
from desksync.notion import Client, NetworkError, Response  # noqa: E402

NOW = datetime.fromisoformat("2026-10-29T09:00:00+05:30")
TASK = "11111111-0000-4000-8000-000000000001"     # open, in the fixtures' Today
DONE = "11111111-0000-4000-8000-000000000006"     # done today
JOB = "33333333-0000-4000-8000-000000000001"      # a Job hunt page
UNKNOWN = "99999999-0000-4000-8000-000000000009"


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.cfg = Config(config.load(CONFIG).raw, self.root / "cache/desk", self.root / "state/desk")
        self.writes = []
        self.logs = []
        sync.run(self.cfg, self.client(), NOW, self.logs.append)
        self.cache = store.read(self.cfg.cache_file)

    def tearDown(self):
        self.tmp.cleanup()

    def client(self, transport=None):
        return Client(transport or fixtures.transport(self.cfg, FIXTURES, self.writes), rate=1000, retries=0)

    def writer(self, transport=None):
        return allow.Writer(self.cfg, self.client(transport))

    def cli(self, *args):
        env = {**os.environ, "DESK_CONFIG": str(CONFIG), "DESK_NOW": NOW.isoformat(), "DESK_NO_KICK": "1",
               "DESK_DRY_RUN": str(FIXTURES), "XDG_CACHE_HOME": str(self.root / "cache"),
               "XDG_STATE_HOME": str(self.root / "state")}
        return subprocess.run([str(DESK / ".local/bin/desk-sync"), *args], capture_output=True, text=True, env=env)


class Refusals(Base):
    def assertRefused(self, fn, *args):
        with self.assertRaises(allow.Refused):
            fn(*args)

    def test_toggle_needs_a_page_id(self):
        for bad in ("", "abc", "../../pages/x", "' OR 1=1", TASK + "0", TASK.replace("1", "g", 1),
                    TASK + "/children", None, 12):
            self.assertRefused(allow.known_task, self.cfg, self.cache, bad)

    def test_toggle_needs_a_task_from_the_last_sync(self):
        self.assertRefused(allow.known_task, self.cfg, self.cache, UNKNOWN)
        self.assertRefused(allow.known_task, self.cfg, self.cache, JOB)
        self.assertRefused(allow.known_task, self.cfg, None, TASK)

    def test_the_brief_and_desk_pages_are_read_only(self):
        for pid in (self.cfg.brief, self.cfg.raw["desk"]["page"]):
            cache = {"today": [{"id": allow.norm_id(pid), "done": False}]}
            self.assertRefused(allow.known_task, self.cfg, cache, pid)

    def test_a_page_outside_today_is_refused_even_if_the_cache_says_otherwise(self):
        forged = {"today": [{"id": JOB, "done": False}]}
        inner = fixtures.transport(self.cfg, FIXTURES, self.writes)
        jobs = json.loads((FIXTURES / "jobs.json").read_text())["results"]

        def t(method, path, body, params):
            if method == "GET" and path == f"pages/{JOB}":
                return Response(200, jobs[0])
            return inner(method, path, body, params)
        self.assertRefused(self.writer(t).set_done, forged, JOB, True)
        self.assertEqual(self.writes, [])

    def test_done_must_be_a_checkbox_value(self):
        self.assertRefused(self.writer().set_done, self.cache, TASK, "yes")
        self.assertEqual(self.writes, [])

    def test_new_pages_only_in_today_and_ideas(self):
        for target in ("jobs", "countdowns", "brief", "", "../pages"):
            self.assertRefused(allow.create_body, self.cfg, target, "x")
            self.assertRefused(self.writer().create, target, "x")
        self.assertEqual(self.writes, [])

    def test_capture_text(self):
        for bad in ("", "   ", "\x00\x01\x1b", "​‮", "idea:", "idea:   ", None):
            self.assertRefused(allow.capture, self.cfg, bad)
        self.assertEqual(allow.capture(self.cfg, "  buy\x1b[31m milk\n now "), ("today", "buy[31m milk now"))
        self.assertEqual(allow.capture(self.cfg, "‮evil"), ("today", "evil"))
        self.assertEqual(allow.capture(self.cfg, "IDEA: a rice for Notion"), ("ideas", "a rice for Notion"))
        target, title = allow.capture(self.cfg, "x" * 500)
        self.assertEqual(len(title), 200)

    def test_no_delete_and_no_other_writes_in_the_queue(self):
        items = [{"qid": "a", "op": "delete", "page": TASK}, {"qid": "b", "op": "update", "page": TASK},
                 {"qid": "c", "op": "capture", "target": "jobs", "title": "x"},
                 {"qid": "d", "op": "toggle", "page": UNKNOWN, "done": True},
                 {"qid": "e", "op": "toggle", "page": self.cfg.brief, "done": True}]
        retry, errors = queue.apply(self.cfg, self.writer(), self.cache, items, NOW, self.logs.append)
        self.assertEqual(retry, [])
        self.assertEqual([e["qid"] for e in errors], list("abcde"))
        self.assertTrue(all(e["message"].startswith("refused") for e in errors))
        self.assertEqual(self.writes, [])

    def test_the_writer_has_only_these_calls(self):
        public = sorted(n for n in vars(allow.Writer) if not n.startswith("_"))
        self.assertEqual(public, ["create", "new", "set", "set_done", "trash"])

    def test_cli_refusals_exit_3(self):
        for args in (["toggle", "nope"], ["toggle", UNKNOWN], ["capture", "--", "   "], ["capture", "--", "idea:"]):
            r = self.cli(*args)
            self.assertEqual(r.returncode, 3, args)
            self.assertIn("refused", r.stderr)
        self.assertFalse(self.cfg.queue_file.exists() and store.read(self.cfg.queue_file))


class Bodies(Base):
    def test_toggle_body_sets_only_done(self):
        self.writer().set_done(self.cache, TASK, True)
        self.assertEqual(self.writes, [("PATCH", f"pages/{TASK}", {"properties": {"Done": {"checkbox": True}}})])

    def test_capture_bodies(self):
        self.writer().create("today", "Call the bank")
        self.writer().create("ideas", "A tiny idea")
        (m1, p1, b1), (m2, p2, b2) = self.writes
        self.assertEqual((m1, p1, m2, p2), ("POST", "pages", "POST", "pages"))
        self.assertEqual(b1, {"parent": {"type": "data_source_id", "data_source_id": self.cfg.source("today")},
                              "properties": {"Task": {"title": [{"type": "text", "text": {"content": "Call the bank"}}]},
                                             "Priority": {"select": {"name": "Normal"}}}})
        self.assertEqual(b2, {"parent": {"type": "data_source_id", "data_source_id": self.cfg.source("ideas")},
                              "properties": {"Idea": {"title": [{"type": "text", "text": {"content": "A tiny idea"}}]}}})


class Queue(Base):
    def test_toggle_flips_the_synced_value_and_twice_cancels(self):
        self.assertEqual(queue.toggle(self.cfg, self.cache, TASK, NOW), "queued done=true")
        self.assertEqual(queue.toggle(self.cfg, self.cache, DONE, NOW), "queued done=false")
        self.assertEqual(queue.toggle(self.cfg, self.cache, TASK, NOW), "cancelled")
        self.assertEqual([(i["page"], i["done"]) for i in store.read(self.cfg.queue_file)], [(DONE, False)])

    def test_the_queue_file_is_private(self):
        queue.capture(self.cfg, "x", NOW)
        self.assertEqual(oct(self.cfg.queue_file.stat().st_mode & 0o777), "0o600")

    def test_a_run_applies_the_queue_then_syncs(self):
        self.assertEqual(self.cli("toggle", TASK).returncode, 0)
        self.assertEqual(self.cli("capture", "--", "-starts with a dash").returncode, 0)
        self.assertEqual(self.cli("capture", "--", "idea: notion in the bar").returncode, 0)
        r = self.cli("run")
        self.assertEqual(r.returncode, 0, r.stderr)
        writes = store.read(self.cfg.state_dir / "writes.json")
        self.assertEqual([(w["method"], w["path"]) for w in writes],
                         [("PATCH", f"pages/{TASK}"), ("POST", "pages"), ("POST", "pages")])
        self.assertEqual(writes[1]["body"]["properties"]["Task"]["title"][0]["text"]["content"], "-starts with a dash")
        self.assertEqual(store.read(self.cfg.queue_file), [])
        self.assertFalse(store.read(self.cfg.cache_file)["stale"])

    def test_transient_failures_are_retried_then_reported(self):
        def offline(*a):
            raise NetworkError("offline")
        item = {"qid": "q", "op": "capture", "target": "today", "title": "x", "tries": 0}
        for tries in (1, 2):
            retry, errors = queue.apply(self.cfg, self.writer(offline), self.cache, [item], NOW, self.logs.append)
            self.assertEqual(([i["tries"] for i in retry], errors), ([tries], []))
            item = retry[0]
        retry, errors = queue.apply(self.cfg, self.writer(offline), self.cache, [item], NOW, self.logs.append)
        self.assertEqual(retry, [])
        self.assertEqual(errors[0]["qid"], "q")

    def test_a_4xx_is_reported_not_retried(self):
        def no(*a):
            return Response(400, {"code": "validation_error"})
        item = {"qid": "q", "op": "capture", "target": "today", "title": "x"}
        retry, errors = queue.apply(self.cfg, self.writer(no), self.cache, [item], NOW, self.logs.append)
        self.assertEqual(retry, [])
        self.assertIn("validation_error", errors[0]["message"])

    def test_errors_reach_the_cache_for_rollback(self):
        store.write(self.cfg.queue_file, [{"qid": "zz", "op": "toggle", "page": UNKNOWN, "done": True}])
        self.cli("run")
        errors = store.read(self.cfg.cache_file)["errors"]
        self.assertEqual(errors[-1]["qid"], "zz")


if __name__ == "__main__":
    unittest.main()
