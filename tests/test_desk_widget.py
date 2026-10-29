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
WIRED = ["nacre", "paper", "abyss", "satsuei", "goldengate"]
BARS = {"nacre": "bar/Bar.qml", "paper": "bar/Bar.qml", "abyss": "bar/Bar.qml", "satsuei": "bar/Bar.qml",
        "goldengate": "menubar/MenuBar.qml"}
SHARED = ["DeskState.qml", "DeskStyle.qml", "DeskText.qml", "DeskGlyph.qml", "DeskCheck.qml", "DeskButton.qml",
          "DeskPill.qml", "DeskPanel.qml", "DeskCapture.qml", "DeskShortcuts.qml", "DeskToday.qml", "DeskBrief.qml", "DeskCountdowns.qml", "DeskJobs.qml"]
STUB_CACHE = Path("/tmp/qsstub-home/.cache/desk/state.json")
STUB_UI = Path("/tmp/qsstub-home/.local/state/desk/ui.json")


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


class Wiring(unittest.TestCase):
    def test_every_bar_has_the_pill_and_every_shell_the_panel(self):
        for shell in WIRED:
            with self.subTest(shell):
                self.assertIn("DeskPill {", (SHELLS / shell / BARS[shell]).read_text())
                text = (SHELLS / shell / "shell.qml").read_text()
                for needle in ("import qs.deskwidget", "DeskPanel {}", "DeskCapture {}", "DeskShortcuts {}"):
                    self.assertIn(needle, text)

    def test_the_glass_rices_blur_behind_it(self):
        rices = REPO / "rices/.config/rices"
        for rice in ("nacre", "abyss", "satsuei", "goldengate"):
            with self.subTest(rice):
                ns = re.search(r'namespace:\s*"([^"]+)"', (SHELLS / rice / "deskwidget/DeskTheme.qml").read_text())[1]
                rules = (rices / rice / "templates/hypr.lua").read_text()
                blurred = [m for m in re.findall(r'namespace = "(\^[^"]+\$)"', rules)
                           if re.match(m.replace("\\\\", "\\"), ns)]
                self.assertTrue(blurred, f"{ns} is in none of {rice}'s layer rules")
        self.assertIn('"goldengate:deskpanel"', (rices / "goldengate/templates/glass.lua").read_text())


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


class Capture(unittest.TestCase):
    def test_the_bind(self):
        base = (REPO / "hypr/.config/hypr/base.lua").read_text()
        self.assertIn('bind(key("SHIFT + N"), hl.dsp.global("quickshell:desk-capture")', base)
        # nothing else, shared or a rice's own, takes Super+Shift+N
        lua = base + "".join(p.read_text() for p in (REPO / "rices/.config/rices").glob("*/templates/*.lua"))
        self.assertEqual(len(re.findall(r'key\("SHIFT \+ N"\)|SUPER \+ SHIFT \+ N"', lua)), 1)
        for shell in WIRED:
            text = (SHELLS / shell / "shell.qml").read_text()
            self.assertIn("DeskShortcuts {}", text, shell)
            self.assertEqual(text.count("DeskShortcuts"), 1, f"{shell}: one GlobalShortcut, not one per screen")
        self.assertIn('name: "desk-capture"', (SHELLS / WIRED[0] / "deskwidget/DeskShortcuts.qml").read_text())

    def test_the_line_is_capped(self):
        text = (SHELLS / WIRED[0] / "deskwidget/DeskCapture.qml").read_text()
        self.assertIn("maximumLength: 200", text)
        self.assertIn("Keys.onEscapePressed: DeskState.captureOpen = false", text)


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

    def test_capture_opens_on_the_focused_screen(self):
        import qs_smoke
        self.write_cache(datetime.now(timezone.utc).astimezone())
        for shell in WIRED:
            with self.subTest(shell):
                errors, pokes = qs_smoke.smoke(SHELLS / shell, seconds=4, poke=REPO / "tests/pokes/desk-capture.qml")
                self.assertEqual(errors, [])
                p = {x["tag"]: x for x in pokes}
                self.assertEqual((p["open"]["open"], p["open"]["screen"], p["open"]["panel"]), (True, "DP-1", False))
                self.assertEqual((p["blank"]["sent"], p["real"]["sent"]), (False, True))
                self.assertEqual((p["panel"]["panel"], p["panel"]["capture"]), (True, False))

    def test_a_rice_switch_keeps_the_tab_and_fetches_nothing(self):
        import qs_smoke
        self.write_cache(datetime.now(timezone.utc).astimezone())
        synced = json.loads(STUB_CACHE.read_text())["synced_at"]
        STUB_UI.parent.mkdir(parents=True, exist_ok=True)
        try:
            for a, b in zip(WIRED, WIRED[1:] + WIRED[:1]):
                with self.subTest(f"{a} -> {b}"):
                    STUB_UI.unlink(missing_ok=True)
                    errors, pokes = qs_smoke.smoke(SHELLS / a, seconds=4.5, poke=REPO / "tests/pokes/desk-switch.qml")
                    self.assertEqual(errors, [])
                    p = {x["tag"]: x for x in pokes}
                    self.assertEqual(p["found"]["tab"], "today")
                    # the mode changed under the open panel: same tab, still open, same data
                    self.assertEqual((p["left"]["tab"], p["left"]["panel"], p["left"]["synced"]), ("jobs", True, synced))
                    # what the real FileView would have written (the stand-in keeps writes in memory)
                    STUB_UI.write_text(json.dumps({"tab": "jobs"}) + "\n")
                    errors, pokes = qs_smoke.smoke(SHELLS / b, seconds=3, poke=REPO / "tests/pokes/desk-switch.qml")
                    self.assertEqual(errors, [])
                    found = {x["tag"]: x for x in pokes}["found"]
                    self.assertEqual((found["tab"], found["loaded"], found["open"], found["synced"]),
                                     ("jobs", True, 5, synced))
        finally:
            STUB_UI.unlink(missing_ok=True)

    def test_offline_shows_the_badge_and_keeps_the_data(self):
        # the last good sync was 40 minutes ago; the latest attempt found no network
        self.write_cache(datetime.now(timezone.utc).astimezone() - timedelta(minutes=40),
                         {"stale": True, "error": "offline"})
        p = self.poke(WIRED[0])["loaded"]
        self.assertEqual((p["stale"], p["badge"], p["label"]), (True, "Offline", "Synced 40m ago"))
        self.assertEqual(p["open"], 5)


if __name__ == "__main__":
    unittest.main()
