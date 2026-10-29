"""Desk: the full view's edits (set, new, trash) through the allowlist, and every refusal."""
import json
import unittest

from test_desk_write import JOB, TASK, UNKNOWN, Base, FIXTURES, NOW  # noqa: F401

from desksync import allow, queue, schema, store  # noqa: E402

LOG = "00000043-0000-4000-8000-000000000002"      # a Learning log row
BOOK = "00000045-0000-4000-8000-000000000001"     # a Reading list row
FUL = "00000046-0000-4000-8000-000000000001"      # a Fulgurite board row


class Reading(Base):
    def test_every_database_is_synced_with_its_schema(self):
        self.assertEqual(sorted(self.cache["sources"]), sorted(self.cfg.sources))
        for name, src in self.cache["sources"].items():
            self.assertEqual(src["schema"][0]["type"], "title", name)
            self.assertTrue(src["rows"], name)
        self.assertEqual(self.cache["order"][-2:], ["brief", "weekly"])

    def test_values_by_type(self):
        rows = {r["id"]: r["v"] for r in self.cache["sources"]["learning"]["rows"]}
        self.assertEqual(rows[LOG]["Confidence"], "Shaky")
        self.assertEqual(rows[LOG]["Date"], {"start": "2026-10-25", "end": None})
        self.assertIs(rows[LOG]["Revisit"], False)
        self.assertEqual(rows[LOG]["Source"], "")
        ful = self.cache["sources"]["fulgurite"]["rows"][0]["v"]
        self.assertEqual(ful["Area"], ["Disassembly", "Testing"])
        self.assertEqual(ful["Updated"], "2026-10-28T09:00:00.000Z")
        habits = self.cache["sources"]["habits"]["rows"]
        self.assertEqual([h["v"]["Score"] for h in habits], ["2", "3"])     # newest first, formula as text
        edit = {f["name"]: f["edit"] for f in self.cache["sources"]["habits"]["schema"]}
        self.assertEqual((edit["Score"], edit["Exercise"]), (False, True))

    def test_finished_rows_go_last(self):
        reading = self.cache["sources"]["reading"]["rows"]
        self.assertEqual([r["closed"] for r in reading], [False, True])
        today = self.cache["sources"]["today"]["rows"]
        self.assertEqual(sorted(r["closed"] for r in today), [r["closed"] for r in today])

    def test_the_weekly_reviews_newest_first(self):
        weekly = self.cache["pages"]["weekly"]
        self.assertEqual([p["title"] for p in weekly["pages"]], ["Week of 19 Oct", "Week of 12 Oct"])
        self.assertEqual(weekly["pages"][0]["blocks"][1]["text"], "Placement prep started.")


