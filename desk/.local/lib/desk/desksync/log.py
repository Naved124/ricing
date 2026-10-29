"""One line per event to stderr, which journald keeps for the service.

Callers log counts, status codes and error kinds only, never page content or
headers. Anything shaped like a Notion secret is masked anyway.
"""

from __future__ import annotations

import re
import sys

MASK = re.compile(r"\b(ntn|secret)_[A-Za-z0-9]+")


def log(msg: str, stream=None) -> None:
    print(f"desk-sync: {MASK.sub('[masked]', msg)}", file=stream or sys.stderr, flush=True)
