"""rice-sun: sunrise and sunset by NOAA's algorithm, and light/dark from them.

Reference times, within 2 minutes:
  · London 21 Jun 2024 04:43 / 21:21 (published, e.g. Time Out and a London
    council sunlight study)
  · Sydney 21 Dec 2024: a 14 h 24 min day (Time Out)
  · the rest agree with the independent `astral` package to within a minute:
    London 21 Dec 08:04 / 15:53, New York 21 Dec 07:17 / 16:32 and 20 Jun
    05:25 / 20:30, Sydney 21 Dec 05:41 / 20:05, Quito 20 Mar 06:18 / 18:24
"""

import importlib.machinery
import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from datetime import date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

REPO = Path(__file__).resolve().parent.parent
SCRIPT = REPO / "switcher/.local/bin/rice-sun"

loader = importlib.machinery.SourceFileLoader("rice_sun", str(SCRIPT))
spec = importlib.util.spec_from_loader("rice_sun", loader)
rs = importlib.util.module_from_spec(spec)
loader.exec_module(rs)

PLACES = {
    "london":  (51.5074, -0.1278, "Europe/London"),
    "newyork": (40.7128, -74.0060, "America/New_York"),
    "sydney":  (-33.8688, 151.2093, "Australia/Sydney"),
    "quito":   (-0.1807, -78.4678, "America/Guayaquil"),
    "tromso":  (69.6492, 18.9553, "Europe/Oslo"),
}
KNOWN = [
    ("london", date(2024, 6, 21), "04:43", "21:21"),
    ("london", date(2024, 12, 21), "08:04", "15:53"),
    ("newyork", date(2024, 12, 21), "07:17", "16:32"),
    ("newyork", date(2024, 6, 20), "05:25", "20:30"),
    ("sydney", date(2024, 12, 21), "05:41", "20:05"),
    ("quito", date(2024, 3, 20), "06:18", "18:24"),
]


def minutes(hhmm: str) -> int:
    h, m = hhmm.split(":")
    return int(h) * 60 + int(m)


def cfg(place: str, dark=-20, light=20) -> dict:
    lat, lon, _ = PLACES[place]
    return {"lat": lat, "lon": lon, "offset_minutes_dark": dark, "offset_minutes_light": light}


class SunriseSunset(unittest.TestCase):
    def test_known_times(self):
        for place, day, rise, sets in KNOWN:
            with self.subTest(f"{place} {day}"):
                lat, lon, tz = PLACES[place]
                ev = rs.local_events(day, lat, lon, ZoneInfo(tz))
                got_rise = ev["sunrise"].hour * 60 + ev["sunrise"].minute + ev["sunrise"].second / 60
                got_set = ev["sunset"].hour * 60 + ev["sunset"].minute + ev["sunset"].second / 60
                self.assertLess(abs(got_rise - minutes(rise)), 2, ev["sunrise"])
                self.assertLess(abs(got_set - minutes(sets)), 2, ev["sunset"])

    def test_sydney_solstice_day_length(self):
        lat, lon, tz = PLACES["sydney"]
        ev = rs.local_events(date(2024, 12, 21), lat, lon, ZoneInfo(tz))
        length = (ev["sunset"] - ev["sunrise"]).total_seconds() / 60
        self.assertLess(abs(length - (14 * 60 + 24)), 2)

    def test_polar_day_and_night(self):
        lat, lon, tz = PLACES["tromso"]
        summer = rs.local_events(date(2024, 6, 21), lat, lon, ZoneInfo(tz))
        winter = rs.local_events(date(2024, 12, 21), lat, lon, ZoneInfo(tz))
        self.assertEqual((summer["sunrise"], summer["sunset"], summer["polar"]), (None, None, "day"))
        self.assertEqual((winter["sunrise"], winter["sunset"], winter["polar"]), (None, None, "night"))


