#!/usr/bin/env python3
"""Run the reef (../Reef.qml) outside Quickshell, through PySide6, and grab it.

    still.py --out wall.png [--size 1920x1080] [--seconds 20]
        the reef at rest after `seconds` of reef time (gen.py's still)
    still.py --mock --out reef.png [--size 1440x860]
        the mock's side-by-side sequence in real time: 2.5 s, a press at
        (1000, 450), a drag 240 px left over 20 moves, 250 ms, grab
    still.py --bench [--size 1920x1080] [--frames 200]
        frames as fast as they'll go: ms a frame, world and canvas

Colours, hues and the water come from rices/abyss/palette.toml, as Theme.qml
gives them to the shell. Needs PySide6 and a GL context (xvfb-run when
headless, with QSG_RHI_BACKEND=opengl).
"""

from __future__ import annotations

import argparse
import importlib.machinery
import importlib.util
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REEF = HERE.parent
REPO = REEF.parents[4]

loader = importlib.machinery.SourceFileLoader("rice_render", str(REPO / "render/.local/bin/rice-render"))
spec = importlib.util.spec_from_loader("rice_render", loader)
rr = importlib.util.module_from_spec(spec)
loader.exec_module(rr)


def css(hex_: str) -> str:
    """#rrggbb(aa) → rgba(), as Theme.css() hands it to the canvas."""
    r, g, b = (int(hex_[i:i + 2], 16) for i in (1, 3, 5))
    a = int(hex_[7:9], 16) / 255 if len(hex_) > 7 else 1
    return f"rgba({r},{g},{b},{round(a, 3)})"


def look() -> dict:
    data = __import__("tomllib").loads((REPO / "rices/.config/rices/abyss/palette.toml").read_text())
    dark = data["modes"]["dark"]
    c, w = dark["colors"], dark["wallpaper"]
    names = {"ridge": "ridge", "kelp": "kelp", "floorTop": "floor_top", "floorBottom": "floor_bottom",
             "floorLine": "floor_line", "anemoneBase": "anemone_base", "fish": "fish",
             "photophore": "photophore", "plankton": "plankton"}
    return {
        "colors": {k: css(c[v]) for k, v in names.items()},
        # Qt's #aarrggbb
        "kelpColor": "#" + (c["kelp"][7:9] or "ff") + c["kelp"][1:7],
        "hues": {"creatures": w["creatures"], "jellies": w["jellies"], "fans": w["fans"],
                 "anemones": w["anemones"], "sparkle": w["sparkle"], "plankton": w["plankton"],
                 "back": w["back_shift"]},
        "top": w["water_top"], "mid": w["water_mid"], "bottom": w["water_bottom"],
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--size", default="1920x1080")
    ap.add_argument("--seconds", type=float, default=20.0)
    ap.add_argument("--out", type=Path)
    ap.add_argument("--mock", action="store_true")
    ap.add_argument("--bench", action="store_true")
    ap.add_argument("--frames", type=int, default=200)
    ap.add_argument("--set", action="append", default=[], metavar="PROP=VALUE",
                    help="a Reef property, e.g. reduced=true or fps=60")
    a = ap.parse_args()
    w, h = (int(v) for v in a.size.split("x"))

    from PySide6.QtCore import QMetaObject, QObject, QPointF, QTimer, QUrl, Qt, Q_ARG, Q_RETURN_ARG
    from PySide6.QtGui import QGuiApplication, QMouseEvent
    from PySide6.QtQuick import QQuickView

    app = QGuiApplication(sys.argv[:1])
    view = QQuickView()
    view.setInitialProperties({"look": look()})
    view.setResizeMode(QQuickView.SizeRootObjectToView)
    view.setSource(QUrl.fromLocalFile(str(HERE / "Harness.qml")))
    for e in view.errors():
        print(e.toString(), file=sys.stderr)
    if view.status() != QQuickView.Ready:
        return 1
    view.resize(w, h)
    reef = view.rootObject().findChild(QObject, "reef")
    for kv in a.set:
        k, v = kv.split("=", 1)
        reef.setProperty(k, json.loads(v))
    view.show()

    def mouse(kind, x, y, buttons):
        ev = QMouseEvent(kind, QPointF(x, y), QPointF(x, y), Qt.LeftButton if kind != QMouseEvent.Type.MouseMove else Qt.NoButton,
                         buttons, Qt.NoModifier)
        QGuiApplication.sendEvent(view, ev)

    def stats():
        ret = QMetaObject.invokeMethod(reef, "stats", Q_RETURN_ARG("QVariant"))
        return ret.toVariant() if hasattr(ret, "toVariant") else ret

    def grab_and_quit():
        img = view.grabWindow()
        if a.out:
            img.save(str(a.out))
        print(json.dumps(stats()))
        app.quit()

    if a.bench:
        reef.setProperty("fps", 1000)
        frames = [0]
        t0 = [0.0]

        def swapped():
            frames[0] += 1
            if frames[0] == 30:
                t0[0] = time.time()
            if frames[0] == 30 + a.frames:
                el = time.time() - t0[0]
                print(f"{a.frames / el:.1f} fps, {el / a.frames * 1000:.1f} ms a frame (whole loop, llvmpipe), "
                      f"world {reef.property('msWorld'):.2f} ms, canvas {reef.property('msDraw'):.2f} ms")
                app.quit()
        view.frameSwapped.connect(swapped)
    elif a.mock:
        def press():
            mouse(QMouseEvent.Type.MouseButtonPress, 1000, 450, Qt.LeftButton)
            mouse(QMouseEvent.Type.MouseButtonRelease, 1000, 450, Qt.NoButton)
            import math
            for i in range(20):
                QTimer.singleShot(16 * (i + 1), lambda i=i: mouse(QMouseEvent.Type.MouseMove, 1000 - i * 12, 450 + math.sin(i / 3) * 30, Qt.NoButton))
            QTimer.singleShot(16 * 21 + 250, grab_and_quit)
        QTimer.singleShot(2500, press)
    else:
        def still():
            QMetaObject.invokeMethod(reef, "advance", Q_ARG("QVariant", a.seconds))
            QTimer.singleShot(600, grab_and_quit)
        reef.setProperty("running", False)
        QTimer.singleShot(400, still)
    app.exec()
    return 0


if __name__ == "__main__":
    sys.exit(main())
