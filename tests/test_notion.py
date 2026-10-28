"""The Notion widget every rice shares: rice-notion (against a fake Notion),
the shared shell's card and panel (Notion.qml, NotionCard.qml, NotionPanel.qml),
and each control centre's Notion tile (that one is in test_render)."""

import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from datetime import date
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SHELLS = REPO / "quickshell/.config/quickshell"
TOOL = REPO / "switcher/.local/bin/rice-notion"
sys.path.insert(0, str(REPO / "tests"))

TASKS = "11111111-1111-1111-1111-111111111111"
AGENDA = "22222222-2222-2222-2222-222222222222"
PAGE = "33333333-3333-3333-3333-333333333333"


def has_pyside() -> bool:
    try:
        import PySide6.QtQml  # noqa: F401
    except ImportError:
        return False
    return True


def load_tool():
    loader = importlib.machinery.SourceFileLoader("rice_notion", str(TOOL))
    spec = importlib.util.spec_from_loader("rice_notion", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def title(text):
    return {"type": "title", "title": [{"plain_text": text}]}


class Fake(BaseHTTPRequestHandler):
    """Enough of api.notion.com for rice-notion: two databases, a page."""
    calls: list = []
    done_kind = "status"
    throttle = 0           # answer this many requests with 429 first

    def log_message(self, *a):
        pass

    def answer(self, code, body, headers=None):
        data = json.dumps(body).encode()
        self.send_response(code)
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def handle_any(self, method):
        n = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(n)) if n else None
        Fake.calls.append((method, self.path, body, self.headers.get("Authorization"), self.headers.get("Notion-Version")))
        if Fake.throttle > 0:
            Fake.throttle -= 1
            return self.answer(429, {"message": "rate limited"}, {"Retry-After": "1"})
        if self.headers.get("Authorization") != "Bearer secret":
            return self.answer(401, {"message": "API token is invalid."})
        p = self.path
        today = date.today().isoformat()
        if method == "GET" and p == f"/v1/databases/{TASKS}":
            done = ({"type": "checkbox", "checkbox": {}} if Fake.done_kind == "checkbox" else
                    {"type": "status", "status": {"options": [{"name": "Not started"}, {"name": "In progress"}, {"name": "Done"}]}})
            return self.answer(200, {"object": "database", "title": [{"plain_text": "Tasks"}], "properties": {
                "Name": {"type": "title"}, "Done": done, "Due": {"type": "date"},
                "Priority": {"type": "select", "select": {"options": [{"name": "High"}]}}}})
        if method == "GET" and p == f"/v1/databases/{AGENDA}":
            return self.answer(200, {"object": "database", "title": [{"plain_text": "Calendar"}],
                                     "properties": {"Name": {"type": "title"}, "Date": {"type": "date"}}})
        if method == "POST" and p == f"/v1/databases/{TASKS}/query":
            done = {"type": "checkbox", "checkbox": False} if Fake.done_kind == "checkbox" else {"type": "status", "status": {"name": "In progress"}}
            return self.answer(200, {"results": [
                {"id": "t1", "url": "https://www.notion.so/t1", "icon": {"type": "emoji", "emoji": "🧾"}, "properties": {
                    "Name": title("File taxes"), "Done": done, "Due": {"type": "date", "date": {"start": "2020-01-01"}},
                    "Priority": {"type": "select", "select": {"name": "High"}}}},
                {"id": "t2", "url": "https://www.notion.so/t2", "properties": {
                    "Name": title("Call mum"), "Done": done, "Due": {"type": "date", "date": {"start": today + "T18:00:00.000+05:30"}},
                    "Priority": {"type": "select", "select": None}}}], "has_more": False})
        if method == "POST" and p == f"/v1/databases/{AGENDA}/query":
            return self.answer(200, {"results": [{"id": "a1", "url": "u", "properties": {
                "Name": title("Standup"), "Date": {"type": "date", "date": {"start": today, "end": None}}}}], "has_more": False})
        if method == "GET" and p == f"/v1/pages/{PAGE}":
            return self.answer(200, {"object": "page", "url": "https://www.notion.so/week", "properties": {"title": title("Week")}})
        if method == "GET" and p.startswith(f"/v1/blocks/{PAGE}/children"):
            return self.answer(200, {"results": [
                {"id": "h", "type": "heading_2", "heading_2": {"rich_text": [{"plain_text": "Health"}]}},
                {"id": "b1", "type": "to_do", "to_do": {"rich_text": [{"plain_text": "Gym"}], "checked": True}},
                {"id": "p", "type": "paragraph", "paragraph": {"rich_text": []}},
                {"id": "b2", "type": "to_do", "to_do": {"rich_text": [{"plain_text": "Walk"}], "checked": False}}]})
        if method == "POST" and p == "/v1/search":
            return self.answer(200, {"results": [
                {"object": "page", "id": "r1", "url": "https://www.notion.so/r1", "last_edited_time": "2026-10-28T09:00:00.000Z",
                 "properties": {"title": title("Notes")}},
                {"object": "page", "id": "r2", "archived": True, "properties": {"title": title("Old")}}]})
        if method == "GET" and p == "/v1/users/me":
            return self.answer(200, {"object": "user", "name": "Rice"})
        if method in ("PATCH", "POST") and (p.startswith("/v1/pages") or p.startswith("/v1/blocks")):
            return self.answer(200, {"object": "page", "id": "new"})
        return self.answer(404, {"message": f"no {p}"})

    def do_GET(self):
        self.handle_any("GET")

    def do_POST(self):
        self.handle_any("POST")

    def do_PATCH(self):
        self.handle_any("PATCH")


