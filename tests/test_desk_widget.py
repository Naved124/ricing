"""Desk: the shells' widget (deskwidget/ in every shell with a bar).

The shared files are the same in every shell; DeskTheme is each rice's own
and fills every property DeskStyle declares. Notion's text is drawn only as
plain text, links open only as https through xdg-open, and the widget runs
nothing but desk-sync with an argument list.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SHELLS = REPO / "quickshell/.config/quickshell"
DESK = REPO / "desk"
sys.path.insert(0, str(REPO / "tests"))

# the shells the widget is wired into
WIRED = ["nacre"]
SHARED = ["DeskState.qml", "DeskStyle.qml", "DeskText.qml", "DeskGlyph.qml", "DeskCheck.qml", "DeskButton.qml",
          "DeskPill.qml", "DeskPanel.qml", "DeskToday.qml", "DeskBrief.qml", "DeskCountdowns.qml", "DeskJobs.qml"]
STUB_CACHE = Path("/tmp/qsstub-home/.cache/desk/state.json")


def has_pyside() -> bool:
    try:
        import PySide6.QtQml  # noqa: F401
    except ImportError:
        return False
    return True


def style_props() -> list[str]:
    text = (SHELLS / "nacre/deskwidget/DeskStyle.qml").read_text()
    return re.findall(r"^\s*property \w+ (\w+)", text, re.M)


class Files(unittest.TestCase):
    def test_the_shared_files_are_identical(self):
        first = SHELLS / WIRED[0] / "deskwidget"
        for shell in WIRED[1:]:
            for name in SHARED:
                with self.subTest(shell=shell, file=name):
                    self.assertEqual((SHELLS / shell / "deskwidget" / name).read_text(), (first / name).read_text(),
                                     f"copy {WIRED[0]}/deskwidget/{name} to {shell}/deskwidget/")
        for shell in WIRED:
            extra = {p.name for p in (SHELLS / shell / "deskwidget").glob("*.qml")} - set(SHARED) - {"DeskTheme.qml"}
            self.assertEqual(extra, set(), f"{shell}/deskwidget/ has files the others don't")

    def test_every_theme_fills_the_interface(self):
        props = style_props()
        self.assertGreaterEqual(len(props), 25)
        for shell in WIRED:
            text = (SHELLS / shell / "deskwidget/DeskTheme.qml").read_text()
            with self.subTest(shell):
                self.assertIn("pragma Singleton", text)
                self.assertRegex(text, r"(?m)^DeskStyle \{")
                missing = [p for p in props if not re.search(rf"(?m)^\s*{p}\s*:", text)]
                self.assertEqual(missing, [], f"{shell}'s DeskTheme leaves these unset")
                self.assertRegex(text, r'namespace:\s*"' + shell)

    def test_the_shared_files_hold_no_look(self):
        for name in SHARED:
            if name == "DeskStyle.qml":
                continue
            text = (SHELLS / WIRED[0] / "deskwidget" / name).read_text()
            with self.subTest(name):
                self.assertNotRegex(text, r"\bimport qs\s*$|\bTheme\.", "the look comes from DeskTheme only")
                self.assertNotRegex(text, r"font\.family:\s*\"", "fonts come from DeskTheme")


class Untrusted(unittest.TestCase):
    def files(self):
        for shell in WIRED:
            for f in sorted((SHELLS / shell / "deskwidget").glob("*.qml")):
                yield f, f.read_text()

    def test_plain_text_only(self):
        for f, text in self.files():
            with self.subTest(f.name):
                self.assertNotRegex(text, r"RichText|StyledText|MarkdownText|AutoText|onLinkActivated|linkActivated")
                if f.name != "DeskText.qml":
                    # every word goes through DeskText, which is PlainText
                    self.assertNotRegex(text, r"(?m)^\s*(Text|TextEdit|Label)\s*\{")
        self.assertIn("textFormat: Text.PlainText", (SHELLS / WIRED[0] / "deskwidget/DeskText.qml").read_text())

    def test_no_network_and_no_shell(self):
        for f, text in self.files():
            with self.subTest(f.name):
                self.assertNotIn("XMLHttpRequest", text)
                self.assertNotRegex(text, r'"(sh|bash|zsh)"|"-c"|notion\.com|api\.notion')
                for cmd in re.findall(r"\[\s*\"([^\"]+)\"", text):
                    if cmd in ("desk-sync", "xdg-open"):
                        continue
                    # other string arrays (tab names) are not commands
                    self.assertNotIn(cmd, ("curl", "wget", "python3", "secret-tool"))

    def test_links_are_https_and_one_argument(self):
        state = (SHELLS / WIRED[0] / "deskwidget/DeskState.qml").read_text()
        self.assertIn('/^https:\\/\\/[^\\s"\'<>]+$/', state)
        self.assertIn('Quickshell.execDetached(["xdg-open", url])', state)
        self.assertIn('["desk-sync", "capture", "--", t]', state)


@unittest.skipUnless(has_pyside(), "needs PySide6")
class Live(unittest.TestCase):
    """The shell under the stand-ins, reading a fixture cache from ~/.cache/desk."""

    def write_cache(self, now: datetime, stale: dict | None = None):
        STUB_CACHE.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([str(DESK / ".local/bin/desk-sync"), "sync", "--dry-run", "--out", str(STUB_CACHE)],
                       check=True, capture_output=True,
                       env={**os.environ, "DESK_CONFIG": str(DESK / ".config/desk/config.toml"),
                            "DESK_NOW": now.isoformat()})
        if stale:
            doc = json.loads(STUB_CACHE.read_text())
            doc.update(stale)
            STUB_CACHE.write_text(json.dumps(doc))

    def tearDown(self):
        STUB_CACHE.unlink(missing_ok=True)

    def poke(self, shell):
        import qs_smoke
        errors, pokes = qs_smoke.smoke(SHELLS / shell, seconds=5, poke=REPO / "tests/pokes/desk.qml")
        self.assertEqual(errors, [])
        return {p["tag"]: p for p in pokes}

    def test_it_reads_toggles_and_rolls_back(self):
        self.write_cache(datetime.now(timezone.utc).astimezone())
        for shell in WIRED:
            with self.subTest(shell):
                p = self.poke(shell)
                self.assertEqual((p["loaded"]["open"], p["loaded"]["overdue"]), (5, 1))
                self.assertEqual(p["loaded"]["next"], "4d · Placement drive")
                self.assertEqual((p["loaded"]["stale"], p["loaded"]["badge"]), (False, ""))
                self.assertEqual((p["toggled"]["done"], p["toggled"]["pending"], p["toggled"]["open"]), (True, True, 4))
                self.assertEqual(p["rolled"]["done"], False)
                self.assertIn("refused", p["rolled"]["error"])
                self.assertEqual((p["links"]["js"], p["links"]["http"], p["links"]["https"]), (False, False, True))

    def test_offline_shows_the_badge_and_keeps_the_data(self):
        # the last good sync was 40 minutes ago; the latest attempt found no network
        self.write_cache(datetime.now(timezone.utc).astimezone() - timedelta(minutes=40),
                         {"stale": True, "error": "offline"})
        p = self.poke(WIRED[0])["loaded"]
        self.assertEqual((p["stale"], p["badge"], p["label"]), (True, "Offline", "Synced 40m ago"))
        self.assertEqual(p["open"], 5)


if __name__ == "__main__":
    unittest.main()
