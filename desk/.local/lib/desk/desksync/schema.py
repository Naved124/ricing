"""Any Desk database, whole: its schema and rows as plain values, and the
other way, a value from the full view checked against that schema and made
into the property body Notion takes.

The full view is built from these, not from field names, so a property added
in Notion shows up (and can be edited) after the next sync. Values the view
sees, by type:

    title, rich_text, url, email, phone_number    str ("" when empty)
    number                                        int | float | None
    select, status                                str ("" when empty)
    multi_select                                  [str]
    date                                          {"start": str, "end": str | None} | None
    checkbox                                      bool
    anything else (formula, rollup, created_time, people, relation, files, ...)
                                                  str, read-only

A write is refused unless the value fits the type, an option is one the
schema already has (Notion would otherwise add it: a schema change), and the
property is one of the editable types.
"""

from __future__ import annotations

import math
import re
import unicodedata
from datetime import date, datetime

from .normalize import URL, clip, https, norm_id, rich, value

EDITABLE = ("title", "rich_text", "number", "select", "multi_select", "status", "date", "checkbox",
            "url", "email", "phone_number")
CHUNK = 2000            # Notion's limit on one rich text object
EMAIL = re.compile(r"^[^\s@<>\"]+@[^\s@<>\"]+\.[^\s@<>\"]+$")
PHONE = re.compile(r"^[0-9+()\-. ]{3,40}$")


class Invalid(Exception):
    """A value that doesn't fit its property; the message is safe to show."""


# ── reading ─────────────────────────────────────────────────────────────


def schema(source: dict) -> list[dict]:
    """The data source's properties: the title first, then as Notion lists them."""
    out = []
    for name, p in (source.get("properties") or {}).items():
        t = p.get("type", "")
        item = {"name": name, "type": t, "edit": t in EDITABLE}
        if t in ("select", "multi_select", "status"):
            body = p.get(t) or {}
            groups = {}
            for g in body.get("groups") or []:
                for oid in g.get("option_ids") or []:
                    groups[oid] = g.get("name", "")
            item["options"] = [{"name": o.get("name", ""), "color": o.get("color", "default"),
                                "group": groups.get(o.get("id"), "")}
                               for o in body.get("options") or [] if o.get("name")]
        out.append(item)
    out.sort(key=lambda i: i["type"] != "title")
    return out


def title_of(source: dict) -> str:
    return clip(rich(source.get("title")), 80)


def cell(prop: dict | None, text_max: int):
    """One property of a row, as the view sees it."""
    if not prop:
        return None
    t = prop.get("type")
    v = prop.get(t)
    if t in ("title", "rich_text"):
        return clip(rich(v), text_max)
    if t in ("url", "email", "phone_number"):
        return clip(v or "", 2000)
    if t == "number":
        return v if isinstance(v, (int, float)) and not isinstance(v, bool) else None
    if t in ("select", "status"):
        return (v or {}).get("name") or ""
    if t == "multi_select":
        return [o.get("name", "") for o in v or [] if o.get("name")]
    if t == "date":
        return {"start": v.get("start"), "end": v.get("end")} if v and v.get("start") else None
    if t == "checkbox":
        return bool(v)
    shown = value(prop)
    if t in ("people", "created_by", "last_edited_by"):
        people = v if isinstance(v, list) else [v] if isinstance(v, dict) else []
        shown = ", ".join(p.get("name", "") for p in people if p.get("name"))
    elif t == "relation":
        shown = f"{len(v or [])} linked"
    elif t == "files":
        shown = ", ".join(f.get("name", "") for f in v or [])
    elif t == "unique_id":
        v = v or {}
        shown = f"{v.get('prefix') + '-' if v.get('prefix') else ''}{v.get('number', '')}"
    if isinstance(shown, bool):
        return "yes" if shown else "no"
    if isinstance(shown, float) and shown.is_integer():
        shown = int(shown)
    return clip(str(shown), 300) if shown not in (None, "") else ""


def rows(pages: list[dict], fields: list[dict], text_max: int) -> list[dict]:
    names = [f["name"] for f in fields]
    out = []
    for r in pages:
        if r.get("in_trash") or r.get("archived") or r.get("is_archived"):
            continue
        p = r.get("properties") or {}
        out.append({"id": norm_id(r["id"]), "url": https(r.get("url")),
                    "created": r.get("created_time"), "edited": r.get("last_edited_time"),
                    "v": {n: cell(p.get(n), text_max) for n in names}})
    return out


def closed(row: dict, fields: list[dict], done_field: str | None) -> bool:
    """Finished: its done checkbox is ticked, or its status is in the "complete" group."""
    if done_field and row["v"].get(done_field) is True:
        return True
    for f in fields:
        if f["type"] == "status":
            group = next((o["group"] for o in f.get("options", []) if o["name"] == row["v"].get(f["name"])), "")
            if group.lower() == "complete":
                return True
    return False


def sort_key(row: dict, spec: str | None):
    """`Due` oldest first with empty dates last, `-Date` newest first; else newest created first."""
    if not spec:
        return (0, _neg(row.get("created") or ""))
    desc = spec.startswith("-")
    v = row["v"].get(spec.lstrip("-"))
    if isinstance(v, dict):
        v = v.get("start")
    if v in (None, "", []):
        return (1, "")
    v = str(v) if not isinstance(v, (int, float)) else f"{v:020.6f}"
    return (0, _neg(v) if desc else v)


