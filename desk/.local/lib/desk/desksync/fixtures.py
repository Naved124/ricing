"""--dry-run: Notion's answers from tests/fixtures/desk/, no network.

today.json, countdowns.json, jobs.json      data source queries (a list = pages by cursor)
brief-page.json, brief-blocks.json          the brief page and its blocks
"""

from __future__ import annotations

import json
from pathlib import Path

from .config import Config
from .notion import Response, Transport


def transport(cfg: Config, root: Path, writes: list | None = None) -> Transport:
    by_source = {cfg.source(n).replace("-", ""): n for n in ("today", "countdowns", "jobs", "ideas")}
    brief = cfg.brief.replace("-", "")

    def load(name: str, cursor: str | None):
        data = json.loads((root / f"{name}.json").read_text())
        if isinstance(data, list):
            data = data[int(cursor[1:]) if cursor else 0]
        return data

    def send(method, path, body, params):
        parts = path.split("/")
        key = parts[1].replace("-", "") if len(parts) > 1 else ""
        if method == "POST" and parts[0] == "data_sources" and parts[-1] == "query":
            name = by_source.get(key)
            if name is None or not (root / f"{name}.json").exists():
                return Response(404, {"code": "object_not_found"})
            return Response(200, load(name, (body or {}).get("start_cursor")))
        if method == "GET" and parts[0] == "blocks" and key == brief:
            return Response(200, load("brief-blocks", (params or {}).get("start_cursor")))
        if method == "GET" and parts[0] == "pages":
            if key == brief:
                return Response(200, load("brief-page", None))
            for row in _rows(root, "today"):
                if row["id"].replace("-", "") == key:
                    return Response(200, row)
            return Response(404, {"code": "object_not_found"})
        if method in ("PATCH", "POST") and parts[0] == "pages" and writes is not None:
            writes.append((method, path, body))
            return Response(200, {"object": "page", "id": key or "00000000000040008000000000000000"})
        return Response(400, {"code": "validation_error"})

    return send


def _rows(root: Path, name: str) -> list[dict]:
    data = json.loads((root / f"{name}.json").read_text())
    pages = data if isinstance(data, list) else [data]
    return [r for p in pages for r in p.get("results", [])]
