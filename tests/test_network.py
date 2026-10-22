"""The network widget every rice shares (the shared shell's Network.qml and
Wifi.qml, through nmcli), how each rice opens it, the bar's one network mark,
and system/install --network (tested in test_system)."""

import os
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SHELLS = REPO / "quickshell/.config/quickshell"
sys.path.insert(0, str(REPO / "tests"))


def has_pyside() -> bool:
    try:
        import PySide6.QtQml  # noqa: F401
    except ImportError:
        return False
    return True


class Widget(unittest.TestCase):
    def test_it_does_the_usual_things(self):
        wifi = (SHELLS / "rice/Wifi.qml").read_text()
        for needle in ('"nmcli", "monitor"', "device wifi list --rescan no", '"device", "wifi", "rescan"',
                       '"radio", "wifi"', "device wifi connect", "IFS= read -r p", "hidden yes",
                       '"connection", "up", "uuid"', '"connection", "down", "uuid"', '"connection", "delete", "uuid"',
                       '"connection.autoconnect"', '"ipv4.dns", list, "ipv4.ignore-auto-dns"', "802-11-wireless-security.psk",
                       "running: root.watching"):
            self.assertIn(needle, wifi)
        net = (SHELLS / "rice/Network.qml").read_text()
        for needle in ('"rice-network"', "Theme.role(n)", "meta.fonts?.ui", "meta.shape?.panel", "Wifi.watching = open",
                       '"Cloudflare"', '"Google"', '"Quad9"', '"Automatic"', "Wifi.setDns(", "secret: true",
                       "Wifi.connect(", '"+ Hidden network…"', "Wifi.forget(", "Wifi.reveal(", "Wifi.autoconnect(",
                       "Wifi.setRadio(", "Wifi.rescan()", "Wifi.down("):
            self.assertIn(needle, net)
        shell = (SHELLS / "rice/shell.qml").read_text()
        for needle in ("Network { id: network }", 'target: "network"', "function open(): void"):
            self.assertIn(needle, shell)

    def test_every_rice_opens_it_from_its_wifi_tile(self):
        for rice, tile in (("nacre", "center/Toggle.qml"), ("abyss", "center/Toggle.qml"), ("paper", "center/Check.qml"),
                           ("satsuei", "center/Tile.qml")):
            with self.subTest(rice):
                t = (SHELLS / rice / tile).read_text()
                for needle in ("property bool doubleOpens: false", "onDoubleClicked", "single.restart()", "root.secondary()"):
                    self.assertIn(needle, t)
                center = (SHELLS / rice / "center/Center.qml").read_text()
                self.assertIn("doubleOpens: true", center)
                self.assertIn('["qs", "-c", "rice", "ipc", "call", "network", "open"]', center)
                self.assertNotIn("nmtui", center)

    def test_one_network_mark_on_each_bar(self):
        for rice, f in (("nacre", "bar/Tray.qml"), ("paper", "bar/Tray.qml"), ("abyss", "bar/Status.qml"),
                        ("satsuei", "bar/Status.qml")):
            with self.subTest(rice):
                self.assertIn("nm-applet|networkmanager|network-manager|iwgtk|connman", (SHELLS / rice / f).read_text())

    @unittest.skipUnless(has_pyside(), "needs PySide6")
    def test_it_reads_nmcli(self):
        import qs_smoke
        errors, pokes = qs_smoke.smoke(SHELLS / "rice", seconds=3.2, poke=REPO / "tests/pokes/rice-network.qml")
        self.assertEqual(errors, [])
        read, fields = pokes
        self.assertEqual((read["radio"], read["device"]), (True, "wlan0"))
        # one row per name (the strongest), hidden ones left out, the one in use first
        self.assertEqual([n["ssid"] for n in read["networks"]], ["Home", "Cafe:Guest", "Neighbour"])
        self.assertEqual([n["saved"] for n in read["networks"]], [True, False, False])
        self.assertEqual(read["networks"][1]["security"], "")
        self.assertEqual(read["saved"], ["Home", "Office"])                # Wi-Fi only
        a = read["active"]
        self.assertEqual((a["name"], a["uuid"], a["ip"], a["gateway"], a["dns"]),
                         ("Home", "1111-aaaa", "192.168.1.23/24", "192.168.1.1", ["192.168.1.1"]))
        self.assertEqual(fields["f"], ["a:b", "c\\d", ""])


if __name__ == "__main__":
    unittest.main()