class Bodies(Base):
    def test_one_body_per_type(self):
        w = self.writer()
        w.set(self.cache, "today", TASK, "Due", {"start": "2026-11-02"})
        w.set(self.cache, "today", TASK, "Area", "Cyber")
        w.set(self.cache, "today", TASK, "Priority", "")
        w.set(self.cache, "today", TASK, "Notes", "see https://example.org/a then\\nmore")
        w.set(self.cache, "fulgurite", FUL, "Area", ["Formats", "Formats", "Testing"])
        w.set(self.cache, "fulgurite", FUL, "Status", "Done")
        w.set(self.cache, "learning", LOG, "Source", "https://example.org/x")
        w.set(self.cache, "learning", LOG, "Revisit", True)
        prep = self.cache["sources"]["prep"]["rows"][0]["id"]
        w.set(self.cache, "prep", prep, "Times asked", 3)
        bodies = [b["properties"] for m, p, b in self.writes if m == "PATCH"]
        self.assertEqual(bodies[0], {"Due": {"date": {"start": "2026-11-02", "end": None}}})
        self.assertEqual(bodies[1], {"Area": {"select": {"name": "Cyber"}}})
        self.assertEqual(bodies[2], {"Priority": {"select": None}})
        self.assertEqual(bodies[3]["Notes"]["rich_text"][1],
                         {"type": "text", "text": {"content": "https://example.org/a", "link": {"url": "https://example.org/a"}}})
        self.assertEqual(bodies[4], {"Area": {"multi_select": [{"name": "Formats"}, {"name": "Testing"}]}})
        self.assertEqual(bodies[5], {"Status": {"status": {"name": "Done"}}})
        self.assertEqual(bodies[6], {"Source": {"url": "https://example.org/x"}})
        self.assertEqual(bodies[7], {"Revisit": {"checkbox": True}})
        self.assertEqual(bodies[8], {"Times asked": {"number": 3}})

    def test_text_keeps_its_lines_and_loses_control_characters(self):
        self.writer().set(self.cache, "learning", LOG, "Stuck on", "one\n\x1b[31mtwo‮")
        body = self.writes[-1][2]["properties"]["Stuck on"]["rich_text"]
        self.assertEqual("".join(p["text"]["content"] for p in body), "one\n[31mtwo")

    def test_new_row_and_trash(self):
        w = self.writer()
        w.new(self.cache, "boxes", {"Box": "Lame", "Platform": "HTB", "Retired": True})
        w.trash(self.cache, "reading", BOOK)
        (m1, p1, b1), (m2, p2, b2) = [x for x in self.writes if x[0] != "GET"]
        self.assertEqual((m1, p1), ("POST", "pages"))
        self.assertEqual(b1["parent"], {"type": "data_source_id", "data_source_id": self.cfg.source("boxes")})
        self.assertEqual(b1["properties"]["Platform"], {"select": {"name": "HTB"}})
        self.assertEqual((m2, p2, b2), ("PATCH", f"pages/{BOOK}", {"in_trash": True}))


class Refusals(Base):
    def assertRefused(self, fn, *args):
        with self.assertRaises(allow.Refused):
            fn(*args)
        self.assertEqual(self.writes, [])

    def test_bad_values(self):
        w = self.writer()
        for prop, bad in (("Area", "Brand new option"), ("Due", "next friday"), ("Due", {"start": "2026-13-01"}),
                          ("Due", {"start": "2026-11-02", "end": "2026-11-01"}), ("Done", "yes"), ("Task", "   "),
                          ("Task", "x" * 2001), ("Notes", 5), ("Priority", ["High"]), ("No such field", "x")):
            self.assertRefused(w.set, self.cache, "today", TASK, prop, bad)
        self.assertRefused(w.set, self.cache, "learning", LOG, "Source", "javascript:alert(1)")
        self.assertRefused(w.set, self.cache, "fulgurite", FUL, "Area", ["Disassembly", "Shiny"])
        self.assertRefused(w.set, self.cache, "fulgurite", FUL, "Status", "")
        prep = self.cache["sources"]["prep"]["rows"][0]["id"]
        for bad in ("3", True, float("nan")):
            self.assertRefused(w.set, self.cache, "prep", prep, "Times asked", bad)

    def test_worked_out_properties_are_read_only(self):
        habit = self.cache["sources"]["habits"]["rows"][0]["id"]
        self.assertRefused(self.writer().set, self.cache, "habits", habit, "Score", "9")
        self.assertRefused(self.writer().set, self.cache, "fulgurite", FUL, "Updated", "2026-01-01")

    def test_rows_must_be_from_that_database_in_the_last_sync(self):
        w = self.writer()
        self.assertRefused(w.set, self.cache, "today", UNKNOWN, "Area", "Cyber")
        self.assertRefused(w.set, self.cache, "today", JOB, "Area", "Cyber")            # a Job hunt row
        self.assertRefused(w.set, self.cache, "nope", TASK, "Area", "Cyber")
        self.assertRefused(w.set, None, "today", TASK, "Area", "Cyber")
        self.assertRefused(w.trash, self.cache, "jobs", TASK)
        for pid in (self.cfg.brief, self.cfg.weekly, self.cfg.raw["desk"]["page"]):
            forged = json.loads(json.dumps(self.cache))
            forged["sources"]["today"]["rows"].append({"id": allow.norm_id(pid), "v": {}})
            self.assertRefused(w.set, forged, "today", pid, "Area", "Cyber")
            self.assertRefused(w.trash, forged, "today", pid)

    def test_notion_has_the_last_word_on_where_a_row_is(self):
        forged = json.loads(json.dumps(self.cache))
        forged["sources"]["today"]["rows"].append({"id": JOB, "v": {}})
        self.assertRefused(self.writer().set, forged, "today", JOB, "Area", "Cyber")

    def test_a_new_row_needs_a_title_and_known_options(self):
        w = self.writer()
        self.assertRefused(w.new, self.cache, "boxes", {"Platform": "HTB"})
        self.assertRefused(w.new, self.cache, "boxes", {"Box": "x", "Platform": "Vulnhub"})
        self.assertRefused(w.new, self.cache, "boxes", {})
        self.assertRefused(w.new, self.cache, "boxes", ["Box"])


