"""The write queue, ~/.local/state/desk/queue.json, behind a lock.

The shells add to it (desk-sync toggle / capture / set / new / trash), each
checked against the allowlist as it is added; a run takes it whole,
applies it through allow.Writer, puts back what failed for a reason worth
retrying, and records the rest as errors in the cache for the shell to roll
back.
"""

from __future__ import annotations

import fcntl
import uuid
from contextlib import contextmanager
from datetime import datetime

from . import allow, store
from .config import Config
from .notion import NetworkError, NotionError, RETRY_STATUS

MAX_TRIES = 3
KEEP_ERRORS = 20


@contextmanager
def locked(cfg: Config, name: str = "queue.lock", block: bool = True):
    store.private_dir(cfg.state_dir)
    with open(cfg.state_dir / name, "a") as f:
        try:
            fcntl.flock(f, fcntl.LOCK_EX | (0 if block else fcntl.LOCK_NB))
        except BlockingIOError:
            yield False
            return
        try:
            yield True
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)


def _read(cfg: Config) -> list:
    items = store.read(cfg.queue_file, [])
    return items if isinstance(items, list) else []


def toggle(cfg: Config, cache: dict | None, raw: str, now: datetime) -> str:
    """Queue the opposite of the task's synced Done; a second toggle before the run cancels the first."""
    task = allow.known_task(cfg, cache, raw)
    with locked(cfg):
        items = _read(cfg)
        same = [i for i in items if i.get("op") == "toggle" and i.get("page") == task["id"]]
        if same:
            store.write(cfg.queue_file, [i for i in items if i not in same])
            return "cancelled"
        items.append({"qid": uuid.uuid4().hex, "op": "toggle", "page": task["id"], "done": not task["done"],
                      "at": now.isoformat(timespec="seconds"), "tries": 0})
        store.write(cfg.queue_file, items)
    return f"queued done={'true' if not task['done'] else 'false'}"


def capture(cfg: Config, raw: str, now: datetime) -> str:
    target, title = allow.capture(cfg, raw)
    with locked(cfg):
        items = _read(cfg)
        items.append({"qid": uuid.uuid4().hex, "op": "capture", "target": target, "title": title,
                      "at": now.isoformat(timespec="seconds"), "tries": 0})
        store.write(cfg.queue_file, items)
    return f"queued to {target}"


def _add(cfg: Config, item: dict, now: datetime, replaces=None) -> None:
    with locked(cfg):
        items = [i for i in _read(cfg) if not (replaces and replaces(i))]
        items.append({"qid": uuid.uuid4().hex, **item, "at": now.isoformat(timespec="seconds"), "tries": 0})
        store.write(cfg.queue_file, items)


def set_(cfg: Config, cache: dict | None, name: str, raw: str, prop: str, value, now: datetime) -> str:
    """One property of a row; a later edit of the same property before the run replaces it."""
    src, row = allow.known_row(cfg, cache, name, raw)
    allow.set_body(cfg, src, prop, value)
    _add(cfg, {"op": "set", "source": name, "page": row["id"], "prop": prop, "value": value}, now,
         lambda i: i.get("op") == "set" and i.get("page") == row["id"] and i.get("prop") == prop)
    return "queued"


def new(cfg: Config, cache: dict | None, name: str, values, now: datetime) -> str:
    src = allow.known_source(cfg, cache, name)
    allow.new_body(cfg, name, src, values)
    _add(cfg, {"op": "new", "source": name, "values": values}, now)
    return f"queued a new row in {name}"


def trash(cfg: Config, cache: dict | None, name: str, raw: str, now: datetime) -> str:
    _, row = allow.known_row(cfg, cache, name, raw)
    _add(cfg, {"op": "trash", "source": name, "page": row["id"]}, now,
         lambda i: i.get("page") == row["id"])
    return "queued for the trash"


def take(cfg: Config) -> list:
    with locked(cfg):
        items = _read(cfg)
        if items:
            store.write(cfg.queue_file, [])
    return items


def put_back(cfg: Config, items: list) -> None:
    if not items:
        return
    with locked(cfg):
        store.write(cfg.queue_file, items + _read(cfg))


def apply(cfg: Config, writer: allow.Writer, cache: dict | None, items: list, now: datetime, log) -> tuple[list, list]:
    """Apply each item; returns (retry, errors)."""
    retry, errors = [], []
    for item in items:
        op = item.get("op")
        try:
            if op == "toggle":
                writer.set_done(cache, item.get("page", ""), item.get("done"))
            elif op == "capture":
                writer.create(item.get("target", ""), item.get("title", ""))
            elif op == "set":
                writer.set(cache, item.get("source"), item.get("page", ""), item.get("prop"), item.get("value"))
            elif op == "new":
                writer.new(cache, item.get("source"), item.get("values"))
            elif op == "trash":
                writer.trash(cache, item.get("source"), item.get("page", ""))
            else:
                raise allow.Refused("not an allowed write")
            log(f"{op}: ok")
            continue
        except allow.Refused as e:
            message = f"refused: {e}"
        except (NetworkError, NotionError) as e:
            transient = isinstance(e, NetworkError) or e.status in RETRY_STATUS
            if transient and item.get("tries", 0) + 1 < MAX_TRIES:
                retry.append({**item, "tries": item.get("tries", 0) + 1})
                log(f"{op}: {e}, will retry")
                continue
            message = f"Notion said no ({e})" if isinstance(e, NotionError) else "couldn't reach Notion"
        log(f"{op}: {message}")
        errors.append({"qid": item.get("qid"), "op": op, "page": item.get("page"), "source": item.get("source"),
                       "prop": item.get("prop"), "message": message, "at": now.isoformat(timespec="seconds")})
    return retry, errors


def keep(old: list, new: list) -> list:
    return (old + new)[-KEEP_ERRORS:]
