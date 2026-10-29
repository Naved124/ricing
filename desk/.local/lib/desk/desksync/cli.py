"""desk-sync's subcommands.

    desk-sync check                         the config and the keyring
    desk-sync sync                          read every source into the cache
    desk-sync sync --dry-run [--out FILE]   the same from tests/fixtures/desk, no network;
                                            prints the cache unless --out
"""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime
from pathlib import Path

from . import config, fixtures, secret, sync
from .config import Config
from .log import log
from .notion import Client, http_transport

REPO = Path(__file__).resolve().parents[5]
FIXTURES = REPO / "tests/fixtures/desk"


def now() -> datetime:
    """DESK_NOW (ISO) stands in for the clock, as RICE_NOW does for rice-sun."""
    v = os.environ.get("DESK_NOW")
    t = datetime.fromisoformat(v) if v else datetime.now()
    return t.astimezone() if t.tzinfo is None else t


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="desk-sync", description="Mirror the Notion Desk page for the shells.")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("check", help="read the config and the keyring, and say what's set")
    s = sub.add_parser("sync", help="read every Desk source into the cache")
    s.add_argument("--dry-run", action="store_true", help="answer from fixture JSON, no network")
    s.add_argument("--fixtures", type=Path, default=FIXTURES, help="the fixture folder (--dry-run)")
    s.add_argument("--out", type=Path, help="write the cache here instead (--dry-run prints it otherwise)")
    return p


def client_for(cfg: Config, credential: str) -> Client:
    n = cfg.notion
    return Client(http_transport(n["api"], n["version"], credential, n["timeout_seconds"]),
                  rate=n["requests_per_second"], retries=n["max_retries"], log=log)


def check(cfg: Config) -> int:
    print(f"config:     ok ({config.config_path()})")
    print(f"cache:      {cfg.cache_file}")
    print(f"queue:      {cfg.queue_file}")
    try:
        secret.read()
    except secret.SecretError as e:
        print(f"credential: {e}")
        return 1
    print("credential: found in the keyring")
    return 0


def do_sync(cfg: Config, args) -> int:
    if args.dry_run:
        target = args.out
        if target is None:
            import tempfile
            tmp = tempfile.TemporaryDirectory()
            target = Path(tmp.name) / "state.json"
        cfg = Config(cfg.raw, target.parent, cfg.state_dir)
        if target.name != "state.json":
            raise SystemExit("desk-sync: --out must be a file named state.json")
        client = Client(fixtures.transport(cfg, args.fixtures), rate=1000, retries=0, log=log)
        code = sync.run(cfg, client, now(), log)
        if args.out is None:
            print(json.dumps(json.loads(target.read_text()), indent=1, ensure_ascii=False))
        return code
    try:
        client = client_for(cfg, secret.read())
    except secret.SecretError as e:
        return sync.run(cfg, None, now(), log, failure=e)
    return sync.run(cfg, client, now(), log)


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        cfg = config.load()
    except config.ConfigError as e:
        log(str(e))
        return 2
    if args.cmd == "check":
        return check(cfg)
    if args.cmd == "sync":
        return do_sync(cfg, args)
    return 0
