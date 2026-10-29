"""The write allowlist. Enforced here, in desk-sync, whatever the shell asks.

Allowed, and nothing else:
  - set Done on a page of the Today data source that was in the last sync
  - a new page in Today: its title, and Priority at the default
  - a new page in the Idea inbox: its title
  - the full view's edits, on the databases in config.toml's [sources] only:
    set one editable property of a row that was in the last sync, a new row,
    or a row moved to Notion's trash (where it can be restored from)
Every value is checked against the schema from the last sync (schema.py):
an option Notion doesn't have yet is refused, as it would change the schema.
Before a row is changed, Notion is asked which data source it is in. Never
the brief, the weekly reviews or the Desk page; no schema changes, no
permanent deletes. Request bodies are built only from the templates below.
"""

from __future__ import annotations

import re
import unicodedata

from . import schema
from .config import Config
from .normalize import norm_id

UUID = re.compile(r"^(?:[0-9a-f]{32}|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$")
CREATE_TARGETS = ("today", "ideas")


class Refused(Exception):
    """A write the allowlist doesn't cover; the message is safe to show."""


def page_id(raw: str) -> str:
    if not isinstance(raw, str) or not UUID.match(raw.lower()):
        raise Refused("not a page ID")
    return norm_id(raw)


def read_only(cfg: Config) -> set:
    return {norm_id(cfg.brief), norm_id(cfg.weekly), norm_id(cfg.raw["desk"]["page"])}


def known_task(cfg: Config, cache: dict | None, raw: str) -> dict:
    """The Today task `raw` names, from the last sync; anything else is refused."""
    pid = page_id(raw)
    if pid in read_only(cfg):
        raise Refused("the brief and the Desk page are read-only")
    for t in (cache or {}).get("today", []):
        if t.get("id") == pid:
            return t
    raise Refused("not a task in the last synced Today list")


def clean_text(raw: str, limit: int) -> str:
    """Control and format characters out, whitespace collapsed, trimmed, capped."""
    s = "".join(" " if c in "\t\n\r" or unicodedata.category(c) in ("Zl", "Zp") else c
                for c in raw if unicodedata.category(c) not in ("Cc", "Cf") or c in "\t\n\r")
    s = " ".join(s.split())
    if not s:
        raise Refused("nothing to capture")
    return s[:limit].rstrip()


def capture(cfg: Config, raw: str) -> tuple[str, str]:
    """(target, title): `idea:` sends it to the Idea inbox, the rest to Today."""
    if not isinstance(raw, str):
        raise Refused("nothing to capture")
    s = clean_text(raw, 10_000)
    target = "today"
    if s[:5].lower() == "idea:":
        target, s = "ideas", s[5:]
    return target, clean_text(s, cfg.sync["capture_max"])


def done_body(cfg: Config, done: bool) -> dict:
    if not isinstance(done, bool):
        raise Refused("Done is a checkbox")
    return {"properties": {cfg.fields("today")["done"]: {"checkbox": done}}}


def create_body(cfg: Config, target: str, title: str) -> dict:
    if target not in CREATE_TARGETS:
        raise Refused("new pages go only to Today or the Idea inbox")
    title = clean_text(title, cfg.sync["capture_max"])
    f = cfg.fields(target)
    props = {f["title"]: {"title": [{"type": "text", "text": {"content": title}}]}}
    if target == "today":
        props[f["priority"]] = {"select": {"name": cfg.sync["priority_default"]}}
    return {"parent": {"type": "data_source_id", "data_source_id": cfg.source(target)}, "properties": props}


def known_source(cfg: Config, cache: dict | None, name) -> dict:
    """The synced copy of one of the Desk's databases: its schema and rows."""
    if not isinstance(name, str) or name not in cfg.sources:
        raise Refused("not one of the Desk's databases")
    src = ((cache or {}).get("sources") or {}).get(name)
    if not src or not src.get("schema"):
        raise Refused("that database hasn't been synced yet")
    return src


def known_row(cfg: Config, cache: dict | None, name, raw) -> tuple[dict, dict]:
    """(source, row): a row of `name` from the last sync; anything else is refused."""
    src = known_source(cfg, cache, name)
    pid = page_id(raw)
    if pid in read_only(cfg):
        raise Refused("the brief, the weekly reviews and the Desk page are read-only")
    for r in src.get("rows", []):
        if r.get("id") == pid:
            return src, r
    raise Refused("not a row of that database in the last sync")


def set_body(cfg: Config, src: dict, prop, value) -> dict:
    try:
        return {"properties": schema.properties(src["schema"], {prop: value}, cfg.sync["text_max"], False)}
    except schema.Invalid as e:
        raise Refused(str(e)) from None


def new_body(cfg: Config, name: str, src: dict, values) -> dict:
    try:
        props = schema.properties(src["schema"], values, cfg.sync["text_max"], True)
    except schema.Invalid as e:
        raise Refused(str(e)) from None
    return {"parent": {"type": "data_source_id", "data_source_id": cfg.source(name)}, "properties": props}


class Writer:
    """The only way desk-sync writes to Notion: these calls."""

    def __init__(self, cfg: Config, client):
        self.cfg, self.client = cfg, client

    def set_done(self, cache: dict | None, raw: str, done: bool) -> None:
        task = known_task(self.cfg, cache, raw)
        page = self.client.page(task["id"])
        parent = page.get("parent") or {}
        if norm_id(str(parent.get("data_source_id", ""))) != norm_id(self.cfg.source("today")):
            raise Refused("that page isn't in the Today data source")
        if page.get("in_trash") or page.get("archived"):
            raise Refused("that task is in the trash")
        self.client.request("PATCH", f"pages/{task['id']}", done_body(self.cfg, done))

    def create(self, target: str, title: str) -> None:
        self.client.request("POST", "pages", create_body(self.cfg, target, title))

    def _check_parent(self, name: str, pid: str) -> None:
        """Notion's own word on where the row is, whatever the cache says."""
        page = self.client.page(pid)
        parent = page.get("parent") or {}
        if norm_id(str(parent.get("data_source_id", ""))) != norm_id(self.cfg.source(name)):
            raise Refused("that row isn't in that database")
        if page.get("in_trash") or page.get("archived"):
            raise Refused("that row is in the trash")

    def set(self, cache: dict | None, name: str, raw: str, prop: str, value) -> None:
        src, row = known_row(self.cfg, cache, name, raw)
        body = set_body(self.cfg, src, prop, value)
        self._check_parent(name, row["id"])
        self.client.request("PATCH", f"pages/{row['id']}", body)

    def new(self, cache: dict | None, name: str, values) -> None:
        src = known_source(self.cfg, cache, name)
        self.client.request("POST", "pages", new_body(self.cfg, name, src, values))

    def trash(self, cache: dict | None, name: str, raw: str) -> None:
        _, row = known_row(self.cfg, cache, name, raw)
        self._check_parent(name, row["id"])
        self.client.request("PATCH", f"pages/{row['id']}", {"in_trash": True})
