"""Draw the fixture character through chars/SceneMatch.qml with a given
target colour and print the colours at its head (the rule's teal) and its body
(the protected pink), as JSON. tests/test_satsuei.py runs it once per
wallpaper accent."""

import json
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SAT = REPO / "quickshell/.config/quickshell/satsuei"
GIF = REPO / "tests/fixtures/satsuei-char/test/dance.gif"


def main(target: str) -> None:
    from PySide6.QtCore import QTimer, QUrl
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQuick import QQuickView

    app = QGuiApplication(sys.argv)
    view = QQuickView()
    view.setColor("transparent")
    qml = f"""
import QtQuick
Item {{
    width: 120; height: 160
    Loader {{
        id: m
        anchors.fill: parent
        source: "{(SAT / 'chars/SceneMatch.qml').as_uri()}"
        onLoaded: {{
            item.rules = [{{ from: "#39c5bb", to: "{target}", tol: 0.1, strength: 1 }}];
            item.protect = ["#e12885"];
            item.source = tex;
        }}
    }}
    Image {{ id: pic; anchors.fill: parent; source: "{GIF.as_uri()}"; smooth: false }}
    ShaderEffectSource {{ id: tex; sourceItem: pic; hideSource: true }}
}}"""
    tmp = Path(os.environ.get("TMPDIR", "/tmp")) / "scenematch_probe.qml"
    tmp.write_text(qml)
    view.setSource(QUrl.fromLocalFile(str(tmp)))
    view.resize(120, 160)
    view.show()
    out = {}

    def grab():
        img = view.grabWindow()
        # the GIF is 30 × 40 stretched to 120 × 160: its head at (15, 12), its body at (15, 30)
        for name, (x, y) in {"head": (60, 48), "body": (60, 120)}.items():
            c = img.pixelColor(x, y)
            out[name] = "#%02x%02x%02x" % (c.red(), c.green(), c.blue())
        print(json.dumps(out))
        app.quit()

    QTimer.singleShot(800, grab)
    app.exec()


if __name__ == "__main__":
    main(sys.argv[1])
