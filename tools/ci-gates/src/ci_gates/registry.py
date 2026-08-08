"""Parse and mutate the committed gate registry (.github/ci-gates/registry.conf).

The registry is INI (configparser): one section per candidate gate. It is the
reproducible source of truth for what Smart CI does, so two properties matter
and are tested:

  * reading is total — a gate with no stanza still resolves, via the tier
    default, so adding an advisory detector needs no registry edit; and
  * writing is minimal and idempotent — approving a gate rewrites exactly that
    gate's `state` and preserves comments/order elsewhere as far as configparser
    allows, so the diff a maintainer's /ci-gate command produces is legible.
"""

from __future__ import annotations

import configparser
from dataclasses import dataclass
from pathlib import Path

TIERS = ("advisory", "gating")
STATES = ("on", "proposed", "off")


def default_state(tier: str) -> str:
    """The state a gate has when the registry says nothing about it.

    This is where the auto-approve policy lives: an advisory gate is *on* by
    default (cheap, non-blocking, so it may run itself the first time it
    applies), while a gating gate — one that can fail a PR — defaults to
    *proposed* and waits for a human to cross it.
    """
    if tier not in TIERS:
        raise ValueError(f"unknown tier {tier!r}, expected one of {TIERS}")
    return "on" if tier == "advisory" else "proposed"


@dataclass(frozen=True)
class Gate:
    """One candidate gate as declared in the registry."""

    id: str
    tier: str
    state: str
    title: str
    run: str
    cross: str
    setup: str = ""

    @property
    def advisory(self) -> bool:
        return self.tier == "advisory"

    @property
    def gating(self) -> bool:
        return self.tier == "gating"


DEFAULT_REGISTRY_PATH = Path(".github/ci-gates/registry.conf")


class Registry:
    """The parsed registry, plus the on-disk file it came from."""

    def __init__(self, gates: dict[str, Gate], path: Path | None = None):
        self._gates = gates
        self.path = path

    # -- construction ------------------------------------------------------

    @classmethod
    def load(cls, path: Path) -> "Registry":
        path = Path(path)
        parser = _parser()
        with path.open(encoding="utf-8") as fh:
            parser.read_file(fh)
        gates: dict[str, Gate] = {}
        for section in parser.sections():
            gates[section] = _gate_from_section(section, parser[section])
        return cls(gates, path)

    @classmethod
    def find(cls, start: Path | None = None) -> "Registry":
        """Load the registry by walking up from `start` to the repo root."""
        root = find_root(start or Path.cwd())
        return cls.load(root / DEFAULT_REGISTRY_PATH)

    # -- reading -----------------------------------------------------------

    def __contains__(self, gate_id: str) -> bool:
        return gate_id in self._gates

    def __iter__(self):
        return iter(self._gates.values())

    def ids(self) -> list[str]:
        return list(self._gates)

    def get(self, gate_id: str) -> Gate:
        try:
            return self._gates[gate_id]
        except KeyError:
            raise KeyError(f"no gate named {gate_id!r} in {self.path}") from None

    # -- writing -----------------------------------------------------------

    def set_state(self, gate_id: str, state: str) -> None:
        """Change a gate's state, in memory. Call `save()` to persist."""
        if state not in STATES:
            raise ValueError(f"unknown state {state!r}, expected one of {STATES}")
        gate = self.get(gate_id)
        if gate.tier == "advisory" and state == "proposed":
            # An advisory gate has no proposed phase — it is auto-approved. Let
            # a human decline it (off) or re-enable it (on), but not park it in
            # a state that would silently stop it running with no notice.
            raise ValueError(
                f"gate {gate_id!r} is advisory; it cannot be 'proposed' "
                "(use 'on' or 'off')"
            )
        self._gates[gate_id] = _replace_state(gate, state)

    def save(self, path: Path | None = None) -> None:
        """Write the registry back, editing only the `state` lines in place so
        the diff stays to the states that changed and the comments survive."""
        target = Path(path) if path else self.path
        if target is None:
            raise ValueError("no path to save to")
        text = target.read_text(encoding="utf-8")
        for gate in self._gates.values():
            text = _rewrite_state_line(text, gate.id, gate.state)
        target.write_text(text, encoding="utf-8")


# -- helpers ---------------------------------------------------------------


def _parser() -> configparser.ConfigParser:
    # Comment prefixes '#' only (the file uses '#'); keep keys case-sensitive so
    # a future value is never silently lowercased.
    parser = configparser.ConfigParser(comment_prefixes=("#",), inline_comment_prefixes=None)
    parser.optionxform = str  # preserve key case
    return parser


def _gate_from_section(gate_id: str, section) -> Gate:
    tier = section.get("tier", "").strip()
    if tier not in TIERS:
        raise ValueError(
            f"gate {gate_id!r}: tier must be one of {TIERS}, got {tier!r}"
        )
    state = section.get("state", "").strip() or default_state(tier)
    if state not in STATES:
        raise ValueError(
            f"gate {gate_id!r}: state must be one of {STATES}, got {state!r}"
        )
    if tier == "advisory" and state == "proposed":
        raise ValueError(
            f"gate {gate_id!r}: advisory gates have no 'proposed' state"
        )
    title = section.get("title", "").strip()
    run = section.get("run", "").strip()
    if not title:
        raise ValueError(f"gate {gate_id!r}: missing title")
    if not run:
        raise ValueError(f"gate {gate_id!r}: missing run command")
    return Gate(
        id=gate_id,
        tier=tier,
        state=state,
        title=title,
        run=run,
        cross=section.get("cross", "").strip(),
        setup=section.get("setup", "").strip(),
    )


def _replace_state(gate: Gate, state: str) -> Gate:
    return Gate(
        id=gate.id,
        tier=gate.tier,
        state=state,
        title=gate.title,
        run=gate.run,
        cross=gate.cross,
        setup=gate.setup,
    )


def _rewrite_state_line(text: str, gate_id: str, state: str) -> str:
    """Return `text` with gate `gate_id`'s `state = ...` line set to `state`.

    Walks the file section by section so it edits the state under the right
    [gate_id] header and nowhere else. If the section has no state line, one is
    inserted right after the header.
    """
    lines = text.splitlines(keepends=True)
    header = f"[{gate_id}]"
    in_section = False
    header_idx = -1
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            if in_section:
                # Left our section without finding a state line — insert one.
                break
            in_section = stripped == header
            if in_section:
                header_idx = i
            continue
        if in_section and stripped.lower().startswith("state"):
            indent = line[: len(line) - len(line.lstrip())]
            lines[i] = f"{indent}state = {state}\n"
            return "".join(lines)
    if header_idx >= 0:
        lines.insert(header_idx + 1, f"state = {state}\n")
        return "".join(lines)
    raise KeyError(f"no [{gate_id}] section in the registry text")


def find_root(start: Path) -> Path:
    """Walk up from `start` to the nearest directory holding .github/ci-gates.

    So the tool answers the same from anywhere in the checkout, exactly like
    tools/lineage's find_root.
    """
    start = Path(start).resolve()
    for candidate in (start, *start.parents):
        if (candidate / ".github" / "ci-gates").is_dir():
            return candidate
    return start