class Tool(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Fake)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()

    def setUp(self):
        Fake.calls = []
        Fake.done_kind = "status"
        Fake.throttle = 0
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        (self.home / "config/rice").mkdir(parents=True)
        self.write_config()
        self.env = dict(os.environ, XDG_CONFIG_HOME=str(self.home / "config"), XDG_CACHE_HOME=str(self.home / "cache"),
                        NOTION_API=f"http://127.0.0.1:{self.server.server_port}")
        self.env.pop("NOTION_TOKEN", None)

    def tearDown(self):
        self.tmp.cleanup()

    def write_config(self, token="secret", refresh=90):
        (self.home / "config/rice/notion.toml").write_text(f'''
token = "{token}"
refresh = {refresh}
[tasks]
database = "https://www.notion.so/me/Tasks-{TASKS.replace("-", "")}?v=abc"
priority = "Priority"
[agenda]
database = "{AGENDA}"
[inbox]
database = "{TASKS}"
[pinned]
page = "{PAGE}"
''')

    def tool(self, *args, **kw):
        return subprocess.run([sys.executable, str(TOOL), *args], env=self.env, capture_output=True, text=True, timeout=30, **kw)

    def test_a_snapshot(self):
        r = self.tool("snapshot")
        self.assertEqual(r.returncode, 0, r.stderr)
        s = json.loads(r.stdout)
        self.assertTrue(s["ok"])
        self.assertEqual(s["error"], "")
        t = s["tasks"]
        self.assertTrue(t["configured"])
        self.assertEqual(t["statuses"], ["Not started", "In progress", "Done"])
        self.assertEqual([x["title"] for x in t["items"]], ["File taxes", "Call mum"])
        first, second = t["items"]
        self.assertEqual((first["icon"], first["overdue"], first["today"], first["priority"], first["status"]),
                         ("🧾", True, False, "High", "In progress"))
        self.assertEqual((second["overdue"], second["today"], second["dueTime"]), (False, True, True))
        self.assertEqual([a["title"] for a in s["agenda"]["items"]], ["Standup"])
        self.assertTrue(s["agenda"]["items"][0]["allDay"])
        self.assertEqual(s["pinned"]["title"], "Week")
        self.assertEqual([(i["text"], i["done"], i["group"]) for i in s["pinned"]["items"]],
                         [("Gym", True, "Health"), ("Walk", False, "Health")])
        self.assertEqual([p["title"] for p in s["recent"]], ["Notes"])          # the archived one left out
        # the open tasks only, by due date; the link's ID was found; the API's version and the token went with it
        query = next(c for c in Fake.calls if c[1] == f"/v1/databases/{TASKS}/query")
        self.assertEqual(query[2]["filter"], {"property": "Done", "status": {"does_not_equal": "Done"}})
        self.assertEqual(query[2]["sorts"][0], {"property": "Due", "direction": "ascending"})
        self.assertEqual((query[3], query[4]), ("Bearer secret", "2022-06-28"))
        # and it's kept for next time
        self.assertEqual(json.loads((self.home / "cache/rice/notion.json").read_text())["tasks"], t)

    def test_a_checkbox_for_done(self):
        Fake.done_kind = "checkbox"
        s = json.loads(self.tool("snapshot").stdout)
        self.assertEqual(s["tasks"]["doneKind"], "checkbox")
        query = next(c for c in Fake.calls if c[1].endswith("/query") and TASKS in c[1])
        self.assertEqual(query[2]["filter"], {"property": "Done", "checkbox": {"equals": False}})

    def watch(self):
        p = subprocess.Popen([sys.executable, str(TOOL), "watch"], env=self.env, stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE, text=True)
        def stop():
            p.kill()
            p.wait()
            for f in (p.stdin, p.stdout):
                if not f.closed:
                    f.close()
        self.addCleanup(stop)
        return p

    def line(self, p):
        return json.loads(p.stdout.readline())

    def test_watch_takes_commands(self):
        p = self.watch()
        self.assertTrue(self.line(p)["ok"])
        Fake.calls = []
        for cmd in ({"op": "done", "id": "t1", "on": True}, {"op": "done", "id": "t1", "on": False},
                    {"op": "todo", "id": "b2", "on": True}, {"op": "status", "id": "t2", "value": "Done"},
                    {"op": "add", "text": "Buy milk", "due": "+2"}, {"op": "capture", "text": "Idea\nline one\n\nline two"}):
            p.stdin.write(json.dumps(cmd) + "\n")
            p.stdin.flush()
            r = self.line(p)
            self.assertEqual((r["kind"], r["op"], r["ok"]), ("result", cmd["op"], True), r)
            self.assertEqual(self.line(p)["kind"], "snapshot")
        writes = [(m, path, body) for m, path, body, *_ in Fake.calls if m in ("PATCH",) or (m == "POST" and path == "/v1/pages")]
        self.assertEqual(writes[0], ("PATCH", "/v1/pages/t1", {"properties": {"Done": {"status": {"name": "Done"}}}}))
        # unticking a status goes back to the first other option
        self.assertEqual(writes[1][2], {"properties": {"Done": {"status": {"name": "Not started"}}}})
        self.assertEqual(writes[2], ("PATCH", "/v1/blocks/b2", {"to_do": {"checked": True}}))
        self.assertEqual(writes[3][2], {"properties": {"Done": {"status": {"name": "Done"}}}})
        add = writes[4][2]
        self.assertEqual(add["parent"], {"database_id": TASKS})
        self.assertEqual(add["properties"]["Name"]["title"][0]["text"]["content"], "Buy milk")
        self.assertEqual(add["properties"]["Due"]["date"]["start"], date.fromordinal(date.today().toordinal() + 2).isoformat())
        cap = writes[5][2]
        self.assertEqual(cap["properties"]["Name"]["title"][0]["text"]["content"], "Idea")
        self.assertEqual([b["paragraph"]["rich_text"][0]["text"]["content"] for b in cap["children"]], ["line one", "line two"])
        # a bad command is answered, not fatal
        p.stdin.write("{nope\n")
        p.stdin.flush()
        self.assertFalse(self.line(p)["ok"])
        p.stdin.close()
        self.assertEqual(p.wait(timeout=10), 0)          # the shell went away: so does it

    def test_offline_keeps_the_last_read(self):
        self.assertEqual(self.tool("snapshot").returncode, 0)
        self.env["NOTION_API"] = "http://127.0.0.1:9"     # nothing listens there
        p = self.watch()
        cached = self.line(p)
        self.assertTrue(cached["stale"])
        self.assertEqual(len(cached["tasks"]["items"]), 2)
        failed = self.line(p)
        self.assertFalse(failed["ok"])
        self.assertIn("offline", failed["error"])
        self.assertEqual(len(failed["tasks"]["items"]), 2)

    def test_slows_down_when_asked(self):
        Fake.throttle = 1
        p = self.watch()
        first = self.line(p)
        self.assertFalse(first["ok"])
        self.assertIn("slow down", first["error"])
        t = time.monotonic()
        second = self.line(p)
        self.assertTrue(second["ok"], second)
        self.assertGreaterEqual(time.monotonic() - t, 0.8)          # Retry-After: 1

    def test_a_bad_token(self):
        self.write_config(token="wrong")
        r = self.tool("snapshot")
        self.assertEqual(r.returncode, 1)
        self.assertIn("token was refused", r.stderr)

    def test_no_token_asks_for_one(self):
        self.write_config(token="")
        p = self.watch()
        s = self.line(p)
        self.assertTrue(s["setup"])
        self.assertIn("notion.toml", s["error"])
        self.assertEqual(Fake.calls, [])

    def test_check(self):
        (self.home / "config/rice/notion.toml").chmod(0o600)
        r = self.tool("check")
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn("token works: Rice", r.stdout)
        self.assertIn("tasks: Tasks", r.stdout)
        self.assertIn("pinned: Week", r.stdout)

    def test_check_warns_of_a_readable_token(self):
        (self.home / "config/rice/notion.toml").chmod(0o644)
        r = self.tool("check")
        self.assertEqual(r.returncode, 1)
        self.assertIn("chmod 600", r.stdout)

    def test_dates_and_ids(self):
        m = load_tool()
        today = date(2026, 10, 28)          # a Wednesday
        self.assertEqual(m.when("today", today), "2026-10-28")
        self.assertEqual(m.when("tomorrow", today), "2026-10-29")
        self.assertEqual(m.when("+7", today), "2026-11-04")
        self.assertEqual(m.when("fri", today), "2026-10-30")
        self.assertEqual(m.when("wed", today), "2026-11-04")          # the next one, not today
        self.assertEqual(m.when("2026-12-01", today), "2026-12-01")
        self.assertEqual(m.when("", today), "")
        self.assertEqual(m.page_id("https://www.notion.so/me/Tasks-0123456789abcdef0123456789ABCDEF?v=1"),
                         "01234567-89ab-cdef-0123-456789abcdef")


