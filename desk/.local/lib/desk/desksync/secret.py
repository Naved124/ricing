"""The Notion credential, from the keyring (libsecret's secret-tool) and nowhere else.

Stored once by hand:  secret-tool store --label="Desk Notion" service desk-notion
It is read per run, kept in memory, and goes only into the Authorization
header: never into argv, the environment, the cache, the queue or a log line.
A locked or missing keyring is an error; there is no file to fall back to.
"""

from __future__ import annotations

import re
import subprocess

LOOKUP = ["secret-tool", "lookup", "service", "desk-notion"]
STORE_HINT = 'secret-tool store --label="Desk Notion" service desk-notion'
SHAPE = re.compile(r"^(ntn|secret)_[A-Za-z0-9]{20,}$")


class SecretError(Exception):
    """Says what's wrong and what to do; never carries the credential."""


def read(run=subprocess.run, timeout: float = 20) -> str:
    try:
        r = run(LOOKUP, capture_output=True, text=True, timeout=timeout, stdin=subprocess.DEVNULL)
    except FileNotFoundError:
        raise SecretError("secret-tool isn't installed (pacman -S libsecret)") from None
    except subprocess.TimeoutExpired:
        raise SecretError("the keyring didn't answer: is it locked? Log in again or unlock it with seahorse") from None
    err = (r.stderr or "").lower()
    if r.returncode != 0 and err:
        if "locked" in err or "prompt" in err or "dismissed" in err:
            raise SecretError("the keyring is locked: unlock it (log in again, or seahorse) and retry")
        if "org.freedesktop.secrets" in err or "dbus" in err or "d-bus" in err or "not provided" in err:
            raise SecretError("no keyring service on the session bus: is gnome-keyring running?")
        raise SecretError(f"secret-tool failed (exit {r.returncode})")
    value = (r.stdout or "").strip()
    if not value:
        raise SecretError(f"no Desk credential in the keyring: store it with  {STORE_HINT}")
    if not SHAPE.match(value):
        raise SecretError("the keyring's Desk entry doesn't look like a Notion integration secret")
    return value
