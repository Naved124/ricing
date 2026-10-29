"""--dry-run: Notion's answers from tests/fixtures/desk/, no network.

<source>.json                               a data source's query (a list = pages by cursor),
                                            for each name in config.toml's [sources]
<source>-schema.json                        GET data_sources/{id}
brief-page.json, brief-blocks.json          the brief page and its blocks
weekly-page.json, weekly-blocks.json        the weekly reviews page and its blocks
blocks-<id>.json                            any other block's children (a weekly recap)
"""

from __future__ import annotations

import json
from pathlib import Path

from .config import Config
from .notion import Response, Transport


def transport(cfg: Config, root: Path, writes: list | None = None) -> Transport:
    by_source = {sid.replace("-", ""): n for n, sid in cfg.sources.items()}
    named = {cfg.brief.replace("-", ""): "brief", cfg.weekly.replace("-", ""): "weekly"}

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
        if method == "GET" and parts[0] == "data_sources" and len(parts) == 2:
            name = by_source.get(key)
            if name is None or not (root / f"{name}-schema.json").exists():
                return Response(404, {"code": "object_not_found"})
            return Response(200, load(f"{name}-schema", None))
        if method == "GET" and parts[0] == "blocks":
            name = f"{named[key]}-blocks" if key in named else f"blocks-{key}"
            if not (root / f"{name}.json").exists():
                return Response(200, {"object": "list", "results": [], "has_more": False})
            return Response(200, load(name, (params or {}).get("start_cursor")))
        if method == "GET" and parts[0] == "pages":
            if key in named:
                return Response(200, load(f"{named[key]}-page", None))
            for name in by_source.values():
                if not (root / f"{name}.json").exists():
                    continue
                for row in _rows(root, name):
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
