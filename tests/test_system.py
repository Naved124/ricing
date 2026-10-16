"""Runs system/install against a scratch root (RICE_SYSTEM_ROOT) with fake
systemctl, mkinitcpio, plymouth-set-default-theme, findmnt and pacman, and
checks what it writes, that it backs up and undoes, and that it never touches
Limine's boot entries.
"""

import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
INSTALL = REPO / "system/install"

FAKE = r"""#!/bin/sh
echo "$(basename "$0") $*" >> "$RICE_TEST_LOG"
case "$(basename "$0")" in
    findmnt) echo "$RICE_SYSTEM_ROOT/boot" ;;
    plymouth-set-default-theme)
        if [ -n "$1" ]; then echo "$1" > "$RICE_TEST_PLY"; else cat "$RICE_TEST_PLY" 2>/dev/null || echo bgrt; fi ;;
esac
exit 0
"""
FAKES = ["systemctl", "mkinitcpio", "plymouth-set-default-theme", "findmnt", "pacman",
         "greetd", "regreet", "cage"]

LIMINE = """\
timeout: 3
wallpaper: boot():/old.png
term_foreground: ffffff

/Arch Linux
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: root=UUID=1234 rw
    module_path: boot():/initramfs-linux.img
"""
ENTRIES = LIMINE[LIMINE.index("/Arch Linux"):]


class SystemInstall(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.root, self.home, bin_ = t / "root", t / "home", t / "bin"

        rices = self.home / ".config/rices"
        shutil.copytree(REPO / "rices/.config/rices", rices,
                        ignore=shutil.ignore_patterns("build", "current"))
        (rices / "current").symlink_to("nacre")
        subprocess.run([str(REPO / "render/.local/bin/rice-render"), "nacre", "-q"], check=True,
                       env=dict(os.environ, RICE_DIR=str(rices), HOME=str(self.home),
                                RICE_TEMPLATES=str(REPO / "render/.local/share/rice/templates"),
                                RICE_INSTALL_ROOT=str(t / "inst")))

        (self.root / "boot").mkdir(parents=True)
        (self.root / "boot/limine.conf").write_text(LIMINE)
        (self.root / "etc/kernel").mkdir(parents=True)
        (self.root / "etc/kernel/cmdline").write_text("root=UUID=1234 rw\n")
        (self.root / "etc/mkinitcpio.conf").write_text(
            "MODULES=()\nHOOKS=(base udev autodetect microcode modconf kms keyboard block filesystems fsck)\n")
        dm = self.root / "etc/systemd/system/display-manager.service"
        dm.parent.mkdir(parents=True)
        dm.symlink_to("/usr/lib/systemd/system/sddm.service")

        bin_.mkdir()
        for name in FAKES:
            p = bin_ / name
            p.write_text(FAKE)
            p.chmod(p.stat().st_mode | stat.S_IXUSR)
        self.log = t / "calls.log"
        self.env = dict(os.environ, PATH=f"{bin_}:/usr/bin:/bin", RICE_SYSTEM_ROOT=str(self.root),
                        RICE_SYSTEM_HOME=str(self.home), RICE_TEST_LOG=str(self.log),
                        RICE_TEST_PLY=str(t / "plymouth-theme"))

    def tearDown(self):
        self.tmp.cleanup()

    def run_install(self, *args):
        p = subprocess.run([str(INSTALL), *args], env=self.env, capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        return p

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_limine_block_is_added_once_and_entries_are_untouched(self):
        for _ in range(2):
            self.run_install("--limine")
        conf = (self.root / "boot/limine.conf").read_text()
        self.assertEqual(conf.count("# >>> rice"), 1)
        self.assertTrue(conf.endswith(ENTRIES), conf)
        self.assertIn("wallpaper: boot():/rice-wallpaper.png", conf)
        self.assertIn("# (rice) wallpaper: boot():/old.png", conf)
        self.assertIn("# (rice) term_foreground: ffffff", conf)
        self.assertIn("timeout: 3", conf.splitlines())          # not ours: left alone
        palette = next(l for l in conf.splitlines() if l.startswith("term_palette:"))
        self.assertEqual(len(palette.split(":", 1)[1].strip().split(";")), 8)
        self.assertTrue((self.root / "boot/rice-wallpaper.png").is_file())

    def test_limine_skipped_under_secure_boot(self):
        efivars = self.root / "sys/firmware/efi/efivars"
        efivars.mkdir(parents=True)
        (efivars / "SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c").write_bytes(b"\x06\x00\x00\x00\x01")
        p = self.run_install("--limine")
        self.assertIn("Secure Boot", p.stderr)
        self.assertEqual((self.root / "boot/limine.conf").read_text(), LIMINE)

    def test_greetd_switches_display_manager(self):
        self.run_install("--greetd")
        etc = self.root / "etc/greetd"
        for f in ("config.toml", "regreet.toml", "regreet.css"):
            self.assertTrue((etc / f).is_file(), f)
        self.assertIn("cage", (etc / "config.toml").read_text())
        calls = self.calls()
        self.assertIn("systemctl disable sddm.service", calls)
        self.assertIn("systemctl enable greetd.service", calls)

    def test_plymouth_hook_cmdline_and_rebuild(self):
        for _ in range(2):
            self.run_install("--plymouth")
        hooks = (self.root / "etc/mkinitcpio.conf").read_text()
        self.assertIn("HOOKS=(base udev plymouth autodetect", hooks)
        self.assertEqual(hooks.count("plymouth"), 1)
        self.assertEqual((self.root / "etc/kernel/cmdline").read_text(), "root=UUID=1234 rw quiet splash\n")
        theme = self.root / "usr/share/plymouth/themes/rice"
        for f in ("rice.plymouth", "rice.script", "logo.png", "bar.png"):
            self.assertTrue((theme / f).is_file(), f)
        calls = self.calls()
        self.assertIn("plymouth-set-default-theme rice", calls)
        # rebuilt once: the second run found nothing to change
        self.assertEqual(calls.count("mkinitcpio -P"), 1)

    def test_undo_restores_everything(self):
        before = {p: (self.root / p).read_text() for p in
                  ("boot/limine.conf", "etc/mkinitcpio.conf", "etc/kernel/cmdline")}
        self.run_install("--all")
        self.run_install("--undo")
        for p, text in before.items():
            self.assertEqual((self.root / p).read_text(), text, p)
        self.assertFalse((self.root / "etc/greetd").exists() and any((self.root / "etc/greetd").iterdir()))
        self.assertFalse((self.root / "usr/share/plymouth/themes/rice").exists())
        self.assertFalse((self.root / "boot/rice-wallpaper.png").exists())
        calls = self.calls()
        self.assertIn("systemctl enable sddm.service", calls)
        self.assertIn("plymouth-set-default-theme bgrt", calls)

    def test_dry_run_changes_nothing(self):
        def snapshot():
            return {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        before = snapshot()
        self.run_install("--all", "--dry-run")
        self.assertEqual(snapshot(), before)
        self.assertFalse((self.root / "var/backups").exists())

    def test_refresh_only_touches_what_is_set_up(self):
        self.run_install("--limine")
        self.log.unlink()
        self.run_install("--refresh")
        self.assertFalse(any("greetd" in c or "plymouth" in c for c in self.calls()))


if __name__ == "__main__":
    unittest.main()
