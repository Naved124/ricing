"""desk-sync's subcommands.

    desk-sync check                         the config and the keyring
    desk-sync sync                          read every source into the cache
    desk-sync sync --dry-run [--out FILE]   the same from tests/fixtures/desk, no network;
                                            prints the cache unless --out
    desk-sync toggle PAGE_ID                queue Done flipped on a task from the last sync
    desk-sync capture -- TEXT               queue a new task (or `idea: …` for the Idea inbox)
    desk-sync set SOURCE PAGE_ID PROP JSON  queue one property of a row (the full view's edits)
    desk-sync new SOURCE JSON               queue a new row: {"Property": value, ...}
    desk-sync trash SOURCE PAGE_ID          queue a row to Notion's trash
    desk-sync run                           apply the queue, then sync (what the timer runs)
    desk-sync now                           start a run in the background

toggle, capture, set, new and trash refuse anything the allowlist (allow.py) doesn't cover, with
exit status 3 and the reason on stderr. DESK_DRY_RUN=<fixture folder> makes
run answer from fixtures and record writes instead of sending them.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from . import allow, config, fixtures, queue, secret, store, sync
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
    t = sub.add_parser("toggle", help="queue Done flipped on a Today task")
    t.add_argument("page")
    c = sub.add_parser("capture", help="queue a new Today task, or an idea with `idea:`")
    c.add_argument("text", nargs="+")
    e = sub.add_parser("set", help="queue one property of a row in a Desk database")
    e.add_argument("source")
    e.add_argument("page")
    e.add_argument("prop")
    e.add_argument("value", help="JSON: a string, number, true/false, null, a list of options or a date")
    n = sub.add_parser("new", help="queue a new row in a Desk database")
    n.add_argument("source")
    n.add_argument("values", help='JSON: {"Property": value, ...}, the title among them')
    d = sub.add_parser("trash", help="queue a row to Notion's trash")
    d.add_argument("source")
    d.add_argument("page")
    sub.add_parser("run", help="apply the queue, then sync")
    sub.add_parser("now", help="start a run in the background")
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


def kick() -> None:
    """Start a run without waiting: the hardened service if there is one, else ourselves."""
    if os.environ.get("DESK_NO_KICK"):
        return
    try:
        r = subprocess.run(["systemctl", "--user", "start", "--no-block", "desk-sync.service"],
                           capture_output=True, timeout=10)
        if r.returncode == 0:
            return
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    subprocess.Popen([sys.executable, os.path.realpath(sys.argv[0]), "run"], start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def run_client(cfg: Config) -> Client:
    """The live client, or with DESK_DRY_RUN a fixture one whose writes go to writes.json."""
    if os.environ.get("DESK_DRY_RUN"):
        writes: list = []
        client = Client(fixtures.transport(cfg, Path(os.environ["DESK_DRY_RUN"]), writes), rate=1000,
                        retries=0, log=log)
        client.writes = writes
        return client
    return client_for(cfg, secret.read())


def do_run(cfg: Config) -> int:
    with queue.locked(cfg, "run.lock", block=False) as got:
        if not got:
            log("a run is already going")
            return 0
        try:
            client = run_client(cfg)
        except secret.SecretError as e:
            return sync.run(cfg, None, now(), log, failure=e)
        code = 0
        for _ in range(3):
            items = queue.take(cfg)
            old = store.read(cfg.cache_file) or sync.empty()
            retry, errors = queue.apply(cfg, allow.Writer(cfg, client), old, items, now(), log)
            queue.put_back(cfg, retry)
            code = sync.run(cfg, client, now(), log, errors=queue.keep(old.get("errors", []), errors))
            if retry or not store.read(cfg.queue_file, []):
                break
        if getattr(client, "writes", None):
            store.write(cfg.state_dir / "writes.json", [{"method": m, "path": p, "body": b}
                                                        for m, p, b in client.writes])
        return code


def json_arg(raw: str):
    try:
        return json.loads(raw)
    except ValueError:
        raise allow.Refused("that value isn't JSON") from None


def enqueue(cfg: Config, args) -> int:
    cache = store.read(cfg.cache_file)
    try:
        if args.cmd == "toggle":
            print(queue.toggle(cfg, cache, args.page, now()))
        elif args.cmd == "set":
            print(queue.set_(cfg, cache, args.source, args.page, args.prop, json_arg(args.value), now()))
        elif args.cmd == "new":
            print(queue.new(cfg, cache, args.source, json_arg(args.values), now()))
        elif args.cmd == "trash":
            print(queue.trash(cfg, cache, args.source, args.page, now()))
        else:
            print(queue.capture(cfg, " ".join(args.text), now()))
    except allow.Refused as e:
        log(f"refused: {e}")
        return 3
    kick()
    return 0


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
    if args.cmd in ("toggle", "capture", "set", "new", "trash"):
        return enqueue(cfg, args)
    if args.cmd == "run":
        return do_run(cfg)
    if args.cmd == "now":
        kick()
    return 0
