"""Desk: the shells' widget (deskwidget/ in every shell): the card on the
desktop, the full view, quick capture.

The shared files are the same in every shell; DeskTheme is each rice's own
and fills every property DeskStyle declares. Notion's text is drawn only as
plain text, links open only as https through xdg-open, and the widget runs
nothing but desk-sync with an argument list.
"""
import json
import os
import re
import subprocess
import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SHELLS = REPO / "quickshell/.config/quickshell"
DESK = REPO / "desk"
sys.path.insert(0, str(REPO / "tests"))

# the shells the widget is wired into, and each one's control centre
WIRED = ["nacre", "paper", "abyss", "satsuei", "goldengate"]
CENTERS = {"nacre": "center/Center.qml", "paper": "center/Center.qml", "abyss": "center/Center.qml",
           "satsuei": "center/Center.qml", "goldengate": "controlcenter/ControlCenter.qml"}
SHARED = ["DeskState.qml", "DeskStyle.qml", "DeskText.qml", "DeskGlyph.qml", "DeskCheck.qml", "DeskButton.qml",
          "DeskChip.qml", "DeskInput.qml", "DeskField.qml", "DeskPage.qml", "DeskCard.qml", "DeskView.qml",
          "DeskCapture.qml", "DeskShortcuts.qml"]
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
        self.assertGreaterEqual(len(props), 27)
        for shell in WIRED:
            text = (SHELLS / shell / "deskwidget/DeskTheme.qml").read_text()
            with self.subTest(shell):
                self.assertIn("pragma Singleton", text)
                self.assertRegex(text, r"(?m)^DeskStyle \{")
                missing = [p for p in props if not re.search(rf"(?m)^\s*{p}\s*:", text)]
                self.assertEqual(missing, [], f"{shell}'s DeskTheme leaves these unset")
                self.assertRegex(text, r'(?m)^\s*namespace:\s*"' + shell)
                self.assertRegex(text, r'cardNamespace:\s*"' + shell)

    def test_the_shared_files_hold_no_look(self):
        for name in SHARED:
            if name == "DeskStyle.qml":
                continue
            text = (SHELLS / WIRED[0] / "deskwidget" / name).read_text()
            with self.subTest(name):
                self.assertNotRegex(text, r"\bimport qs\s*$|\bTheme\.", "the look comes from DeskTheme only")
                self.assertNotRegex(text, r"font\.family:\s*\"", "fonts come from DeskTheme")


