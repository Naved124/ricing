"""Runs the `rice` switcher in a sandbox with fake desktop tools on PATH.

Every fake (qs, hyprctl, grim, gsettings, swaync, …) appends its argv to a
log, so the tests can check what a switch does and in which order, and that
a failing step never leaves the screen frozen.
"""

import json
import os
import shutil
import stat
import subprocess
import tempfile
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
    "qs list -c "*) [ -f "$RICE_TEST_RUNNING" ] && echo running ;;
    # a daemon outlives the switch, keeping whatever files it inherited
    "qs -n -c "*" -d") if [ -n "$RICE_TEST_DAEMON" ]; then sleep 4 >/dev/null 2>&1 & fi ;;
    gsettings*) [ -n "$RICE_TEST_FAIL_GSETTINGS" ] && exit 1 ;;
    "uwsm check is-active") [ -n "$RICE_TEST_UWSM" ] || exit 1 ;;
    "pgrep -x Hyprland") [ -n "$RICE_TEST_HYPR_ALIVE" ] || exit 1 ;;
esac
exit 0
"""
FAKES = ["qs", "hyprctl", "grim", "gsettings", "swaync", "swaync-client",
         "pkill", "pgrep", "swww", "mpvpaper", "nvim", "systemctl", "hyprlock", "pidof",
         "uwsm", "loginctl", "setsid"]


@unittest.skipUnless(shutil.which("jq"), "jq not installed")
class Switch(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.rices = root / "rices"
        shutil.copytree(REPO / "rices/.config/rices", self.rices,
                        ignore=shutil.ignore_patterns("build", "current"))
        (self.rices / "current").symlink_to(self.rices / "urushi")

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
        self.assertTrue((self.rices / "nacre/build/meta.json").exists())

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

    def test_shell_rice_stops_swaync_and_wallpaper_daemons(self):
        self.rice("nacre")
        calls = self.calls()
        for daemon in ("swaync", "mako", "dunst"):
            self.assertIn(f"pkill -x {daemon}", calls)
        self.assertIn("pkill -x mpvpaper", calls)
        self.assertIn("swww kill", calls)

    def test_leaving_a_shell_kills_it(self):
        self.rice("nacre")
        self.log.unlink()
        r = self.rice("urushi")
        self.assertEqual(r.returncode, 0, r.stderr)
        calls = self.calls()
        self.assertIn("qs kill -c nacre", calls)
        self.assertFalse(any(c.startswith("qs -n -c urushi") for c in calls))
        self.index(calls, "qs -c rice ipc call rice dissolve urushi")

    def test_shell_to_shell(self):
        self.rice("nacre")
        self.log.unlink()
        r = self.rice("paper")
        self.assertEqual(r.returncode, 0, r.stderr)
        calls = self.calls()
        self.assertLess(self.index(calls, "qs kill -c nacre"), self.index(calls, "qs -n -c paper -d"))

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
        self.log.unlink()
        self.rice("nacre")   # leaving Paper clears it explicitly
        self.assertEqual(self.shader_calls(), ['hyprctl eval hl.config({ decoration = { screen_shader = "" } })'])

    def test_grain_off_is_remembered(self):
        self.rice("paper")
        self.log.unlink()
        self.assertEqual(self.rice("grain", "status").stdout, "on\n")
        self.rice("grain", "toggle")
        self.assertEqual(self.rice("grain", "status").stdout, "off\n")
        self.assertEqual(self.shader_calls(), ['hyprctl eval hl.config({ decoration = { screen_shader = "" } })'])
        self.log.unlink()
        r = self.rice("reapply")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.shader_calls(), ['hyprctl eval hl.config({ decoration = { screen_shader = "" } })'])
        self.log.unlink()
        self.rice("grain", "on")
        self.assertIn("grain.frag", self.shader_calls()[0])

    def test_reapply_restarts_a_running_shell(self):
        self.rice("paper")
        Path(self.env["RICE_TEST_RUNNING"]).touch()
        self.log.unlink()
        r = self.rice("reapply")
        self.assertEqual(r.returncode, 0, r.stderr)
        calls = self.calls()
        self.assertLess(self.index(calls, "qs kill -c paper"), self.index(calls, "qs -n -c paper -d"))

    def test_a_started_shell_doesnt_keep_the_lock(self):
        # the shell `rice` starts runs on after the switch; if it held the
        # switch lock, every later `rice` would wait for it forever
        self.assertEqual(self.rice("nacre", RICE_TEST_DAEMON="1").returncode, 0)
        t = time.monotonic()
        r = self.rice("paper", RICE_TEST_DAEMON="1")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertLess(time.monotonic() - t, 3, "waited for the previous shell to exit")

    def test_already_active_is_a_no_op(self):
        r = self.rice("urushi")
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
        self.assertEqual(d["current"], "urushi")
        self.assertEqual([x["name"] for x in d["rices"]], ["nacre", "paper", "urushi"])
        self.assertTrue(all(x["card"] for x in d["rices"]))
        nacre = d["rices"][0]["meta"]
        self.assertEqual(nacre["transition"], "ripple")
        self.assertIn("paper 07:00", d["schedule"])

    def test_lock_uses_the_shell(self):
        self.rice("nacre")
        self.log.unlink()
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
        self.log.unlink()
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