class Shell(unittest.TestCase):
    def test_the_shared_shell_has_it(self):
        shell = (SHELLS / "rice/shell.qml").read_text()
        for needle in ("NotionCard {}", "NotionPanel {}", 'target: "notion"', "function toggle(): void", "function open(): void"):
            self.assertIn(needle, shell)
        svc = (SHELLS / "rice/Notion.qml").read_text()
        for needle in ('["rice-notion", "watch"]', "running: root.wanted", "stdinEnabled: true", '"/notion.json"'):
            self.assertIn(needle, svc)
        card = (SHELLS / "rice/NotionCard.qml").read_text()
        for needle in ('"rice-notion"', "WlrLayer.Bottom", "hasFullscreen", "Notion.setAt(", "Notion.setShown(false)"):
            self.assertIn(needle, card)

    def test_the_example_settings_are_complete(self):
        import tomllib
        ex = tomllib.loads((REPO / "switcher/.local/share/rice/notion.example.toml").read_text())
        self.assertEqual(ex["token"], "")            # never a real one
        for section in ("tasks", "agenda", "inbox", "pinned"):
            self.assertIn(section, ex)

    @unittest.skipUnless(has_pyside(), "needs PySide6")
    def test_it_runs(self):
        import qs_smoke
        errors, pokes = qs_smoke.smoke(SHELLS / "rice", seconds=5.5, poke=REPO / "tests/pokes/rice-notion.qml")
        self.assertEqual(errors, [])
        read, offline = pokes
        self.assertTrue(read["shown"])
        self.assertEqual(read["open"], ["t1", "t2", "t3"])
        self.assertEqual(read["today"], ["t1", "t2"])          # today's, and what's overdue
        self.assertEqual(read["overdue"], ["t1"])
        self.assertEqual(read["someday"], ["t3"])
        self.assertEqual(read["ticked"], [True, True])         # shown at once, before Notion answers
        self.assertEqual(read["days"], ["Today", "Tomorrow"])
        # offline: the error shows, the last read stays, and so does the tick
        self.assertEqual((offline["ok"], offline["tasks"], offline["ticked"]), (False, 3, True))


if __name__ == "__main__":
    unittest.main()
