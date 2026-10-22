#!/usr/bin/env python3
"""Draw a shell under the Quickshell stand-ins and save what one screen shows.

    tests/qs_shot.py quickshell/.config/quickshell/satsuei --out shot.png
        [--poke FILE] [--at 2.5] [--screen DP-1] [--size 1920x1080]

The stand-ins' windows aren't real windows, so this collects every
PanelWindow on the screen once the shell has run `--at` seconds (a poke can
open panels first), lays their contents out where their anchors and margins
put them, stacked by layer (background, bottom, top, overlay), in one real
window, and grabs it. Hyprland's blur isn't there, so glass looks thinner
than on the desktop. Needs PySide6 and a GL context for shaders (xvfb-run
with QSG_RHI_BACKEND=opengl).
"""

from __future__ import annotations

import argparse
import os
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import qs_smoke  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("shell", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--poke", type=Path)
    ap.add_argument("--at", type=float, default=2.5)
    ap.add_argument("--screen", default="DP-1")
    ap.add_argument("--size", default="1920x1080")
    a = ap.parse_args()
    w, h = (int(v) for v in a.size.split("x"))
    os.environ["QML_XHR_ALLOW_FILE_READ"] = "1"

    from PySide6.QtCore import QObject, QTimer, QUrl
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine, QQmlEngine, QQmlExpression
    from PySide6.QtQuick import QQuickItem, QQuickView

    app = QGuiApplication(sys.argv[:1])
    tmp = tempfile.TemporaryDirectory()
    root = Path(tmp.name)
    dst = qs_smoke.prepare(a.shell.resolve(), root)
    if a.poke:
        (dst / "Poke.qml").write_text(qs_smoke.transform(a.poke.read_text()))
    engine = QQmlApplicationEngine()
    engine.addImportPath(str(qs_smoke.STUB))
    engine.addImportPath(str(root))
    engine.load(QUrl.fromLocalFile(str(dst / "shell.qml")))
    if not engine.rootObjects():
        print("shell.qml did not load", file=sys.stderr)
        return 1
    if a.poke:
        QTimer.singleShot(400, lambda: engine.load(QUrl.fromLocalFile(str(dst / "Poke.qml"))))

    view = QQuickView()
    view.setColor("black")
    view.resize(w, h)
    view.show()
    desk = view.contentItem()

    def windows() -> list:
        out = []

        def walk(o):
            for c in o.children():
                mo = c.metaObject()
                if mo.indexOfProperty("panelAnchors") >= 0 and mo.indexOfProperty("contentItem") >= 0:
                    out.append(c)
                walk(c)
        for r in engine.rootObjects():
            walk(r)
        return out

    def place():
        stack = []
        for win in windows():
            def prop(path):
                e = QQmlExpression(QQmlEngine.contextForObject(win), win, path)
                v, _ = e.evaluate()
                return v
            name = prop("screen ? screen.name : null")
            if name not in (None, a.screen) or not win.property("visible"):
                continue
            item = win.property("contentItem")
            if not isinstance(item, QQuickItem):
                continue
            L, R, T, B = (bool(prop(f"panelAnchors.{k}")) for k in ("left", "right", "top", "bottom"))
            ml, mr, mt, mb = (int(prop(f"margins.{k}") or 0) for k in ("left", "right", "top", "bottom"))
            ww = w - ml - mr if L and R else float(win.property("width"))
            wh = h - mt - mb if T and B else float(win.property("height"))
            x = ml if L or not R else w - mr - ww
            y = mt if T or not B else h - mb - wh
            if not (L or R):
                x = (w - ww) / 2
            if not (T or B):
                y = (h - wh) / 2
            layer = prop("layershell.layer")
            stack.append((int(layer if layer is not None else 2), item, x, y, ww, wh))
            if os.environ.get("QS_SHOT_DEBUG"):
                print(prop("layershell.namespace"), layer, x, y, ww, wh, file=sys.stderr)
        for z, (layer, item, x, y, ww, wh) in enumerate(sorted(stack, key=lambda s: s[0])):
            item.setParentItem(desk)
            item.setProperty("x", x)
            item.setProperty("y", y)
            item.setProperty("width", ww)
            item.setProperty("height", wh)
            item.setZ(z)

    def grab():
        img = view.grabWindow()
        img.save(str(a.out))
        app.quit()

    QTimer.singleShot(int(a.at * 1000), place)
    QTimer.singleShot(int(a.at * 1000) + 900, grab)
    app.exec()
    return 0


if __name__ == "__main__":
    sys.exit(main())