class Wiring(unittest.TestCase):
    def test_every_shell_has_the_card_the_view_and_capture(self):
        for shell in WIRED:
            with self.subTest(shell):
                text = (SHELLS / shell / "shell.qml").read_text()
                for needle in ("import qs.deskwidget", "DeskCard {", "DeskView {}", "DeskCapture {}", "DeskShortcuts {}"):
                    self.assertIn(needle, text)
                if shell != "goldengate":       # a full-screen window covers Golden Gate's bottom layer anyway
                    self.assertRegex(text, r"DeskCard \{[^}]*hidden:", "the card steps aside for fullscreen")

    def test_no_pill_in_any_bar(self):
        for f in SHELLS.rglob("*.qml"):
            self.assertNotIn("DeskPill", f.read_text(), f)
            self.assertNotIn("DeskPanel", f.read_text(), f)

    def test_every_control_centre_toggles_the_card(self):
        for shell in WIRED:
            text = (SHELLS / shell / CENTERS[shell]).read_text()
            with self.subTest(shell):
                self.assertIn("DeskState.setCardShown(!DeskState.cardShown)", text)
                self.assertIn("DeskState.openView(", text)

    def test_the_glass_rices_blur_behind_it(self):
        rices = REPO / "rices/.config/rices"
        for rice in ("nacre", "abyss", "satsuei", "goldengate"):
            theme = (SHELLS / rice / "deskwidget/DeskTheme.qml").read_text()
            rules = (rices / rice / "templates/hypr.lua").read_text()
            patterns = [m.replace("\\\\", "\\") for m in re.findall(r'namespace = "(\^[^"]+\$)"', rules)]
            # Golden Gate's desktop widgets frost themselves (see CLAUDE.md), so its card is left out
            names = ["namespace"] + ([] if rice == "goldengate" else ["cardNamespace"])
            for key in names:
                ns = re.search(rf'(?m)^\s*{key}:\s*"([^"]+)"', theme)[1]
                with self.subTest(rice=rice, layer=ns):
                    self.assertTrue([p for p in patterns if re.match(p, ns)], f"{ns} is in none of {rice}'s layer rules")
        glass = (rices / "goldengate/templates/glass.lua").read_text()
        self.assertIn('"goldengate:deskpanel"', glass)
        self.assertNotIn("deskcard", glass, "Golden Gate's card frosts itself, as its other desktop widgets do")


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
                    self.assertNotRegex(text, r"(?m)^\s*(Text|Label)\s*\{")
                if f.name != "DeskInput.qml":
                    self.assertNotRegex(text, r"(?m)^\s*TextEdit\s*\{", "the one TextEdit is DeskInput's")
        first = SHELLS / WIRED[0] / "deskwidget"
        self.assertIn("textFormat: Text.PlainText", (first / "DeskText.qml").read_text())
        self.assertIn("textFormat: TextEdit.PlainText", (first / "DeskInput.qml").read_text())

    def test_no_network_and_no_shell(self):
        for f, text in self.files():
            with self.subTest(f.name):
                self.assertNotIn("XMLHttpRequest", text)
                self.assertNotRegex(text, r'"(sh|bash|zsh)"|"-c"|notion\.com|api\.notion')
                for cmd in re.findall(r"\[\s*\"([^\"]+)\"", text):
                    self.assertNotIn(cmd, ("curl", "wget", "python3", "secret-tool"))
        state = (SHELLS / WIRED[0] / "deskwidget/DeskState.qml").read_text()
        commands = re.findall(r'run\(\["([^"]+)", "([^"]+)"', state)
        self.assertEqual({c for c, _ in commands}, {"desk-sync"})
        self.assertEqual({s for _, s in commands}, {"set", "new", "trash", "capture", "now"})

    def test_links_are_https_and_one_argument(self):
        state = (SHELLS / WIRED[0] / "deskwidget/DeskState.qml").read_text()
        self.assertIn('/^https:\\/\\/[^\\s"\'<>]+$/', state)
        self.assertIn('Quickshell.execDetached(["xdg-open", url])', state)
        self.assertIn('["desk-sync", "capture", "--", t]', state)
        self.assertIn('["desk-sync", "set", name, id, prop, JSON.stringify(value)]', state)


