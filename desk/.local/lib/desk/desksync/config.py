"""config.toml (IDs, property names, limits) and where the cache and state live."""

from __future__ import annotations

import os
import tomllib
from dataclasses import dataclass
from pathlib import Path


class ConfigError(Exception):
    pass


def _xdg(var: str, fallback: str) -> Path:
    v = os.environ.get(var)
    return Path(v) if v else Path.home() / fallback


def config_path() -> Path:
    if os.environ.get("DESK_CONFIG"):
        return Path(os.environ["DESK_CONFIG"])
    return _xdg("XDG_CONFIG_HOME", ".config") / "desk" / "config.toml"


@dataclass(frozen=True)
class Config:
    raw: dict
    cache_dir: Path
    state_dir: Path

    @property
    def cache_file(self) -> Path:
        return self.cache_dir / "state.json"

    @property
    def queue_file(self) -> Path:
        return self.state_dir / "queue.json"

    @property
    def lock_file(self) -> Path:
        return self.state_dir / "queue.lock"

    def source(self, name: str) -> str:
        return self.raw["sources"][name]

    def fields(self, name: str) -> dict:
        return self.raw["fields"][name]

    @property
    def notion(self) -> dict:
        return self.raw["notion"]

    @property
    def sync(self) -> dict:
        return self.raw["sync"]

    @property
    def brief(self) -> str:
        return self.raw["desk"]["brief"]


REQUIRED = {
    "notion": ("api", "version", "requests_per_second", "timeout_seconds", "max_retries"),
    "desk": ("page", "brief"),
    "sources": ("today", "jobs", "countdowns", "ideas"),
    "sync": ("max_pages", "stale_minutes", "capture_max", "priority_default"),
}


def load(path: Path | None = None) -> Config:
    path = path or config_path()
    try:
        raw = tomllib.loads(path.read_text())
    except FileNotFoundError:
        raise ConfigError(f"no config at {path} (run tools/relink, or set DESK_CONFIG)") from None
    except tomllib.TOMLDecodeError as e:
        raise ConfigError(f"{path}: {e}") from None
    for table, keys in REQUIRED.items():
        for k in keys:
            if k not in raw.get(table, {}):
                raise ConfigError(f"{path}: [{table}] {k} is missing")
    for name in ("today", "jobs", "countdowns", "ideas"):
        if name not in raw.get("fields", {}):
            raise ConfigError(f"{path}: [fields.{name}] is missing")
    return Config(raw,
                  _xdg("XDG_CACHE_HOME", ".cache") / "desk",
                  _xdg("XDG_STATE_HOME", ".local/state") / "desk")
