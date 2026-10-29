"""One read sync: every source, normalized, into the cache in one write.

Either all five reads succeed and the cache is replaced, or nothing new is
written but `stale`, `error` and `attempted_at` on the last good cache.
"""

from __future__ import annotations

from datetime import datetime

from . import normalize, store
from .config import Config
from .notion import Client, NetworkError, NotionError

VERSION = 1


def stamp(now: datetime) -> str:
    return now.isoformat(timespec="seconds")


def explain(e: Exception) -> str:
    """A short reason for the footer: no content, no IDs."""
    if isinstance(e, NetworkError):
        return {"timeout": "Notion timed out", "offline": "offline"}.get(e.kind, e.kind)
    if isinstance(e, NotionError):
        if e.status == 401:
            return "Notion refused the credential (401)"
        if e.status in (403, 404):
            return f"Notion can't see a Desk source ({e.status}): share the Desk page with the integration"
        if e.status == 429:
            return "rate limited by Notion"
        return f"Notion error {e.status}"
    return str(e) or type(e).__name__


def fetch(cfg: Config, client: Client, now: datetime) -> dict:
    pages = cfg.sync["max_pages"]
    rows = {name: client.query(cfg.source(name), pages) for name in ("today", "countdowns", "jobs")}
    brief_page = client.page(cfg.brief)
    brief_blocks = client.blocks(cfg.brief, 3)
    today = normalize.today(rows["today"], cfg.fields("today"), now)
    countdowns = normalize.countdowns(rows["countdowns"], cfg.fields("countdowns"), now)
    open_ = [t for t in today if not t["done"]]
    return {
        "today": today,
        "countdowns": countdowns,
        "jobs": normalize.jobs(rows["jobs"], cfg.fields("jobs")),
        "brief": normalize.brief(brief_page, brief_blocks),
        "summary": {"open": len(open_), "overdue": sum(t["state"] == "overdue" for t in open_),
                    "next": ({"event": countdowns[0]["event"], "days": countdowns[0]["days"]}
                             if countdowns else None)},
    }


def empty() -> dict:
    return {"version": VERSION, "synced_at": None, "today": [], "countdowns": [], "jobs": [],
            "brief": {"title": "Daily brief", "edited": None, "blocks": []},
            "summary": {"open": 0, "overdue": 0, "next": None}, "errors": []}


def run(cfg: Config, client: Client | None, now: datetime, log, failure: Exception | None = None,
        errors: list | None = None) -> int:
    """Sync into the cache. `failure` (e.g. a locked keyring) marks it stale without trying."""
    old = store.read(cfg.cache_file) or empty()
    kept_errors = errors if errors is not None else old.get("errors", [])
    try:
        if failure:
            raise failure
        data = fetch(cfg, client, now)
    except Exception as e:  # whatever went wrong, the last good cache stays
        reason = explain(e) if isinstance(e, (NetworkError, NotionError)) or e is failure else type(e).__name__
        old.update(stale=True, error=reason, attempted_at=stamp(now), errors=kept_errors)
        store.write(cfg.cache_file, old)
        log(f"sync failed, kept the last good cache: {reason}")
        return 1
    doc = {"version": VERSION, "synced_at": stamp(now), "attempted_at": stamp(now), "stale": False,
           "error": None, **data, "errors": kept_errors}
    store.write(cfg.cache_file, doc)
    log(f"synced: {len(data['today'])} tasks, {len(data['countdowns'])} countdowns, "
        f"{sum(len(g['items']) for g in data['jobs'])} jobs, {len(data['brief']['blocks'])} brief blocks, "
        f"{client.count} requests")
    return 0