def _neg(s: str) -> str:
    """A string that sorts in reverse."""
    return "".join(chr(0x10FFFF - ord(c)) for c in s)


def source(name: str, src: dict, pages: list[dict], view: dict, text_max: int) -> dict:
    fields = schema(src)
    done = (view.get("done") or {}).get(name)
    rs = rows(pages, fields, text_max)
    for r in rs:
        r["closed"] = closed(r, fields, done)
    spec = (view.get("sort") or {}).get(name)
    rs.sort(key=lambda r: (r["closed"], sort_key(r, spec)))
    return {"title": title_of(src) or name, "description": clip(rich(src.get("description")), 300),
            "schema": fields, "done": done, "rows": rs}


# ── writing ─────────────────────────────────────────────────────────────


def field(fields: list[dict], name) -> dict:
    for f in fields:
        if f["name"] == name:
            if not f["edit"]:
                raise Invalid(f"{name} is worked out by Notion and can't be edited")
            return f
    raise Invalid("no such property in this database")


def plain(raw, limit: int, lines: bool) -> str:
    """Control and format characters out (newlines kept in a text field), trimmed, capped."""
    if not isinstance(raw, str):
        raise Invalid("that should be text")
    keep = "\n" if lines else ""
    s = "".join(c if c in keep else " " if c in "\t\r\n" else c for c in raw
                if unicodedata.category(c) not in ("Cc", "Cf") or c in "\t\r\n")
    s = "\n".join(" ".join(l.split()) for l in s.split("\n")) if lines else " ".join(s.split())
    s = s.strip()
    if len(s) > limit:
        raise Invalid(f"that's longer than {limit} characters")
    return s


def rich_text(s: str) -> list[dict]:
    """Plain text as rich text: https links stay links, in pieces Notion accepts."""
    out = []
    at = 0
    for m in list(URL.finditer(s)) + [None]:
        end = m.start() if m else len(s)
        if end > at:
            text = s[at:end]
            out += [{"type": "text", "text": {"content": text[i:i + CHUNK]}} for i in range(0, len(text), CHUNK)]
        if m:
            url = m.group(0)[:CHUNK]
            out.append({"type": "text", "text": {"content": url, "link": {"url": url}}})
            at = m.start() + len(url)
    return out[:100]


def day(raw, what: str) -> str:
    if not isinstance(raw, str):
        raise Invalid(f"the {what} should be a date")
    try:
        if len(raw) == 10:
            date.fromisoformat(raw)
        else:
            datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        raise Invalid(f"the {what} isn't a date") from None
    return raw


def body(f: dict, raw, text_max: int) -> dict:
    """The property body Notion takes for `raw`, or Invalid."""
    t = f["type"]
    if t == "title":
        s = plain(raw, CHUNK, False)
        if not s:
            raise Invalid("the title can't be empty")
        return {"title": [{"type": "text", "text": {"content": s}}]}
    if t == "rich_text":
        return {"rich_text": rich_text(plain(raw, text_max, True))}
    if t == "number":
        if raw is None or raw == "":
            return {"number": None}
        if isinstance(raw, bool) or not isinstance(raw, (int, float)) or not math.isfinite(raw):
            raise Invalid("that should be a number")
        return {"number": raw}
    if t == "checkbox":
        if not isinstance(raw, bool):
            raise Invalid("that should be ticked or not")
        return {"checkbox": raw}
    names = [o["name"] for o in f.get("options", [])]
    if t in ("select", "status"):
        if raw in (None, "") and t == "select":
            return {"select": None}
        if raw not in names:
            raise Invalid(f"{raw!s:.40} isn't one of {f['name']}'s options")
        return {t: {"name": raw}}
    if t == "multi_select":
        if not isinstance(raw, list) or any(v not in names for v in raw):
            raise Invalid(f"only {f['name']}'s own options can be picked")
        return {"multi_select": [{"name": v} for v in dict.fromkeys(raw)]}
    if t == "date":
        if raw in (None, ""):
            return {"date": None}
        if not isinstance(raw, dict):
            raise Invalid("that should be a date")
        start = day(raw.get("start"), "date")
        end = raw.get("end") or None
        if end is not None:
            end = day(end, "end date")
            if end[:10] < start[:10]:
                raise Invalid("the end is before the start")
        return {"date": {"start": start, "end": end}}
    if t == "url":
        s = plain(raw, CHUNK, False)
        if s and not re.match(r"^https?://\S+$", s):
            raise Invalid("a link starts with https://")
        return {"url": s or None}
    if t == "email":
        s = plain(raw, 320, False)
        if s and not EMAIL.match(s):
            raise Invalid("that isn't an email address")
        return {"email": s or None}
    if t == "phone_number":
        s = plain(raw, 40, False)
        if s and not PHONE.match(s):
            raise Invalid("that isn't a phone number")
        return {"phone_number": s or None}
    raise Invalid(f"{f['name']} can't be edited")


def properties(fields: list[dict], values, text_max: int, need_title: bool) -> dict:
    if not isinstance(values, dict) or not values:
        raise Invalid("nothing to write")
    out = {}
    for name, raw in values.items():
        f = field(fields, name)
        out[name] = body(f, raw, text_max)
    if need_title and not any(f["type"] == "title" and f["name"] in out for f in fields):
        raise Invalid("a new row needs a title")
    return out