class Queue(Base):
    def test_a_later_edit_of_the_same_property_replaces_the_first(self):
        queue.set_(self.cfg, self.cache, "today", TASK, "Area", "Cyber", NOW)
        queue.set_(self.cfg, self.cache, "today", TASK, "Priority", "Low", NOW)
        queue.set_(self.cfg, self.cache, "today", TASK, "Area", "RE", NOW)
        items = store.read(self.cfg.queue_file)
        self.assertEqual([(i["prop"], i["value"]) for i in items], [("Priority", "Low"), ("Area", "RE")])

    def test_refused_at_once_and_nothing_queued(self):
        for args in (["set", "today", TASK, "Area", '"Shiny"'], ["set", "today", TASK, "Area", "not json"],
                     ["set", "today", UNKNOWN, "Area", '"Cyber"'], ["new", "boxes", '{"Platform": "HTB"}'],
                     ["trash", "today", JOB], ["set", "brief", TASK, "Area", '"Cyber"']):
            r = self.cli(*args)
            self.assertEqual(r.returncode, 3, args)
            self.assertIn("refused", r.stderr)
        self.assertFalse(store.read(self.cfg.queue_file, []))

    def test_a_run_sends_the_edits(self):
        for args in (["set", "today", TASK, "Due", '{"start": "2026-11-02"}'],
                     ["new", "ideas", '{"Idea": "Desk in every rice", "Kind": "Rice"}'],
                     ["trash", "reading", BOOK]):
            self.assertEqual(self.cli(*args).returncode, 0, args)
        r = self.cli("run")
        self.assertEqual(r.returncode, 0, r.stderr)
        writes = store.read(self.cfg.state_dir / "writes.json")
        self.assertEqual([(w["method"], w["path"]) for w in writes],
                         [("PATCH", f"pages/{TASK}"), ("POST", "pages"), ("PATCH", f"pages/{BOOK}")])
        self.assertEqual(store.read(self.cfg.queue_file), [])

    def test_a_refusal_at_run_time_names_the_row_and_property(self):
        store.write(self.cfg.queue_file, [{"qid": "q", "op": "set", "source": "today", "page": TASK,
                                           "prop": "Area", "value": "Shiny"}])
        self.cli("run")
        e = store.read(self.cfg.cache_file)["errors"][-1]
        self.assertEqual((e["qid"], e["source"], e["page"], e["prop"]), ("q", "today", TASK, "Area"))


class Schema(unittest.TestCase):
    def test_long_text_is_split_into_pieces_notion_takes(self):
        parts = schema.rich_text("a" * 4500)
        self.assertEqual([len(p["text"]["content"]) for p in parts], [2000, 2000, 500])


if __name__ == "__main__":
    unittest.main()
