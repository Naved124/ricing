"""desk-sync's subcommands."""

from __future__ import annotations

import argparse
import sys

from . import config


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="desk-sync", description="Mirror the Notion Desk page for the shells.")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("check", help="read the config and say what's set")
    return p


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        cfg = config.load()
    except config.ConfigError as e:
        print(f"desk-sync: {e}", file=sys.stderr)
        return 2
    if args.cmd == "check":
        print(f"config: ok ({config.config_path()})")
        print(f"cache:  {cfg.cache_file}")
        print(f"queue:  {cfg.queue_file}")
    return 0
