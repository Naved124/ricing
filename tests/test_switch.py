"""Runs the `rice` switcher in a sandbox with fake desktop tools on PATH.

Every fake (qs, hyprctl, grim, gsettings, swaync, …) appends its argv to a
log, so the tests can check what a switch does and in which order, and that
a failing step never leaves the screen frozen.
"""

import json
import os
import re
import shutil
import stat
import subprocess
import tempfile
import threading
import time
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RICE = REPO / "switcher/.local/bin/rice"

FAKE = r"""#!/bin/sh
echo "$(basename "$0") $*" >> "$RICE_TEST_LOG"
case "$(basename "$0") $*" in
    "qs -c rice ipc call rice ping") echo pong ;;
    "hyprctl monitors -j") echo '[{"name":"DP-1"},{"name":"HDMI-A-1"}]' ;;
    # a running shell: a real process whose pid is in $RICE_TEST_RUNNING; like
    # qs, the "none" note goes to stdout
    "qs list -c "*" -j")
        if [ -s "$RICE_TEST_RUNNING" ] && kill -0 "$(cat "$RICE_TEST_RUNNING")" 2>/dev/null; then
            echo "[{\"pid\": $(cat "$RICE_TEST_RUNNING")}]"
        else
            echo "No running instances for shell.qml"
        fi ;;
    # a daemon outlives the switch, keeping whatever files it inherited
    "qs -n -c "*" -d") if [ -n "$RICE_TEST_DAEMON" ]; then sleep 4 >/dev/null 2>&1 & fi ;;
    "gsettings get org.gnome.desktop.interface enable-animations") echo "${RICE_TEST_ANIMATIONS:-true}" ;;
    gsettings*) [ -n "$RICE_TEST_FAIL_GSETTINGS" ] && exit 1 ;;
    grim*) [ -n "$RICE_TEST_FAIL_GRIM" ] && exit 1 ;;
    "uwsm check is-active") [ -n "$RICE_TEST_UWSM" ] || exit 1 ;;
    "pgrep -x Hyprland") [ -n "$RICE_TEST_HYPR_ALIVE" ] || exit 1 ;;
esac
exit 0
"""
FAKES = ["qs", "hyprctl", "grim", "gsettings", "swaync", "swaync-client",
         "pkill", "pgrep", "swww", "mpvpaper", "nvim", "systemctl", "hyprlock", "pidof",
         "uwsm", "loginctl", "setsid", "pw-play"]


