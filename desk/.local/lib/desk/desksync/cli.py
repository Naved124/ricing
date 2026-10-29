"""desk-sync's subcommands."""

from __future__ import annotations

import argparse

from . import config, secret
from .log import log


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="desk-sync", description="Mirror the Notion Desk page for the shells.")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("check", help="read the config and the keyring, and say what's set")
    return p


def check(cfg: config.Config) -> int:
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


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        cfg = config.load()
    except config.ConfigError as e:
        log(str(e))
        return 2
    if args.cmd == "check":
        return check(cfg)
    return 0
