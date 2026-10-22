"""The shared audio package: PipeWire and WirePlumber set for the best sound,
and what install --fresh brings for it."""
import re
import subprocess
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
AUDIO = REPO / "audio/.config"
CONFS = {
    "pipewire": AUDIO / "pipewire/pipewire.conf.d/10-rice-hifi.conf",
    "pulse": AUDIO / "pipewire/pipewire-pulse.conf.d/10-rice-hifi.conf",
    "client": AUDIO / "pipewire/client.conf.d/10-rice-hifi.conf",
    "bluetooth": AUDIO / "wireplumber/wireplumber.conf.d/50-rice-bluetooth.conf",
    "alsa": AUDIO / "wireplumber/wireplumber.conf.d/51-rice-alsa.conf",
}


def body(path):
    """The file without comments or quoted strings, for the bracket count."""
    text = re.sub(r"#.*", "", path.read_text())
    return re.sub(r'"[^"]*"', '""', text)


def bash_array(name):
    r = subprocess.run(["bash", "-c", f'{name}=(); eval "$(sed -n "/^{name}=(/,/^)/p" {REPO}/install)"; '
                        f'printf "%s\\n" "${{{name}[@]}}"'], capture_output=True, text=True, check=True)
    return r.stdout.split()


class Audio(unittest.TestCase):
    def test_installed_by_stow(self):
        r = subprocess.run(["bash", "-c", f'packages=(); eval "$(grep -m1 "^packages=" {REPO}/install)"; '
                            'echo "${packages[@]}"'], capture_output=True, text=True, check=True)
        self.assertIn("audio", r.stdout.split())

    def test_confs_are_balanced(self):
        for name, path in CONFS.items():
            text = body(path)
            for o, c in ("{}", "[]"):
                self.assertEqual(text.count(o), text.count(c), f"{name}: {o}{c} unbalanced")

    def test_wired_is_bit_perfect_where_it_can_be(self):
        text = CONFS["pipewire"].read_text()
        rates = re.search(r"default\.clock\.allowed-rates\s*=\s*\[([^\]]*)\]", text)
        self.assertTrue(rates, "no allowed-rates")
        for rate in ("44100", "48000", "96000"):
            self.assertIn(rate, rates.group(1).split())
        for name in ("pulse", "client", "alsa"):
            self.assertRegex(CONFS[name].read_text(), r"resample\.quality\s*=\s*10\b", name)
        self.assertRegex(CONFS["alsa"].read_text(), r"session\.suspend-timeout-seconds\s*=\s*0\b")

    def test_bluetooth_keeps_its_quality(self):
        text = CONFS["bluetooth"].read_text()
        self.assertRegex(text, r"bluetooth\.autoswitch-to-headset-profile\s*=\s*false")
        self.assertRegex(text, r'bluez5\.a2dp\.ldac\.quality\s*=\s*"auto"')
        self.assertRegex(text, r"bluez5\.enable-sbc-xq\s*=\s*true")
        # a codec list would shut out LHDC and any codec added later
        self.assertNotRegex(body(CONFS["bluetooth"]), r"bluez5\.codecs\s*=")

    def test_fresh_brings_the_codecs_and_firmware(self):
        pkgs = bash_array("fresh_pkgs")
        for pkg in ("pipewire-audio", "sof-firmware", "alsa-ucm-conf", "rtkit"):
            self.assertIn(pkg, pkgs)

    def test_lhdc_is_offered_and_can_fail(self):
        text = (REPO / "install").read_text()
        self.assertIn("lhdc=(liblhdcv5 pipewire-bluez5-lhdc-git wireplumber-lhdc-config)", text)
        step = text[text.index("lhdc=("):]
        step = step[:step.index("\n    fi\n") + 8]
        self.assertIn("ask ", step)
        self.assertIn('warn "LHDC', step)   # a failed build only warns: set -e doesn't stop the install


if __name__ == "__main__":
    unittest.main()
