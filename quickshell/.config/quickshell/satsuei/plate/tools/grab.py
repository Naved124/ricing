#!/usr/bin/env python3
"""Draw Satsuei's plate and pass outside Quickshell, through PySide6.

    grab.py --out plate.png [--hour 7.2] [--size 1920x1080] [--plate PATH] [--off rays,motes]
        one frame of the pass over the seed plate (or PATH, through satsuei-wall
        theme for its light source; its blur maps made in a scratch folder)
    grab.py --bench [--frames 240] [--size 1920x1080]
        GPU time of the pass a frame, from OpenGL timer queries around the
        scene's render pass (the scene is only the pass), with time moving as
        it does on the desktop (the window's clear and the swap's blit are in
        it too, so it's a little over the pass alone). On the laptop:
            python3 ~/.config/quickshell/satsuei/plate/tools/grab.py --bench
        Headless here it needs xvfb-run and QSG_RHI_BACKEND=opengl, and the
        number is the software rasterizer's, not a GPU's.

Runs the shell's own Pass.qml, with the Quickshell stand-ins the tests use
(tests/qsstub) for the imports it doesn't draw with.
"""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import json
import os
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
SHELL = HERE.parents[1]
REPO = SHELL.parents[3]
SEED = REPO / "rices/.config/rices/satsuei/seed"
STUB = REPO / "tests/qsstub"


def gl():
    for name in ("libOpenGL.so.0", "libGL.so.1"):
        try:
            lib = ctypes.CDLL(name)
            lib.glGetQueryObjectui64v.argtypes = [ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(ctypes.c_uint64)]
            return lib
        except (OSError, AttributeError):
            continue
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--size", default="1920x1080")
    ap.add_argument("--out", type=Path)
    ap.add_argument("--hour", type=float, default=7.2)
    ap.add_argument("--time", type=float, default=12.0)
    ap.add_argument("--plate", type=Path)
    ap.add_argument("--off", default="", help="effects off: bloom,rays,motes,grain,grade,pass")
    ap.add_argument("--on", default="", help="effects on (grain is off by default)")
    ap.add_argument("--night", action="store_true")
    ap.add_argument("--bench", action="store_true")
    ap.add_argument("--frames", type=int, default=240)
    a = ap.parse_args()
    w, h = (int(v) for v in a.size.split("x"))

    scratch = tempfile.TemporaryDirectory()
    if a.plate:
        env = {**os.environ, "HOME": scratch.name, "XDG_STATE_HOME": scratch.name + "/state",
               "XDG_DATA_HOME": scratch.name + "/data", "SATSUEI_NO_APPLY": "1", "SATSUEI_QUIET": "1"}
        subprocess.run([str(REPO / "switcher/.local/bin/satsuei-wall"), "set", str(a.plate)], env=env, check=True)
        t = json.loads((Path(scratch.name) / "state/satsuei/theme.json").read_text())
    else:
        t = json.loads((SEED / "theme.json").read_text())
        t.update(plate=str(SEED / t["plate"]), bloom=str(SEED / t["bloom"]), soft=str(SEED / t["soft"]))
    fx = {"bloom": 1, "rays": 1, "motes": 1, "grain": 0, "grade": 1, "pass": 1}
    for k in filter(None, a.on.split(",")):
        fx[k] = 1
    for k in filter(None, a.off.split(",")):
        fx[k] = 0
    opts = {"plate": "file://" + t["plate"], "bloom": "file://" + t["bloom"], "soft": "file://" + t["soft"],
            "animated": bool(t.get("animated")), "light": [t["lightX"], t["lightY"]], "bright": t["bright"],
            "hour": a.hour, "night": a.night, "time": a.time, "fx": fx, "expo": 1.0}

    sys.path.insert(0, str(REPO / "tests"))
    import qs_smoke
    root = Path(scratch.name) / "qml"
    root.mkdir()
    dst = qs_smoke.prepare(SHELL, root)
    shutil.copy(HERE / "Harness.qml", dst / "Harness.qml")

    from PySide6.QtCore import QObject, Qt, QTimer, QUrl
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQuick import QQuickView

    app = QGuiApplication(sys.argv[:1])
    view = QQuickView()
    view.engine().addImportPath(str(STUB))
    view.engine().addImportPath(str(root))
    view.setInitialProperties({"opts": opts})
    view.setResizeMode(QQuickView.SizeRootObjectToView)
    view.setSource(QUrl.fromLocalFile(str(dst / "Harness.qml")))
    for e in view.errors():
        print(e.toString(), file=sys.stderr)
    if view.status() != QQuickView.Ready:
        return 1
    view.resize(w, h)
    view.show()
    pas = view.rootObject().findChild(QObject, "pass")

    if a.bench:
        lib = gl()
        GL_TIME_ELAPSED = 0x88BF
        GL_QUERY_RESULT = 0x8866
        ids = (ctypes.c_uint * 1)()
        state = {"made": False, "open": False, "ns": [], "frames": 0, "t0": 0.0}

        def begin():
            if lib is None:
                return
            if not state["made"]:
                lib.glGenQueries(1, ids)
                state["made"] = True
            lib.glBeginQuery(GL_TIME_ELAPSED, ids[0])
            state["open"] = True

        def end():
            if lib is None or not state["open"]:
                return
            lib.glEndQuery(GL_TIME_ELAPSED)
            v = ctypes.c_uint64(0)
            lib.glGetQueryObjectui64v(ids[0], GL_QUERY_RESULT, ctypes.byref(v))
            state["open"] = False
            if state["frames"] > 30:
                state["ns"].append(v.value)

        # Qt's OpenGL backend records a frame's commands and runs them at its
        # end, so the query has to wrap the whole frame
        view.beforeFrameBegin.connect(begin, Qt.DirectConnection)
        view.afterFrameEnd.connect(end, Qt.DirectConnection)

        def step():
            pas.setProperty("time", pas.property("time") + 1 / 30)

        def swapped():
            state["frames"] += 1
            if state["frames"] == 30:
                state["t0"] = time.time()
            if state["frames"] >= 30 + a.frames:
                ns = state["ns"]
                el = time.time() - state["t0"]
                if ns:
                    ms = [v / 1e6 for v in ns]
                    print(json.dumps({"size": [w, h], "frames": len(ms), "gpu_ms_median": round(statistics.median(ms), 3),
                                      "gpu_ms_p95": round(sorted(ms)[int(len(ms) * 0.95) - 1], 3),
                                      "wall_ms_frame": round(el / a.frames * 1000, 2),
                                      "renderer": os.environ.get("QSG_RHI_BACKEND", "default")}))
                else:
                    print(json.dumps({"error": "no GL timer queries (not an OpenGL scene graph?)",
                                      "wall_ms_frame": round(el / a.frames * 1000, 2)}))
                sys.stdout.flush()
                os._exit(0)
            QTimer.singleShot(0, step)

        view.frameSwapped.connect(swapped)
        QTimer.singleShot(200, step)
    else:
        def grab():
            img = view.grabWindow()
            if a.out:
                img.save(str(a.out))
            app.quit()
        QTimer.singleShot(1500, grab)
    app.exec()
    return 0


if __name__ == "__main__":
    sys.exit(main())
