"""Notion rows -> only the fields the widget renders, as plain text.

Everything from Notion is untrusted: titles stay text (the shells draw them
as plain text), lengths are capped, and links survive only as https URLs.
"""

from __future__ import annotations

import re
from datetime import date, datetime

TEXT_MAX = 300
URL = re.compile(r"https://[^\s<>\"')\]]+")
CLOSED = re.compile(r"reject|declin|closed|withdraw|archiv|ghost|no response", re.I)


def norm_id(i: str) -> str:
    h = i.replace("-", "").lower()
    return f"{h[:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:]}" if len(h) == 32 else i.lower()


def clip(s: str, n: int = TEXT_MAX) -> str:
    s = " ".join(s.split()) if "\n" not in s else s.strip()
    return s if len(s) <= n else s[: n - 1] + "…"


def rich(parts) -> str:
    return "".join(p.get("plain_text", "") for p in parts or [])


def https(url) -> str | None:
    return url if isinstance(url, str) and url.startswith("https://") and URL.fullmatch(url) else None


def first_link(parts) -> str | None:
    for p in parts or []:
        if https(p.get("href")):
            return p["href"]
    m = URL.search(rich(parts))
    return m.group(0) if m else None


def value(prop: dict | None):
    """A property as a plain Python value: str, bool, number, date string or None."""
    if not prop:
        return None
    t = prop.get("type")
    v = prop.get(t)
    if t in ("title", "rich_text"):
        return rich(v)
    if t in ("select", "status"):
        return (v or {}).get("name")
    if t == "multi_select":
        return ", ".join(o.get("name", "") for o in v or [])
    if t == "date":
        return (v or {}).get("start")
    if t in ("checkbox", "number", "url", "email", "phone_number", "created_time", "last_edited_time"):
        return v
    if t == "formula":
        v = v or {}
        inner = v.get(v.get("type"))
        return inner.get("start") if isinstance(inner, dict) else inner
    if t == "rollup":
        v = v or {}
        return v.get(v.get("type")) if v.get("type") in ("number", "date") else None
    return None


def text(props: dict, name: str) -> str:
    v = value(props.get(name))
    if isinstance(v, bool):
        return "yes" if v else ""
    return clip(str(v)) if v not in (None, "") else ""


def day(s) -> date | None:
    if not isinstance(s, str) or not s:
        return None
    try:
        return date.fromisoformat(s[:10])
    except ValueError:
        return None


def live(rows: list[dict]) -> list[dict]:
    return [r for r in rows if not r.get("in_trash") and not r.get("archived") and not r.get("is_archived")]


def local_day(stamp: str | None, tz) -> date | None:
    if not stamp:
        return None
    try:
        return datetime.fromisoformat(stamp.replace("Z", "+00:00")).astimezone(tz).date()
    except ValueError:
        return None


def today(rows: list[dict], f: dict, now: datetime) -> list[dict]:
    """Open tasks (overdue, due today, high priority, the rest), then today's done ones."""
    d0 = now.date()
    out = []
    for r in live(rows):
        p = r.get("properties", {})
        done = value(p.get(f["done"])) is True
        if done and local_day(r.get("last_edited_time"), now.tzinfo) != d0:
            continue
        due = day(value(p.get(f["due"])))
        prio = text(p, f["priority"])
        if done:
            state = "done"
        elif due and due < d0:
            state = "overdue"
        elif due == d0:
            state = "today"
        elif prio.lower() in ("high", "urgent", "p1"):
            state = "high"
        else:
            state = "open"
        out.append({"id": norm_id(r["id"]), "title": text(p, f["title"]) or "Untitled", "done": done,
                    "due": due.isoformat() if due else None, "area": text(p, f["area"]),
                    "priority": prio, "notes": clip(text(p, f["notes"]), 160), "state": state})
    rank = {"overdue": 0, "today": 1, "high": 2, "open": 3, "done": 4}
    out.sort(key=lambda t: (rank[t["state"]], t["due"] or "9999", t["title"].lower()))
    return out


def countdowns(rows: list[dict], f: dict, now: datetime) -> list[dict]:
    d0 = now.date()
    out = []
    for r in live(rows):
        p = r.get("properties", {})
        if value(p.get(f["done"])) is True:
            continue
        when = day(value(p.get(f["date"])))
        left = value(p.get(f["days_left"]))
        if not isinstance(left, (int, float)) or isinstance(left, bool):
            left = (when - d0).days if when else None
        if left is None or left < 0:
            continue
        prep = p.get(f["prep"]) or {}
        out.append({"id": norm_id(r["id"]), "event": text(p, f["title"]) or "Untitled",
                    "date": when.isoformat() if when else None, "days": int(left),
                    "type": text(p, f["type"]), "prep": clip(text(p, f["prep"]), 200),
                    "link": first_link(prep.get(prep.get("type"), []) if isinstance(prep, dict) else None),
                    "soon": left <= 7})
    out.sort(key=lambda c: (c["days"], c["event"].lower()))
    return out


def jobs(rows: list[dict], f: dict) -> list[dict]:
    groups: dict[str, list] = {}
    for r in live(rows):
        p = r.get("properties", {})
        status = text(p, f["status"]) or "No status"
        applied = day(value(p.get(f["applied"])))
        groups.setdefault(status, []).append({
            "id": norm_id(r["id"]), "role": text(p, f["title"]) or "Untitled", "company": text(p, f["company"]),
            "track": text(p, f["track"]), "location": text(p, f["location"]), "referral": text(p, f["referral"]),
            "applied": applied.isoformat() if applied else "",
            "next": text(p, f["next"]), "link": https(value(p.get(f["link"])))})
    for items in groups.values():
        items.sort(key=lambda j: j["applied"] or "", reverse=True)
    order = sorted(groups, key=lambda s: (bool(CLOSED.search(s)), -len(groups[s]), s.lower()))
    return [{"status": s, "items": groups[s]} for s in order]


KINDS = {"heading_1": "h1", "heading_2": "h2", "heading_3": "h3", "paragraph": "p",
         "bulleted_list_item": "bullet", "numbered_list_item": "number", "to_do": "todo",
         "quote": "quote", "callout": "callout", "toggle": "p", "code": "code"}


def brief(page: dict, blocks: list[dict]) -> dict:
    title = ""
    for prop in (page.get("properties") or {}).values():
        if prop.get("type") == "title":
            title = rich(prop.get("title"))
    out = []
    for b in blocks:
        t = b.get("type")
        if t == "divider":
            out.append({"kind": "divider", "text": ""})
            continue
        if t not in KINDS:
            continue
        body = b.get(t) or {}
        item = {"kind": KINDS[t], "text": clip(rich(body.get("rich_text")), 1000)}
        if t == "to_do":
            item["checked"] = bool(body.get("checked"))
        if item["text"] or t == "paragraph":
            out.append(item)
    return {"title": clip(title, 120) or "Daily brief", "edited": page.get("last_edited_time"), "blocks": out[:200]}
