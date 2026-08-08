"""Committed policy config for the scheduled backlog burn.

``.github/backlog-burn.conf`` is the git-tracked source of truth for the
routine's policy — the same idea as ``.github/ci-gates/registry.conf``: a
clone carries it, every run reads it identically, and a change is a reviewed
one-line diff. GitHub supplies only the live arming (the
``BACKLOG_BURN_ENABLED`` repo variable) and the secret.

Parsing is strict on purpose (like the ci-gates registry): a typo'd key or a
malformed value fails loudly rather than being silently ignored and letting
the routine run on a policy nobody wrote.
"""

from __future__ import annotations

from dataclasses import dataclass

DEFAULT_PATH = ".github/backlog-burn.conf"

# The only keys the file may carry. Anything else is a typo and must fail.
_KNOWN_KEYS = ("enabled", "label")


@dataclass
class Config:
    """The routine's committed policy."""

    enabled: bool
    label: str


def _parse_bool(value: str, where: str) -> bool:
    low = value.strip().lower()
    if low in ("true", "false"):
        return low == "true"
    raise ValueError(f"{where}: 'enabled' must be 'true' or 'false', got {value!r}")


def load(path: str = DEFAULT_PATH) -> Config:
    """Parse the config file into a :class:`Config`, or raise on any problem.

    Defaults: ``enabled`` is False if the key is absent (fail safe — an
    incomplete file never reads as "on"); ``label`` defaults to
    ``autonomy-ok``.
    """
    enabled = False
    label = "autonomy-ok"
    seen: set[str] = set()
    with open(path, encoding="utf-8") as fh:
        for lineno, raw in enumerate(fh, 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if ":" not in line:
                raise ValueError(f"{path}:{lineno}: expected 'key: value', got {raw.rstrip()!r}")
            key, _, value = line.partition(":")
            key = key.strip()
            value = value.strip()
            where = f"{path}:{lineno}"
            if key not in _KNOWN_KEYS:
                raise ValueError(f"{where}: unknown key {key!r} (known: {list(_KNOWN_KEYS)})")
            if key in seen:
                raise ValueError(f"{where}: duplicate key {key!r}")
            seen.add(key)
            if key == "enabled":
                enabled = _parse_bool(value, where)
            elif key == "label":
                if not value:
                    raise ValueError(f"{where}: 'label' must not be empty")
                label = value
    return Config(enabled=enabled, label=label)


def get(key: str, path: str = DEFAULT_PATH) -> str:
    """Return one config value as a plain string, for the workflow to read.

    ``enabled`` renders as ``"true"``/``"false"`` so a workflow step can gate
    on it directly.
    """
    cfg = load(path)
    if key == "enabled":
        return "true" if cfg.enabled else "false"
    if key == "label":
        return cfg.label
    raise KeyError(f"unknown config key: {key!r} (known: {list(_KNOWN_KEYS)})")
