"""tools/relink and the git hooks: a pull that adds a file links it into ~."""
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
NEW = "quickshell/.config/quickshell/paper/bar/Added.qml"


@unittest.skipUnless(shutil.which("stow") and shutil.which("git"), "stow and git needed")
class Relink(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.home = root / "home"
        self.home.mkdir()
        self.clone = root / "ricing"
        self.env = {**os.environ, "HOME": str(self.home), "GIT_CONFIG_NOSYSTEM": "1",
                    "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t",
                    "GIT_COMMITTER_EMAIL": "t@t"}
        self.git("clone", "-q", "--no-hardlinks", str(REPO), str(self.clone), cwd=root)
        # the hooks and scripts as they are in this checkout, committed or not
        shutil.copytree(REPO / ".githooks", self.clone / ".githooks", dirs_exist_ok=True)
        for rel in ("tools/relink", "install"):
            shutil.copy2(REPO / rel, self.clone / rel)
        self.git("add", "-A")
        self.git("commit", "-q", "--allow-empty", "-m", "this checkout's hooks")
        self.git("config", "core.hooksPath", ".githooks")

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args, cwd=None):
        return subprocess.run(["git", *args], cwd=cwd or self.clone, env=self.env,
                              capture_output=True, text=True, check=True)

    def link(self):
        subprocess.run(["stow", "--no-folding", "--ignore=__pycache__", "--ignore=^build$",
                        "-d", str(self.clone), "-t", str(self.home), "switcher", "quickshell"],
                       check=True, env=self.env)

    def add_on_a_branch(self):
        self.git("checkout", "-q", "-b", "incoming")
        (self.clone / NEW).write_text("import QtQuick\nItem {}\n")
        self.git("add", NEW)
        self.git("commit", "-q", "-m", "add a widget")
        self.git("checkout", "-q", "-")

    def test_a_merge_links_the_new_file(self):
        self.link()
        self.add_on_a_branch()
        self.assertFalse((self.home / ".config/quickshell/paper/bar/Added.qml").exists())
        self.git("merge", "-q", "--ff-only", "incoming")
        target = self.home / ".config/quickshell/paper/bar/Added.qml"
        self.assertTrue(target.is_symlink(), "the hook didn't link the new file")
        self.assertEqual(target.resolve(), (self.clone / NEW).resolve())

    def test_an_unlinked_home_is_left_alone(self):
        self.add_on_a_branch()
        self.git("merge", "-q", "--ff-only", "incoming")
        self.assertEqual(list(self.home.iterdir()), [])

    def test_install_uses_the_same_package_list(self):
        r = subprocess.run(["bash", "-c", f'packages=(); eval "$(grep -m1 "^packages=" {REPO}/install)"; '
                            'echo "${packages[@]}"'], capture_output=True, text=True, check=True)
        self.assertIn("quickshell", r.stdout.split())
        for pkg in r.stdout.split():
            self.assertTrue((REPO / pkg).is_dir(), pkg)


if __name__ == "__main__":
    unittest.main()
