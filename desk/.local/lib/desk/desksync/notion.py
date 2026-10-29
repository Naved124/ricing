"""A small Notion client: spaced requests, timeouts, backoff on 429 and 5xx.

Endpoints (from makenotion/notion-sdk-js, API version in config.toml):
  POST  data_sources/{id}/query          rows of a data source
  GET   blocks/{id}/children             a page's blocks
  GET   pages/{id}                       a page (its parent says which data source)
  PATCH pages/{id}                       set properties
  POST  pages                            a new page, parent {"data_source_id": …}

The transport is a function (method, path, body, params) -> Response, so tests
and --dry-run swap in fixtures; `http_transport` is the real one (httpx).
Nothing here logs a header, a body or a URL with content in it.
"""

from __future__ import annotations

import random
import time
from dataclasses import dataclass, field
from typing import Callable

RETRY_STATUS = {429, 500, 502, 503, 504}


@dataclass
class Response:
    status: int
    data: dict
    headers: dict = field(default_factory=dict)


class NetworkError(Exception):
    """Couldn't reach Notion (offline, DNS, timeout); `kind` says which."""

    def __init__(self, kind: str):
        super().__init__(kind)
        self.kind = kind


class NotionError(Exception):
    """Notion answered with an error status; `code` is its error code, not content."""

    def __init__(self, status: int, code: str = ""):
        super().__init__(f"http {status} {code}".strip())
        self.status = status
        self.code = code


Transport = Callable[[str, str, "dict | None", "dict | None"], Response]


def http_transport(api: str, version: str, credential: str, timeout: float) -> Transport:
    import httpx  # only the live sync needs it

    client = httpx.Client(
        base_url=api.rstrip("/") + "/",
        headers={"Authorization": f"Bearer {credential}", "Notion-Version": version,
                 "Content-Type": "application/json"},
        timeout=httpx.Timeout(timeout, connect=min(timeout, 5.0)),
        follow_redirects=False,
    )

    def send(method, path, body, params):
        try:
            r = client.request(method, path, json=body, params=params)
        except httpx.TimeoutException:
            raise NetworkError("timeout") from None
        except httpx.TransportError:
            raise NetworkError("offline") from None
        try:
            data = r.json()
        except ValueError:
            data = {}
        return Response(r.status_code, data if isinstance(data, dict) else {},
                        {k.lower(): v for k, v in r.headers.items() if k.lower() == "retry-after"})

    return send


class Client:
    def __init__(self, transport: Transport, rate: float = 3, retries: int = 4,
                 sleep=time.sleep, clock=time.monotonic, rand=random.random, log=None):
        self.send = transport
        self.gap = 1.0 / rate
        self.retries = retries
        self.sleep, self.clock, self.rand = sleep, clock, rand
        self.log = log or (lambda msg: None)
        self.last = None
        self.count = 0

    def _space(self):
        if self.last is not None:
            wait = self.gap - (self.clock() - self.last)
            if wait > 0:
                self.sleep(wait)
        self.last = self.clock()

    def backoff(self, attempt: int, retry_after: str | None = None) -> float:
        """Exponential with jitter; never sooner than Retry-After."""
        delay = min(30.0, 2.0 ** attempt) * (0.5 + 0.5 * self.rand())
        try:
            if retry_after is not None:
                delay = max(delay, float(retry_after) + self.rand())
        except ValueError:
            pass
        return delay

    def request(self, method: str, path: str, body: dict | None = None, params: dict | None = None) -> dict:
        for attempt in range(self.retries + 1):
            self._space()
            self.count += 1
            last = attempt == self.retries
            try:
                r = self.send(method, path, body, params)
            except NetworkError as e:
                if last:
                    raise
                self.log(f"{method} {path.split('/')[0]}: {e.kind}, retrying")
                self.sleep(self.backoff(attempt))
                continue
            if r.status < 300:
                return r.data
            if r.status in RETRY_STATUS and not last:
                self.log(f"{method} {path.split('/')[0]}: http {r.status}, retrying")
                self.sleep(self.backoff(attempt, r.headers.get("retry-after")))
                continue
            raise NotionError(r.status, str(r.data.get("code", "")))
        raise AssertionError("unreachable")

    def query(self, source: str, max_pages: int) -> list[dict]:
        rows, cursor = [], None
        for _ in range(max_pages):
            body = {"page_size": 100}
            if cursor:
                body["start_cursor"] = cursor
            data = self.request("POST", f"data_sources/{source}/query", body)
            rows += [p for p in data.get("results", []) if p.get("object") == "page"]
            if not data.get("has_more") or not data.get("next_cursor"):
                break
            cursor = data["next_cursor"]
        return rows

    def blocks(self, block: str, max_pages: int) -> list[dict]:
        out, cursor = [], None
        for _ in range(max_pages):
            params = {"page_size": 100}
            if cursor:
                params["start_cursor"] = cursor
            data = self.request("GET", f"blocks/{block}/children", None, params)
            out += data.get("results", [])
            if not data.get("has_more") or not data.get("next_cursor"):
                break
            cursor = data["next_cursor"]
        return out

    def page(self, page: str) -> dict:
        return self.request("GET", f"pages/{page}")
