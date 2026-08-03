"""Parse designs/<name>/derives.conf — the lineage record.

House format, same shape as ci.parts / printcheck.args / style.conf:
line-oriented, `#` comments, blank lines ignored, `key: value`, values are
comma-separated lists.

    # Parents in include order. LAST WINS on any module both define.
    variant-of:    sushi-battleship
    derivative-of:
    replaces:      sushi-battleship:top, sushi-battleship:door

The parser is deliberately strict — unknown key, missing colon, repeated key
are all errors rather than something quietly ignored. This file's entire job
is to state a relationship OpenSCAD itself reports nothing about, so a line
that parses to "no opinion" is worse than a line that fails.

Problems collected here are *syntax and structure* only, worded ready for the
`FAIL  lineage: <design>: <message>` line the CLI prints; anything needing the
rest of the tree (does that parent exist? is that part real?) is checks.py.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

#: The only keys a derives.conf may carry. `variant-of` and `derivative-of`
#: are both OKH lineage keys and the tooling treats them identically — which
#: one you write is documentation for humans about the kind of relationship.
KEYS = ("variant-of", "derivative-of", "replaces", "diamond-ok")

#: Keys whose values are parent design names. The combined ordered parent
#: list is the concatenation of every parent-bearing line in FILE order,
#: left to right within a line, because that order has to match the entry
#: .scad's include order — include order is what silently decides which
#: parent wins when two of them define the same module.
PARENT_KEYS = ("variant-of", "derivative-of")

#: Keys that existed in an earlier draft of this format and must never come
#: back silently. `reuses:` named the parts a derivative claimed to inherit
#: unchanged, so they could be skipped by the gate; the decision was to gate
#: everything instead, because "inherited" is precisely the assumption a
#: silent override failure breaks.
RETIRED_KEYS = {
    "reuses": "every part of a derivative is rendered and gated, nothing is "
              "assumed inherited from its parent; delete the line",
}

_KEY_LIST = ", ".join(KEYS)


@dataclass(frozen=True)
class Entry:
    """One `key: value` line, in file order."""

    lineno: int
    key: str
    values: tuple[str, ...]
    raw: str


@dataclass
class DerivesConf:
    """A parsed derives.conf: its entries in file order, plus its problems."""

    path: Path
    entries: list[Entry] = field(default_factory=list)
    problems: list[str] = field(default_factory=list)

    @classmethod
    def load(cls, path: Path) -> DerivesConf:
        """Parse a derives.conf, collecting problems instead of raising.

        One bad line must not hide the rest of the file: a lineage record is
        read by a human deciding whether a relationship is declared correctly,
        and handing them one error at a time turns that into a guessing game.
        """
        conf = cls(path=Path(path))
        seen: dict[str, int] = {}
        for lineno, raw in enumerate(path.read_text().splitlines(), start=1):
            # Trailing comments are stripped as well as whole-line ones. No
            # legal value (a design name, a part name) can contain '#', and
            # without this a `variant-of: base  # the tray` fails as an
            # unknown parent named "base  # the tray" — a real error message
            # about an imaginary problem.
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            if ":" not in line:
                conf.problems.append(
                    f"line {lineno}: {line!r} has no ':' — every line is "
                    f"'key: value' (keys: {_KEY_LIST})")
                continue
            key, _, value = line.partition(":")
            key = key.strip()
            if key in RETIRED_KEYS:
                conf.problems.append(
                    f"line {lineno}: '{key}:' is retired — "
                    f"{RETIRED_KEYS[key]}")
                continue
            if key not in KEYS:
                conf.problems.append(
                    f"line {lineno}: unknown key {key!r} — the only keys are "
                    f"{_KEY_LIST}")
                continue
            if key in seen:
                conf.problems.append(
                    f"line {lineno}: duplicate key {key!r} (already on line "
                    f"{seen[key]}) — merge them into one comma-separated "
                    f"line; keeping the last one silently is the exact footgun "
                    f"this file exists to remove")
                continue
            seen[key] = lineno
            values = tuple(v.strip() for v in value.split(",") if v.strip())
            conf.entries.append(Entry(lineno, key, values, line))
        return conf

    def entry(self, key: str) -> Entry | None:
        """The entry for `key`, or None when the file does not carry it."""
        for e in self.entries:
            if e.key == key:
                return e
        return None

    def values(self, key: str) -> tuple[str, ...]:
        """Values declared under `key`, empty when absent or `key:` is bare."""
        e = self.entry(key)
        return e.values if e else ()

    @property
    def parents(self) -> list[str]:
        """Every declared parent, in the order the includes must appear in."""
        return [name for e in self.entries if e.key in PARENT_KEYS
                for name in e.values]

    def parent_keys(self, name: str) -> list[str]:
        """Which parent key(s) named `name` — one entry per mention."""
        return [e.key for e in self.entries if e.key in PARENT_KEYS
                for v in e.values if v == name]

    @property
    def replaces(self) -> tuple[str, ...]:
        """Raw `replaces` items; splitting into parent/part is checks.py's."""
        return self.values("replaces")

    @property
    def diamond_ok(self) -> tuple[str, ...]:
        """Ancestors this design asserts are safe to sit at a diamond."""
        return self.values("diamond-ok")


def split_replaces(item: str) -> tuple[str, str] | None:
    """Split a `<parent>:<part>` item, or None when it is not exactly that.

    The part half may be empty (`parent:`), meaning the parent's default
    render — the one it has when it ships no ci.parts. An item with no colon
    or with several is unresolvable rather than merely odd: with more than one
    parent there is nothing to attach a bare part name to.
    """
    if item.count(":") != 1:
        return None
    parent, _, part = item.partition(":")
    return parent.strip(), part.strip()