@unittest.skipUnless(shutil.which("jq"), "jq not installed")
class Switch(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.rices = root / "rices"
        shutil.copytree(REPO / "rices/.config/rices", self.rices,
                        ignore=shutil.ignore_patterns("build", "current"))
        # "plain": a rice with no shell of its own (swaync, hyprlock, wallpaper files)
        plain = self.rices / "plain"
        shutil.copytree(self.rices / "nacre", plain)
        meta = {"name": "plain", "shell": "", "notifications": "swaync",
                "wallpaper": "files", "lock": "hyprlock"}
        text = (plain / "palette.toml").read_text()
        for key, value in meta.items():
            text = re.sub(rf'(?m)^{key}(\s*)= "[^"]*"', rf'{key}\1= "{value}"', text, count=1)
        (plain / "palette.toml").write_text(text)
        (self.rices / "current").symlink_to(plain)

        bin_ = root / "bin"
        bin_.mkdir()
        for name in FAKES:
            p = bin_ / name
            p.write_text(FAKE)
            p.chmod(p.stat().st_mode | stat.S_IXUSR)
        (bin_ / "rice-render").symlink_to(REPO / "render/.local/bin/rice-render")
        (bin_ / "jq").symlink_to(shutil.which("jq"))

        self.log = root / "calls.log"
        run = root / "run"
        run.mkdir()
        self.env = {
            "PATH": f"{bin_}:/usr/bin:/bin",
            "HOME": str(root),
            "RICE_DIR": str(self.rices),
            "RICE_TEMPLATES": str(REPO / "render/.local/share/rice/templates"),
            "RICE_INSTALL_ROOT": str(root / "install"),
            "XDG_RUNTIME_DIR": str(run),
            "XDG_STATE_HOME": str(root / "state"),
            "RICE_TEST_LOG": str(self.log),
            "RICE_TEST_RUNNING": str(root / "running"),
            "RICE_SETTLE": "0",
            "RICE_FREEZE_SETTLE": "0",
        }

    def tearDown(self):
        self.tmp.cleanup()

    def rice(self, *args, **env):
        return subprocess.run([str(RICE), *args], env={**self.env, **env},
                              capture_output=True, text=True, timeout=60)

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def index(self, calls, prefix):
        for i, c in enumerate(calls):
            if c.startswith(prefix):
                return i
        self.fail(f"no call starting with {prefix!r} in:\n" + "\n".join(calls))

    def test_switch_order(self):
        r = self.rice("nacre")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(os.readlink(self.rices / "current"), "nacre")
        # rendered before anything froze
        self.assertTrue((self.rices / "nacre/build/light/meta.json").exists())

        calls = self.calls()
        grim = self.index(calls, "grim")
        freeze = self.index(calls, "qs -c rice ipc call rice freeze")
        reload = self.index(calls, "hyprctl reload")
        start = self.index(calls, "qs -n -c nacre -d")
        dissolve = self.index(calls, "qs -c rice ipc call rice dissolve nacre")
        self.assertLess(grim, freeze)
        self.assertLess(freeze, reload)
        self.assertLess(reload, start)
        self.assertLess(start, dissolve)
        self.assertEqual(dissolve, len(calls) - 1, "dissolve should be the last thing")
        # one shot per monitor
        self.assertEqual(sum(c.startswith("grim -l 0 -o") for c in calls), 2)

    def test_active_follows_the_rice_and_the_mode(self):
        active = Path(self.env["HOME"]) / ".local/share/rice/active"
        self.assertEqual(self.rice("nacre").returncode, 0)
        self.assertEqual(Path(os.readlink(active)), self.rices / "current/build/light")
        self.assertTrue((active / "kitty.conf").is_file())
        # the mode is remembered across rice switches
        (Path(self.env["XDG_STATE_HOME"]) / "rice/mode").write_text("dark\n")
        self.assertEqual(self.rice("paper").returncode, 0)
        self.assertEqual(Path(os.readlink(active)), self.rices / "current/build/dark")
        self.assertIn("paper", (active / "kitty.conf").resolve().as_posix())

    # ── rice mode ─────────────────────────────────────────────────────────
    def to_nacre(self):
        self.assertEqual(self.rice("nacre").returncode, 0)
        self.log.unlink(missing_ok=True)

    def test_mode_order(self):
        self.to_nacre()
        r = self.rice("mode", "dark")
        self.assertEqual(r.returncode, 0, r.stderr)
        state = Path(self.env["XDG_STATE_HOME"]) / "rice"
        self.assertEqual((state / "mode").read_text(), "dark\n")
        self.assertEqual((state / "mode-source").read_text(), "manual\n")
        self.assertEqual([p.name for p in state.iterdir() if p.name.startswith(".")], [], "no temp files left")
        active = Path(self.env["HOME"]) / ".local/share/rice/active"
        self.assertEqual(Path(os.readlink(active)), self.rices / "current/build/dark")

        calls = self.calls()
        steps = [self.index(calls, p) for p in (
            "grim", "qs -c rice ipc call rice freeze",
            "hyprctl eval dofile([[",                # the active (dark) hypr-mode.lua, no reload
            "gsettings set org.gnome.desktop.interface color-scheme",
            "pkill -USR1 -x kitty", "pkill -USR1 -x cava",
            "qs -c nacre ipc call mode jump dark", "qs -c rice ipc call mode jump dark",
            "qs -c rice ipc call rice reveal dark")]
        self.assertEqual(steps, sorted(steps), "\n".join(calls))
        self.assertEqual(steps[-1], len(calls) - 1, "the reveal comes last")
        self.assertFalse(any(c.startswith("hyprctl reload") for c in calls), "a mode switch never reloads")
        # Hyprland reads the file; hyprctl would take its `--` first line for a flag
        evals = [c for c in calls if c.startswith("hyprctl eval dofile")]
        self.assertEqual(evals, [f"hyprctl eval dofile([[{active}/hypr-mode.lua]])"])
        timing = Path(self.env["XDG_RUNTIME_DIR"]) / "rice/mode-timing"
        self.assertRegex(timing.read_text(), r"^\d+\n$")
        self.assertIn("dark · manual", self.rice("mode", "status").stdout)
        self.assertIn("last switch:", self.rice("mode", "status", "-v").stdout)

    def test_mode_does_nothing_twice(self):
        self.to_nacre()
        self.rice("mode", "dark")
        self.log.unlink(missing_ok=True)
        self.assertEqual(self.rice("mode", "dark").returncode, 0)
        self.assertFalse(any(c.startswith(("grim", "hyprctl")) for c in self.calls()))

    def test_toggle_and_a_rice_switch_keep_the_mode(self):
        self.to_nacre()
        self.rice("mode", "toggle", "--instant")
        self.assertEqual(self.rice("mode", "status").stdout.split()[0], "dark")
        self.assertEqual(self.rice("paper").returncode, 0)
        active = Path(self.env["HOME"]) / ".local/share/rice/active"
        self.assertEqual(Path(os.readlink(active)), self.rices / "current/build/dark")
        self.rice("mode", "toggle", "--instant")
        self.assertEqual(self.rice("mode", "status").stdout.split()[0], "light")

    def test_instant_jumps_without_a_transition(self):
        self.to_nacre()
        self.rice("mode", "dark", "--instant")
        calls = self.calls()
        self.assertFalse(any(c.startswith("grim") for c in calls))
        self.assertIn("qs -c nacre ipc call mode jump dark", calls)
        self.assertFalse(any("rice reveal" in c for c in calls))

    def test_no_overlay_crossfades_instead(self):
        battery = Path(self.tmp.name) / "power/BAT0"
        battery.mkdir(parents=True)
        (battery / "capacity").write_text("15\n")
        (battery / "status").write_text("Discharging\n")
        for why, env in (("low battery", {"RICE_POWER_SUPPLY": str(battery.parent)}),
                         ("animations off", {"RICE_TEST_ANIMATIONS": "false"}),
                         ("grim failed", {"RICE_TEST_FAIL_GRIM": "1"})):
            with self.subTest(why):
                self.to_nacre()
                self.rice("mode", "light", "--instant")
                self.log.unlink(missing_ok=True)
                self.assertEqual(self.rice("mode", "dark", **env).returncode, 0)
                calls = self.calls()
                self.assertIn("qs -c nacre ipc call mode fade dark 200", calls)
                self.assertFalse(any("ipc call rice freeze" in c or "rice reveal" in c for c in calls))
                if why != "grim failed":
                    self.assertFalse(any(c.startswith("grim") for c in calls))
        (battery / "status").write_text("Charging\n")
        self.to_nacre()
        self.rice("mode", "light", "--instant")
        self.log.unlink(missing_ok=True)
        self.rice("mode", "dark", RICE_POWER_SUPPLY=str(battery.parent))
        self.assertIn("qs -c rice ipc call rice reveal dark", self.calls())

    def test_apps_get_the_rice_app_size(self):
        self.assertEqual(self.rice("paper").returncode, 0)
        fonts = [c for c in self.calls() if "font-name" in c and "monospace" not in c]
        self.assertTrue(fonts)
        self.assertTrue(all(c.endswith("Newsreader Regular 16") for c in fonts), fonts)

    def test_paper_clicks_only_when_sound_is_on(self):
        self.assertEqual(self.rice("paper").returncode, 0)
        conf = Path(self.env["HOME"]) / ".config/rice/mode.toml"
        conf.parent.mkdir(parents=True, exist_ok=True)
        for sound, mode in (("false", "dark"), ("true", "light")):
            with self.subTest(sound=sound):
                conf.write_text(f"sound = {sound}\n")
                self.log.unlink(missing_ok=True)
                self.assertEqual(self.rice("mode", mode).returncode, 0)
                clicks = [c for c in self.calls() if c.startswith("pw-play")]
                self.assertEqual(clicks, [f"pw-play {self.rices}/paper/assets/click.wav"] if sound == "true" else [])
        self.to_nacre()                       # Nacre has no sound
        self.rice("mode", "dark")
        self.assertFalse(any(c.startswith("pw-play") for c in self.calls()))

    # ── auto mode ─────────────────────────────────────────────────────────
    def sun(self, *args, at, toml="lat = 51.5074\nlon = -0.1278\n"):
        conf = Path(self.env["HOME"]) / ".config/rice/mode.toml"
        conf.parent.mkdir(parents=True, exist_ok=True)
        conf.write_text(toml)
        return self.rice(*args, RICE_NOW=at, TZ="Europe/London",
                         RICE_SUN=str(REPO / "switcher/.local/bin/rice-sun"))

    def state(self, name):
        p = Path(self.env["XDG_STATE_HOME"]) / "rice" / name
        if not p.exists():
            return "light" if name == "mode" else None    # no file yet: light
        return p.read_text().strip()

    def test_auto_without_a_location_uses_the_built_in_one(self):
        self.to_nacre()
        r = self.sun("mode", "auto", "--instant", at="2024-06-21T23:00", toml='lat = ""\nlon = ""\n')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual((self.state("mode"), self.state("mode-auto")), ("dark", ""))

    def test_auto_with_a_bad_location_says_so(self):
        self.to_nacre()
        r = self.sun("mode", "auto", at="2024-06-21T12:00", toml="lat = 95\nlon = 0\n")
        self.assertEqual(r.returncode, 2)
        self.assertIn("lat must be", r.stderr)
        self.assertIsNone(self.state("mode-auto"))

    def test_auto_follows_the_sun(self):
        self.to_nacre()
        r = self.sun("mode", "auto", "--instant", at="2024-06-21T21:05")   # London: dark from 21:01
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual((self.state("mode"), self.state("mode-source")), ("dark", "auto"))
        status = self.sun("mode", "status", at="2024-06-21T21:05").stdout
        self.assertRegex(status, r"^dark · auto · light at 05:0\d$")
        # the timer's tick does nothing until the sun's next switch, then switches
        self.sun("mode", "tick", at="2024-06-21T23:00")
        self.assertEqual(self.state("mode"), "dark")
        self.sun("mode", "tick", at="2024-06-22T12:00")
        self.assertEqual((self.state("mode"), self.state("mode-source")), ("light", "auto"))

    def test_a_manual_choice_holds_until_the_next_switch(self):
        self.to_nacre()
        self.sun("mode", "auto", "--instant", at="2024-06-21T12:00")
        self.assertEqual(self.state("mode"), "light")
        self.sun("mode", "dark", "--instant", at="2024-06-21T12:00")
        self.assertEqual(self.state("mode-source"), "manual")
        self.assertIsNotNone(self.state("mode-hold-until"))
        self.assertRegex(self.sun("mode", "status", at="2024-06-21T15:00").stdout,
                         r"^dark · held until 21:0\d \(then auto\)$")
        # held: the tick at 3 pm leaves the user's dark alone
        self.sun("mode", "tick", at="2024-06-21T15:00")
        self.assertEqual((self.state("mode"), self.state("mode-source")), ("dark", "manual"))
        # past the boundary: the hold goes and the sun takes over again
        self.sun("mode", "tick", at="2024-06-21T22:00")
        self.assertEqual((self.state("mode"), self.state("mode-source")), ("dark", "auto"))
        self.assertIsNone(self.state("mode-hold-until"))
        self.sun("mode", "tick", at="2024-06-22T12:00")
        self.assertEqual(self.state("mode"), "light")

    def test_auto_off(self):
        self.to_nacre()
        self.sun("mode", "auto", "--instant", at="2024-06-21T12:00")
        self.sun("mode", "auto", "off", at="2024-06-21T12:00")
        self.assertIsNone(self.state("mode-auto"))
        self.assertEqual(self.sun("mode", "status", at="2024-06-21T12:00").stdout.strip(), "light · manual")
        self.sun("mode", "tick", at="2024-06-21T23:00")
        self.assertEqual(self.state("mode"), "light", "a tick with auto off does nothing")
        # without auto, a manual choice has no hold
        self.sun("mode", "dark", "--instant", at="2024-06-21T12:00")
        self.assertIsNone(self.state("mode-hold-until"))

    def test_json_carries_the_mode(self):
        self.to_nacre()
        self.sun("mode", "auto", "--instant", at="2024-06-21T21:05")
        data = json.loads(self.sun("json", at="2024-06-21T21:05").stdout)
        self.assertEqual((data["mode"], data["mode_auto"]), ("dark", True))
        self.assertRegex(data["mode_next"], r"^light at 05:0\d$")
        self.assertNotIn("schedule", data)

    # ── a dark-only rice (Abyss) ─────────────────────────────────────────
    def to_deep(self):
        import sys
        sys.path.insert(0, str(REPO / "tests"))
        from test_render import make_dark_only
        make_dark_only(self.rices)
        r = self.rice("deep")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.log.unlink(missing_ok=True)

    def test_one_cursor_by_the_light_set_only_when_it_changes(self):
        def cursors():
            return [c for c in self.calls() if c.startswith("hyprctl setcursor")]
        # before any mode is chosen: Ice
        self.to_nacre()
        state = Path(self.env["XDG_STATE_HOME"]) / "rice/cursor"
        self.assertEqual(state.read_text().strip(), "Bibata-Modern-Ice 24")
        index = Path(self.env["HOME"]) / ".icons/default/index.theme"
        self.assertIn("Inherits=Bibata-Modern-Ice", index.read_text())
        # by day: Classic, set once
        self.rice("mode", "light", "--instant")
        self.assertEqual(cursors(), ["hyprctl setcursor Bibata-Modern-Classic 24"])
        self.assertIn("gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Classic", self.calls())
        # another rice in the same mode: not touched
        self.log.unlink()
        self.assertEqual(self.rice("paper").returncode, 0)
        self.assertEqual(cursors(), [])
        self.assertFalse(any("cursor-theme" in c for c in self.calls()))
        # at night: Ice again
        self.rice("mode", "dark", "--instant")
        self.assertEqual(cursors(), ["hyprctl setcursor Bibata-Modern-Ice 24"])
        # every rendered build carries its mode's cursor; a palette can't pick its own
        for mode, name in (("light", "Bibata-Modern-Classic"), ("dark", "Bibata-Modern-Ice")):
            regreet = (self.rices / f"paper/build/{mode}/regreet/regreet.toml").read_text()
            self.assertIn(f'cursor_theme_name = "{name}"', regreet)
        text = (self.rices / "paper/palette.toml").read_text()
        (self.rices / "paper/palette.toml").write_text(text.replace("[gtk]\n", '[gtk]\ncursor = "Adwaita"\n'))
        r = subprocess.run(["rice-render", "paper"], env=self.env, capture_output=True, text=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("the cursor is the mode's", r.stderr)

    def test_a_dark_only_rice_opens_dark_by_day(self):
        self.to_deep()
        active = Path(self.env["HOME"]) / ".local/share/rice/active"
        self.assertEqual(Path(os.readlink(active)), self.rices / "current/build/light")
        self.assertEqual(active.resolve(), (self.rices / "deep/build/dark").resolve())
        self.log.unlink(missing_ok=True)
        self.assertEqual(self.rice("reapply").returncode, 0)
        self.assertIn("gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark", self.calls())
        self.assertIn("gsettings set org.gnome.desktop.interface color-scheme prefer-dark", self.calls())

    def test_rice_mode_remembers_but_a_dark_only_rice_stays_dark(self):
        self.to_deep()
        state = Path(self.env["XDG_STATE_HOME"]) / "rice"
        for target, want in (("dark", "dark"), ("light", "light"), ("toggle", "dark")):
            with self.subTest(target):
                self.log.unlink(missing_ok=True)
                r = self.rice("mode", target)
                self.assertEqual(r.returncode, 0, r.stderr)
                self.assertEqual((state / "mode").read_text(), f"{want}\n")
                calls = self.calls()
                # nothing on screen changes: no freeze, no Hyprland, no GTK, no apps
                for prefix in ("grim", "hyprctl", "gsettings", "pkill -USR1", "qs -c rice ipc call rice reveal"):
                    self.assertFalse(any(c.startswith(prefix) for c in calls), f"{prefix}: {calls}")
                # the chooser follows the choice; the rice says why it doesn't
                self.assertIn(f"qs -c rice ipc call mode jump {want}", calls)
                self.assertIn("qs -c nacre ipc call shell toast dark Deep is always dark", calls)
        active = Path(self.env["HOME"]) / ".local/share/rice/active"
        self.assertEqual(active.resolve(), (self.rices / "deep/build/dark").resolve())
        # Paper and Nacre open in the mode chosen meanwhile
        self.rice("mode", "light")
        self.assertEqual(self.rice("paper").returncode, 0)
        self.assertEqual(active.resolve(), (self.rices / "paper/build/light").resolve())

    def test_auto_leaves_a_dark_only_rice_alone(self):
        self.to_deep()
        r = self.sun("mode", "auto", "--instant", at="2024-06-21T12:00")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual((self.state("mode"), self.state("mode-source")), ("light", "auto"))
        self.log.unlink(missing_ok=True)
        self.sun("mode", "tick", at="2024-06-21T23:00")
        self.assertEqual(self.state("mode"), "dark")
        calls = self.calls()
        self.assertFalse(any("toast" in c for c in calls), "the timer is quiet")
        self.assertFalse(any(c.startswith(("grim", "hyprctl", "gsettings")) for c in calls), calls)

    def test_the_timer_runs_the_tick(self):
        units = REPO / "systemd/.config/systemd/user"
        self.assertIn("ExecStart=%h/.local/bin/rice mode tick", (units / "rice-mode.service").read_text())
        self.assertIn("OnCalendar=*:0/5", (units / "rice-mode.timer").read_text())
        self.assertFalse((units / "rice-auto.timer").exists())
        self.assertFalse((REPO / "rices/.config/rices/auto.conf").exists())
        self.assertIn("rice mode tick", (REPO / "hypr/.config/hypr/hypridle.conf").read_text())

    def test_shell_rice_stops_swaync_and_wallpaper_daemons(self):
        self.rice("nacre")
        calls = self.calls()
        for daemon in ("swaync", "mako", "dunst"):
            self.assertIn(f"pkill -x {daemon}", calls)
        self.assertIn("pkill -x mpvpaper", calls)
        self.assertIn("swww kill", calls)

    def running_shell(self):
        """A stand-in for a running Quickshell instance; `qs list -j` reports it."""
        proc = subprocess.Popen(["sleep", "30"])
        threading.Thread(target=proc.wait, daemon=True).start()   # reap it once killed
        self.addCleanup(proc.kill)
        Path(self.env["RICE_TEST_RUNNING"]).write_text(str(proc.pid))
        return proc

    def assertStopped(self, proc):
        for _ in range(50):
            if proc.poll() is not None:
                return
            time.sleep(0.02)
        self.fail("the old shell is still running")

    def test_leaving_a_shell_kills_it(self):
        self.rice("nacre")
        shell = self.running_shell()
        self.log.unlink(missing_ok=True)
        r = self.rice("plain")
        self.assertEqual(r.returncode, 0, r.stderr)
        calls = self.calls()
        self.assertStopped(shell)
        self.assertFalse(any(c.startswith("qs -n -c plain") for c in calls))
        self.index(calls, "qs -c rice ipc call rice dissolve plain")

    def test_shell_to_shell(self):
        self.rice("nacre")
        shell = self.running_shell()
        self.log.unlink(missing_ok=True)
        r = self.rice("paper")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertStopped(shell)
        self.index(self.calls(), "qs -n -c paper -d")

    def test_failing_step_still_dissolves(self):
        render = Path(self.env["PATH"].split(":")[0]) / "rice-render"
        render.unlink()
        render.write_text("#!/bin/sh\nexit 3\n")
        render.chmod(0o755)
        r = self.rice("paper", RICE_TEST_FAIL_GSETTINGS="1")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("render failed", r.stderr)
        self.assertEqual(os.readlink(self.rices / "current"), "paper")
        self.index(self.calls(), "qs -c rice ipc call rice dissolve paper")

    def shader_calls(self):
        return [c for c in self.calls() if c.startswith("hyprctl eval") and "screen_shader" in c]

    def test_screen_shader_follows_the_rice(self):
        self.rice("paper")
        grain = str(self.rices / "paper/grain.frag")
        self.assertEqual(self.shader_calls(),
                         [f'hyprctl eval hl.config({{ decoration = {{ screen_shader = "{grain}" }} }})'])
        calls = self.calls()
        self.assertLess(self.index(calls, "hyprctl reload"), self.index(calls, "hyprctl eval"))
        self.log.unlink(missing_ok=True)
        self.rice("nacre")   # leaving Paper clears it explicitly
        self.assertEqual(self.shader_calls(), ['hyprctl eval hl.config({ decoration = { screen_shader = "" } })'])

    def test_grain_off_is_remembered(self):
        self.rice("paper")
        self.log.unlink(missing_ok=True)
        self.assertEqual(self.rice("grain", "status").stdout, "on\n")
        self.rice("grain", "toggle")
        self.assertEqual(self.rice("grain", "status").stdout, "off\n")
        self.assertEqual(self.shader_calls(), ['hyprctl eval hl.config({ decoration = { screen_shader = "" } })'])
        self.log.unlink(missing_ok=True)
        r = self.rice("reapply")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.shader_calls(), ['hyprctl eval hl.config({ decoration = { screen_shader = "" } })'])
        self.log.unlink(missing_ok=True)
        self.rice("grain", "on")
        self.assertIn("grain.frag", self.shader_calls()[0])

    def test_reapply_restarts_a_running_shell(self):
        self.rice("paper")
        shell = self.running_shell()
        self.log.unlink(missing_ok=True)
        r = self.rice("reapply")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertStopped(shell)
        self.index(self.calls(), "qs -n -c paper -d")

    def test_reapply_starts_a_shell_that_isnt_running(self):
        # `qs list` says "No running instances" on stdout: that isn't a shell
        self.rice("paper")
        self.log.unlink(missing_ok=True)
        r = self.rice("reapply")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.index(self.calls(), "qs -n -c paper -d")

    def test_a_started_shell_doesnt_keep_the_lock(self):
        # the shell `rice` starts runs on after the switch; if it held the
        # switch lock, every later `rice` would wait for it forever
        self.assertEqual(self.rice("nacre", RICE_TEST_DAEMON="1").returncode, 0)
        t = time.monotonic()
        r = self.rice("paper", RICE_TEST_DAEMON="1")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertLess(time.monotonic() - t, 3, "waited for the previous shell to exit")

    def test_a_held_lock_gives_up_with_a_hint(self):
        self.rice("nacre")
        lock = Path(self.env["XDG_RUNTIME_DIR"]) / "rice/lock"
        holder = subprocess.Popen(["flock", str(lock), "sleep", "10"])
        try:
            time.sleep(0.3)
            r = self.rice("paper", RICE_LOCK_WAIT="1")
            self.assertNotEqual(r.returncode, 0)
            self.assertIn("fuser -v", r.stderr)
        finally:
            holder.kill()
            holder.wait()

    def test_already_active_is_a_no_op(self):
        r = self.rice("plain")
        self.assertEqual(r.returncode, 0)
        self.assertIn("already active", r.stderr)
        self.assertEqual(self.calls(), [])

    def test_unknown_rice(self):
        r = self.rice("nope")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("no such rice", r.stderr)

    def test_json(self):
        r = self.rice("json")
        self.assertEqual(r.returncode, 0, r.stderr)
        d = json.loads(r.stdout)
        self.assertEqual(d["current"], "plain")
        self.assertEqual([x["name"] for x in d["rices"]], ["abyss", "nacre", "paper", "plain", "satsuei"])
        rices = {x["name"]: x for x in d["rices"]}
        self.assertTrue(rices["nacre"]["card"] and rices["paper"]["card"])
        nacre = rices["nacre"]["meta"]
        self.assertEqual(nacre["transition"], "ripple")
        self.assertEqual((d["mode"], d["mode_auto"], d["mode_next"]), ("light", False, ""))

    def test_lock_uses_the_shell(self):
        self.rice("nacre")
        self.log.unlink(missing_ok=True)
        self.rice("lock")
        self.assertEqual(self.calls(), ["qs -c nacre ipc call lock lock"])

    def test_lock_falls_back_to_hyprlock(self):
        self.rice("lock")
        self.assertIn("hyprlock", " ".join(self.calls()))

    def logout(self, **env):
        r = self.rice("logout", RICE_LOGOUT_WAIT="0", XDG_SESSION_ID="7", **env)
        self.assertEqual(r.returncode, 0, r.stderr)
        return self.calls()

    def test_logout_under_uwsm_stops_uwsm(self):
        calls = self.logout(RICE_TEST_UWSM="1")
        self.assertEqual(calls, ["uwsm check is-active", "uwsm stop"])

    def test_logout_prefers_hyprshutdown(self):
        shutdown = Path(self.env["PATH"].split(":")[0]) / "hyprshutdown"
        shutdown.write_text(FAKE)
        shutdown.chmod(0o755)
        calls = self.logout()
        self.assertIn("setsid -f hyprshutdown -t Logging out…", calls)
        self.assertFalse(any(c.startswith("hyprctl dispatch") for c in calls))
        self.assertNotIn("loginctl terminate-session 7", calls)

    def test_logout_falls_back_to_exit_then_loginctl(self):
        calls = self.logout()
        self.assertIn("hyprctl dispatch hl.dsp.exit()", calls)
        self.assertNotIn("loginctl terminate-session 7", calls)       # Hyprland went away
        self.log.unlink(missing_ok=True)
        calls = self.logout(RICE_TEST_HYPR_ALIVE="1")
        self.assertEqual(calls[-1], "loginctl terminate-session 7")

    def test_session_starts_the_shell_without_freezing(self):
        (self.rices / "current").unlink()
        (self.rices / "current").symlink_to(self.rices / "nacre")
        r = self.rice("session")
        self.assertEqual(r.returncode, 0, r.stderr)
        calls = self.calls()
        self.index(calls, "qs -n -c nacre -d")
        self.assertFalse(any("freeze" in c or c.startswith("grim") for c in calls))


if __name__ == "__main__":
    unittest.main()