class LightAndDark(unittest.TestCase):
    def at(self, place, when):
        return datetime.fromisoformat(when).replace(tzinfo=ZoneInfo(PLACES[place][2]))

    def test_dark_twenty_minutes_before_sunset(self):
        # London 21 Jun: sunset 21:21, so dark from 21:01; sunrise 04:43, light from 05:03
        c = cfg("london")
        self.assertEqual(rs.mode_at(self.at("london", "2024-06-21T20:55"), c)["mode"], "light")
        r = rs.mode_at(self.at("london", "2024-06-21T21:05"), c)
        self.assertEqual(r["mode"], "dark")
        self.assertEqual(r["next_mode"], "light")
        self.assertEqual(r["next"][:10], "2024-06-22")
        self.assertLess(abs(minutes(r["next_hhmm"]) - minutes("05:03")), 2)
        self.assertEqual(rs.mode_at(self.at("london", "2024-06-21T03:00"), c)["mode"], "dark")

    def test_next_is_today_during_the_day(self):
        r = rs.mode_at(self.at("london", "2024-12-21T12:00"), cfg("london"))
        self.assertEqual((r["mode"], r["next_mode"], r["next"][:10]), ("light", "dark", "2024-12-21"))
        self.assertLess(abs(minutes(r["next_hhmm"]) - minutes("15:33")), 2)

    def test_offsets_across_midnight(self):
        # an offset can push a switch past midnight: dark 3 h after sunset
        r = rs.mode_at(self.at("london", "2024-06-21T23:30"), cfg("london", dark=180))
        self.assertEqual(r["mode"], "light")
        self.assertEqual(r["next"][:10], "2024-06-22")
        self.assertLess(abs(minutes(r["next_hhmm"]) - minutes("00:21")), 2)

    def test_polar_modes_and_the_next_boundary(self):
        c = cfg("tromso")
        summer = rs.mode_at(self.at("tromso", "2024-06-21T02:00"), c)
        self.assertEqual((summer["mode"], summer["next_mode"]), ("light", "dark"))
        self.assertEqual(summer["next"][:7], "2024-07")     # the first sunset is weeks away
        winter = rs.mode_at(self.at("tromso", "2024-12-21T12:00"), c)
        self.assertEqual((winter["mode"], winter["next_mode"]), ("dark", "light"))
        self.assertEqual(winter["next"][:7], "2025-01")


class Command(unittest.TestCase):
    def run_sun(self, toml: str, *args, **env):
        with tempfile.TemporaryDirectory() as d:
            conf = Path(d) / "mode.toml"
            conf.write_text(toml)
            return subprocess.run([str(SCRIPT), "--config", str(conf), *args], capture_output=True,
                                  text=True, env={**os.environ, "TZ": "Europe/London", **env})

    def test_json_out(self):
        p = self.run_sun("lat = 51.5074\nlon = -0.1278\n", RICE_NOW="2024-06-21T21:05")
        self.assertEqual(p.returncode, 0, p.stderr)
        out = json.loads(p.stdout)
        self.assertEqual(out["mode"], "dark")
        self.assertEqual(set(out), {"mode", "next", "next_epoch", "next_mode", "next_hhmm", "sunrise", "sunset"})
        self.assertGreater(out["next_epoch"], datetime(2024, 6, 21, 21, 5).timestamp())

    def test_blank_location_is_explained(self):
        p = self.run_sun('lat = ""\nlon = ""\n')
        self.assertEqual(p.returncode, 2)
        self.assertIn("set lat in", p.stderr)
        p = self.run_sun("lat = 95\nlon = 0\n")
        self.assertEqual(p.returncode, 2)

    def test_the_shipped_settings_are_placeholders(self):
        shipped = REPO / "switcher/.local/share/rice/mode.toml"
        p = subprocess.run([str(SCRIPT), "--config", str(shipped)], capture_output=True, text=True)
        self.assertEqual(p.returncode, 2, "don't ship a location")
        self.assertIn("set lat", p.stderr)


if __name__ == "__main__":
    unittest.main()
