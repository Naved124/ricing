"""Light mode's rendered output, pinned.

tests/snapshots/light.sha256 holds a sha256 for every file rice-render writes
for each rice in light mode. A palette or template change that is meant to
change light output refreshes it:

    RICE_SNAPSHOT_UPDATE=1 python3 -m unittest tests.test_snapshot
"""

import hashlib
import importlib.machinery
import importlib.util
import os
import shutil
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCRIPT = REPO / "render/.local/bin/rice-render"
RICES = REPO / "rices/.config/rices"
SNAPSHOT = REPO / "tests/snapshots/light.sha256"
TEMPLATES = REPO / "render/.local/share/rice/templates"

loader = importlib.machinery.SourceFileLoader("rice_render_snapshot", str(SCRIPT))
spec = importlib.util.spec_from_loader("rice_render_snapshot", loader)
rr = importlib.util.module_from_spec(spec)
loader.exec_module(rr)


def rice_names() -> list[str]:
    """Every rice with a light mode (a dark-only one like Abyss has no light output)."""
    import tomllib
    return sorted(p.name for p in RICES.iterdir()
                  if p.is_dir() and not p.is_symlink() and (p / "palette.toml").exists()
                  and "light" in rr.declared_modes(tomllib.loads((p / "palette.toml").read_text()),
                                                   p / "palette.toml"))


def light_hashes() -> dict[str, str]:
    """Render every rice into a scratch copy; hash each output by its place in it."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        rices = root / "rices"
        shutil.copytree(RICES, rices, ignore=shutil.ignore_patterns("build", "current"))
        home = root / "home"
        old = rr.HOME, rr.INSTALL_ROOT, rr.SHARED
        rr.HOME = rr.INSTALL_ROOT = home
        rr.SHARED = TEMPLATES
        # an overlay the user has written (Satsuei's plate, Golden Gate's
        # accent) mustn't reach the pins: the palettes render as committed
        old_state = os.environ.get("XDG_STATE_HOME")
        os.environ["XDG_STATE_HOME"] = str(root / "state")
        try:
            hashes = {}
            for name in rice_names():
                rice = rices / name
                outputs = rr.outputs_for(rice, rr.load_modes(rice))
                for path, data in outputs.items():
                    rel = path.relative_to(root).as_posix()
                    if "/build/dark/" in rel:
                        continue
                    # light's build moved into build/light/; hash it where it
                    # used to be, so the pins stay comparable
                    rel = rel.replace("/build/light/", "/build/")
                    # the scratch paths differ on every run
                    data = data.replace(str(root).encode(), b"@ROOT@").replace(b"/build/light", b"/build")
                    hashes[rel] = hashlib.sha256(data).hexdigest()
            return dict(sorted(hashes.items()))
        finally:
            rr.HOME, rr.INSTALL_ROOT, rr.SHARED = old
            if old_state is None:
                os.environ.pop("XDG_STATE_HOME", None)
            else:
                os.environ["XDG_STATE_HOME"] = old_state


class LightSnapshot(unittest.TestCase):
    def test_light_output_is_unchanged(self):
        hashes = light_hashes()
        if os.environ.get("RICE_SNAPSHOT_UPDATE"):
            SNAPSHOT.parent.mkdir(exist_ok=True)
            SNAPSHOT.write_text("".join(f"{h}  {p}\n" for p, h in hashes.items()))
        want = {}
        for line in SNAPSHOT.read_text().splitlines():
            h, p = line.split("  ", 1)
            want[p] = h
        self.assertEqual(sorted(hashes), sorted(want), "a different set of files is rendered")
        changed = [p for p in want if hashes[p] != want[p]]
        self.assertEqual(changed, [], "light output changed")


if __name__ == "__main__":
    unittest.main()
