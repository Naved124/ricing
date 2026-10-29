"""The write allowlist. Enforced here, in desk-sync, whatever the shell asks.

Allowed, and nothing else:
  - set Done on a page of the Today data source that was in the last sync
  - a new page in Today: its title, and Priority at the default
  - a new page in the Idea inbox: its title
No deletes, no other property, no other data source, never the brief page.
Request bodies are built only from the templates below.
"""

from __future__ import annotations

import re
import unicodedata

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


def known_task(cfg: Config, cache: dict | None, raw: str) -> dict:
    """The Today task `raw` names, from the last sync; anything else is refused."""
    pid = page_id(raw)
    if pid in {norm_id(cfg.brief), norm_id(cfg.raw["desk"]["page"])}:
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


class Writer:
    """The only way desk-sync writes to Notion: these two calls."""

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
