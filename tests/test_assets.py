"""Paper's generated images: rices/paper/assets/gen.py must be repeatable,
and the committed PNGs must be what it draws by default."""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ASSETS = REPO / "rices/.config/rices/paper/assets"

try:
    from PIL import Image, ImageChops
except ImportError:          # Pillow is optional outside Paper
    Image = None


@unittest.skipUnless(Image, "Pillow not installed")
class PaperAssets(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.runs = []
        for i in range(2):
            out = Path(cls.tmp.name) / str(i)
            subprocess.run([sys.executable, str(ASSETS / "gen.py"), "--out", str(out), "--size", "640x360"],
                           check=True, capture_output=True)
            cls.runs.append(out)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_same_seed_same_pixels(self):
        for name in ("wall.png", "paper-tex.png", "ink-wear.png", "logo.png"):
            with self.subTest(name):
                a, b = (Image.open(r / name).convert("RGBA") for r in self.runs)
                self.assertIsNone(ImageChops.difference(a, b).getbbox())

    def test_sizes(self):
        self.assertEqual(Image.open(self.runs[0] / "wall.png").size, (640, 360))
        self.assertEqual(Image.open(ASSETS / "wall.png").size, (1920, 1080))
        self.assertEqual(Image.open(ASSETS / "paper-tex.png").size, (512, 512))

    def test_texture_tiles(self):
        """The left and right (and top and bottom) edges continue into each other."""
        tex = Image.open(ASSETS / "paper-tex.png").convert("L")
        w, h = tex.size
        px = tex.load()
        seam = sum(abs(px[0, y] - px[w - 1, y]) for y in range(h)) / h
        inner = sum(abs(px[w // 2, y] - px[w // 2 + 1, y]) for y in range(h)) / h
        self.assertLess(seam, inner * 2.5 + 1)
        seam = sum(abs(px[x, 0] - px[x, h - 1]) for x in range(w)) / w
        self.assertLess(seam, inner * 2.5 + 1)

    def test_wall_is_light_and_quiet(self):
        """The desk is the wall colour almost everywhere: nothing loud behind the windows."""
        wall = Image.open(ASSETS / "wall.png").convert("L")
        hist = wall.histogram()
        near = sum(hist[215:240])
        self.assertGreater(near / (wall.width * wall.height), 0.95)


if __name__ == "__main__":
    unittest.main()
