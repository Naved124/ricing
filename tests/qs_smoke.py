#!/usr/bin/env python3
"""Run a Quickshell config under PySide6 against stand-ins for Quickshell's own
types (tests/qsstub), and report what QML complains about: binding errors,
TypeErrors, missing properties, bad assignments. Nothing is drawn for real
(the software renderer, no Wayland); it catches the mistakes a shell would
print on startup, without Quickshell installed.

    tests/qs_smoke.py quickshell/.config/quickshell/abyss [--seconds 3] [--poke FILE]

Two things Quickshell allows that plain QML can't are renamed in a scratch
copy first: a window's `anchors { top: true … }` (→ panelAnchors) and the
`WlrLayershell.` attached properties (→ layershell). Each folder gets the
qmldir Quickshell makes for it (module qs.<folder>, singletons by their
pragma). `--poke` loads a QML file after the shell that can call into its
singletons (open panels, send notifications) to reach more code; what it
reports with console.warn("POKE:" + JSON) comes back separately.

Exit status 0 when nothing was reported; the messages (and what --poke
reported) are printed as JSON: {"errors": [...], "pokes": [...]}.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
STUB = HERE / "qsstub"

PANEL_BLOCK = re.compile(r"\banchors\s*\{((?:\s*(?:top|bottom|left|right)\s*:\s*(?:true|false)\s*;?)+\s*)\}")
PANEL_ONE = re.compile(r"\banchors\.(top|bottom|left|right)(\s*:\s*(?:true|false)\b)")

# noise from running headless with the software renderer
NOISE = [
    "qt.qpa", "QSGContext", "ShaderEffect", "shader", "Shader", "propertyCache.append",
    "QFont::", "qt.svg", "Cannot open", "QQuickWidget", "XDG_RUNTIME_DIR", "fontconfig",
    "Populating font family", "QOpenGL", "QRhi", "Failed to create", "qt.scenegraph",
    "Software rendering", "not supported", "Could not find a location of the system",
]


def transform(text: str) -> str:
    text = text.replace("WlrLayershell.", "layershell.")
    text = PANEL_BLOCK.sub(lambda m: "panelAnchors {" + m.group(1) + "}", text)
    text = PANEL_ONE.sub(r"panelAnchors.\1\2", text)
    return text


def prepare(shell: Path, root: Path) -> Path:
    dst = root / "qs"
    shutil.copytree(shell, dst, ignore=shutil.ignore_patterns("__pycache__", "tools"))
    for f in dst.rglob("*.qml"):
        f.write_text(transform(f.read_text()))
    for d in [dst, *(p for p in dst.rglob("*") if p.is_dir())]:
        qml = sorted(d.glob("*.qml"))
        if not qml:
            continue
        name = ".".join(d.relative_to(root).parts)
        lines = [f"module {name}"]
        for f in qml:
            single = re.search(r"(?m)^pragma Singleton", f.read_text())
            lines.append(("singleton " if single else "") + f"{f.stem} 1.0 {f.name}")
        (d / "qmldir").write_text("\n".join(lines) + "\n")
    return dst


def run(shell: Path, seconds: float, poke: Path | None, pokes: list | None = None) -> list[str]:
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    os.environ.setdefault("QT_QUICK_BACKEND", "software")
    from PySide6.QtCore import QTimer, QUrl, qInstallMessageHandler, QtMsgType
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine

    found: list[str] = []

    def handler(kind, context, message):
        if kind in (QtMsgType.QtDebugMsg, QtMsgType.QtInfoMsg):
            return
        if message.startswith("POKE:"):
            if pokes is not None:
                pokes.append(json.loads(message[5:]))
            return
        if any(n in message for n in NOISE):
            return
        found.append(message)

    qInstallMessageHandler(handler)
    app = QGuiApplication(sys.argv[:1])
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        dst = prepare(shell, root)
        if poke:
            # written before the engine starts: it caches what's in each folder
            (dst / "Poke.qml").write_text(transform(poke.read_text()))
        engine = QQmlApplicationEngine()
        engine.addImportPath(str(STUB))
        engine.addImportPath(str(root))
        engine.load(QUrl.fromLocalFile(str(dst / "shell.qml")))
        if not engine.rootObjects():
            found.append("shell.qml did not load")
        if poke:
            QTimer.singleShot(400, lambda: engine.load(QUrl.fromLocalFile(str(dst / "Poke.qml"))))
        QTimer.singleShot(int(seconds * 1000), app.quit)
        app.exec()
        del engine
    return found


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("shell", type=Path)
    ap.add_argument("--seconds", type=float, default=3.0)
    ap.add_argument("--poke", type=Path)
    a = ap.parse_args()
    pokes: list = []
    found = run(a.shell.resolve(), a.seconds, a.poke.resolve() if a.poke else None, pokes)
    # the same message from every screen counts once
    unique = list(dict.fromkeys(found))
    print(json.dumps({"errors": unique, "pokes": pokes}, indent=2))
    return 1 if unique else 0


def smoke(shell: Path, seconds: float = 2.5, poke: Path | None = None) -> tuple[list[str], list]:
    """run() in a process of its own (Qt allows one application a process)."""
    import subprocess
    cmd = [sys.executable, str(Path(__file__).resolve()), str(shell), "--seconds", str(seconds)]
    if poke:
        cmd += ["--poke", str(poke)]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=seconds + 60)
    try:
        out = json.loads(p.stdout)
    except json.JSONDecodeError:
        return [f"qs_smoke crashed: {p.stderr.strip()[-2000:]}"], []
    return out["errors"], out["pokes"]


if __name__ == "__main__":
    sys.exit(main())