class Capture(unittest.TestCase):
    def test_the_bind(self):
        base = (REPO / "hypr/.config/hypr/base.lua").read_text()
        self.assertIn('bind(key("SHIFT + N"), hl.dsp.global("quickshell:desk-capture")', base)
        # nothing else, shared or a rice's own, takes Super+Shift+N
        lua = base + "".join(p.read_text() for p in (REPO / "rices/.config/rices").glob("*/templates/*.lua"))
        self.assertEqual(len(re.findall(r'key\("SHIFT \+ N"\)|SUPER \+ SHIFT \+ N"', lua)), 1)
        for shell in WIRED:
            text = (SHELLS / shell / "shell.qml").read_text()
            self.assertEqual(text.count("DeskShortcuts"), 1, f"{shell}: one GlobalShortcut, not one per screen")
        self.assertIn('name: "desk-capture"', (SHELLS / WIRED[0] / "deskwidget/DeskShortcuts.qml").read_text())

    def test_the_card_resizes_like_a_phone_widget(self):
        card = (SHELLS / WIRED[0] / "deskwidget/DeskCard.qml").read_text()
        for needle in ("onLongPressed: DeskState.cardResizing = true", "Handle { dx: -1 }", "Handle { dx: 1 }",
                       "Handle { dy: -1 }", "Handle { dy: 1 }", "DeskState.setCardSize(", "mask: Region { item: win.resizing ? cover : card }"):
            self.assertIn(needle, card)
        self.assertIn("function resize(): void", (SHELLS / WIRED[0] / "deskwidget/DeskShortcuts.qml").read_text())

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

    def setUp(self):
        STUB_UI.unlink(missing_ok=True)

    def tearDown(self):
        STUB_CACHE.unlink(missing_ok=True)
        STUB_UI.unlink(missing_ok=True)

    def poke(self, shell, name="desk.qml", seconds=8):
        import qs_smoke
        errors, pokes = qs_smoke.smoke(SHELLS / shell, seconds=seconds, poke=REPO / "tests/pokes" / name)
        self.assertEqual(errors, [])
        return {p["tag"]: p for p in pokes}

    def test_the_card_and_the_view_read_and_edit(self):
        self.write_cache(datetime.now(timezone.utc).astimezone())
        for shell in WIRED:
            with self.subTest(shell):
                p = self.poke(shell)
                loaded = p["loaded"]
                self.assertEqual((loaded["open"], loaded["overdue"], loaded["stale"], loaded["badge"]), (5, 1, False, ""))
                self.assertEqual(loaded["order"][-2:], ["brief", "weekly"])
                self.assertEqual(len(loaded["order"]), 12)
                self.assertTrue(all(n > 0 for n in loaded["rows"][:10]), loaded["rows"])
                # the card's tick shows at once, in the view too
                self.assertEqual((p["ticked"]["done"], p["ticked"]["pending"], p["ticked"]["open"], p["ticked"]["inView"]),
                                 (True, True, 4, True))
                self.assertEqual((p["view"]["open"], p["view"]["source"], p["view"]["selected"]), (True, "today", True))
                e = p["edited"]
                self.assertEqual((e["area"], e["due"], e["ful"]), ("Cyber", {"start": "2026-11-02", "end": None}, ["Formats"]))
                self.assertEqual((e["pending"], e["foreign"]), (4, False))
                self.assertNotEqual(p["rolled"]["area"], "Cyber")
                self.assertIn("refused", p["rolled"]["error"])
                self.assertEqual(p["rolled"]["pending"], 3)
                self.assertEqual((p["added"]["first"], p["added"]["ghost"], p["added"]["key"]), ("Lame", True, True))
                self.assertTrue(p["trashed"]["gone"])
                self.assertEqual((p["links"]["js"], p["links"]["http"], p["links"]["https"]), (False, False, True))

    def test_capture_opens_on_the_focused_screen(self):
        self.write_cache(datetime.now(timezone.utc).astimezone())
        for shell in WIRED:
            with self.subTest(shell):
                p = self.poke(shell, "desk-capture.qml", 4)
                self.assertEqual((p["open"]["open"], p["open"]["screen"], p["open"]["view"]), (True, "DP-1", False))
                self.assertEqual((p["blank"]["sent"], p["real"]["sent"]), (False, True))
                self.assertEqual((p["view"]["view"], p["view"]["capture"]), (True, False))
                self.assertEqual(p["card"]["card"], False)

    def test_a_rice_switch_keeps_the_place_and_fetches_nothing(self):
        self.write_cache(datetime.now(timezone.utc).astimezone())
        synced = json.loads(STUB_CACHE.read_text())["synced_at"]
        STUB_UI.parent.mkdir(parents=True, exist_ok=True)
        for a, b in zip(WIRED, WIRED[1:] + WIRED[:1]):
            with self.subTest(f"{a} -> {b}"):
                STUB_UI.unlink(missing_ok=True)
                p = self.poke(a, "desk-switch.qml", 4.5)
                self.assertEqual(p["found"]["source"], "today")
                self.assertEqual((p["found"]["w"], p["found"]["h"]), (360, 0))      # its height follows what it holds
                # the mode changed under the open view: same database, still open, same data
                self.assertEqual((p["left"]["source"], p["left"]["view"], p["left"]["synced"]), ("reading", True, synced))
                # what the real FileView would have written (the stand-in keeps writes in memory)
                STUB_UI.write_text(json.dumps({"source": "reading", "cardShown": False, "cardX": 0.4, "cardY": 0.5,
                                               "cardW": 520, "cardH": 300}) + "\n")
                found = self.poke(b, "desk-switch.qml", 3)["found"]
                self.assertEqual((found["source"], found["loaded"], found["open"], found["synced"], found["card"], found["x"]),
                                 ("reading", True, 5, synced, False, 0.4))
                self.assertEqual((found["w"], found["h"]), (520, 300))

    def test_offline_shows_the_badge_and_keeps_the_data(self):
        # the last good sync was 40 minutes ago; the latest attempt found no network
        self.write_cache(datetime.now(timezone.utc).astimezone() - timedelta(minutes=40),
                         {"stale": True, "error": "offline"})
        p = self.poke(WIRED[0])["loaded"]
        self.assertEqual((p["stale"], p["badge"], p["label"]), (True, "Offline", "Synced 40m ago"))
        self.assertEqual(p["open"], 5)


if __name__ == "__main__":
    unittest.main()
