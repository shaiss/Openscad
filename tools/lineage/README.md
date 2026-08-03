# lineage — design lineage: who derives from whom

A *derivative* reuses another design's geometry and replaces part of it: keep
sushi-battleship's tray, put a different lid on it. In OpenSCAD that is one
line plus a redefinition —

```openscad
include <../sushi-battleship/sushi-battleship.scad>   // the parent, verbatim
module top() { ... }                                  // ...but this top() wins
```

— and the parent's own call sites route to the override. It works. What does
not exist, until this tool, is any *record* of the relationship, any way to
know what a change to the parent has to re-gate, and any way to notice when
the override quietly did nothing.

```
$ lineage check
FAIL  lineage: deep-tray: declares parent 'sushi-battleship' but designs/deep-tray/deep-tray.scad
      does not include it — add `include <../sushi-battleship/sushi-battleship.scad>`; the
      declaration is documentation, the include is what OpenSCAD reads

$ lineage blast-radius sushi-battleship
deep-tray
deep-tray-xl
sushi-battleship
```

(`check` prints one line per problem; the one above is wrapped for the page.)

Stdlib only, no runtime dependencies — CI runs `blast-radius` to decide what a
push has to gate, before anything is installed.

## Why it exists: four things OpenSCAD will not tell you

All four were measured in this repo's container on OpenSCAD 2021.01.

| Failure | What was measured |
|---|---|
| **The override is silent** | Typo the module name you meant to override (`Lid` for `lid`) and you get exit 0, no WARNING, no ERROR, a watertight STL that printcheck scores 100/100 — and it is *the base part you were trying to replace*. |
| **A typo'd override reproduces the parent's mesh** | Base and typo'd derivative both hashed to `cbd9c564b14e799f…`; a real override hashed differently. That difference is the only observable evidence an override took. |
| **Last include wins, silently** | Two parents both defining `lid()`: swapping the two `include` lines changed the exported mesh (12 facets vs 72, different hashes) with zero diagnostics. Include *order* is load-bearing and invisible. |
| **`include` is not guarded** | A diamond evaluates the shared ancestor twice — echo-counted: one parent fired the base's echo 1×, a diamond fired it 2×. The duplicate geometry unions cleanly (1 body, watertight, 100/100), so nothing downstream can see it. |

The nightly/manifold build could not be installed in that container. CI closes
most of that gap: `./scripts/lineage.sh selftest` runs in the `render-gate` job
under `openscad-nightly --backend=manifold`, blocking, and confirms every run
that a real override still changes the mesh, a typo'd one still reproduces the
base's, and a geometry-free entry point is still distinguishable. Whether
nightly prints a *diagnostic* nobody reads is still unasserted — assume the
silence.

The last one is why a design is only **base-safe** — safe to sit at the
confluence of a diamond — if its top level defines modules and emits no
top-level geometry.

## The file format: `designs/<name>/derives.conf`

House style, same as `ci.parts` / `printcheck.args` / `style.conf`:
line-oriented, `#` comments (whole-line or trailing), blank lines ignored,
`key: value`, values comma-separated.

```
# Parents in include order. LAST WINS on any module both define.
variant-of:    sushi-battleship
derivative-of:
replaces:      sushi-battleship:top, sushi-battleship:door
```

| Key | Meaning |
|---|---|
| `variant-of` | OKH "variant-of". Comma-separated parent design names. |
| `derivative-of` | OKH "derivative-of". Same shape; the tooling treats the two identically, so which you write is documentation for humans. |
| `replaces` | Parent-qualified `<parent>:<part>` entries — the parent `ci.parts` values this design claims to change. An empty part (`parent:`) means the parent's default render. |
| `diamond-ok` | Comma-separated ancestor names: an explicit, auditable "I know this creates a diamond on `<ancestor>`, and `<ancestor>` is base-safe". |

Anything else is an error, including `reuses:` — an earlier draft key that
named the parts a derivative inherited unchanged so the gate could skip them.
Everything is gated now; nothing is assumed inherited, because "inherited" is
exactly the assumption a silent override failure breaks.

The **combined ordered parent list** is every parent-bearing line in file
order, left to right within a line. That order must match the entry `.scad`'s
`include` lines, because include order silently decides which parent wins.

## Subcommands

Every subcommand takes `--root <dir>` (default: the repo the working
directory is in).

```bash
lineage check [name...]        # validate derives.conf; 1 line per problem
lineage blast-radius <name>... # the designs a change to these has to re-gate
lineage parents <name>         # direct parents, in include order
lineage children <name>        # direct children, sorted
lineage ancestors <name>       # transitive parents, sorted
lineage descendants <name>     # transitive children, sorted
lineage replaces <name>        # TAB-separated "<parent>\t<part>" per entry
lineage base-safe-required <name>   # ancestors whose base-safety the gate must prove
lineage order                  # every design in gallery order
lineage graph [--format text|json]  # the whole forest
```

```
$ lineage check
ok    lineage: 6 design(s), 2 with parents, deepest chain 3

$ lineage order
0	calibration-cube
0	sushi-battleship
1	deep-tray	sushi-battleship
2	deep-tray-xl	deep-tray

$ lineage replaces deep-tray
sushi-battleship	top

$ lineage graph
lineage: 4 design(s), 2 with parents

calibration-cube
sushi-battleship
└─ deep-tray  (replaces: sushi-battleship:top)
    └─ deep-tray-xl  (replaces: deep-tray:)
```

`order` lists every design, roots alphabetically, each immediately followed by
its descendants depth-first; a multi-parent design appears exactly once, under
its first declared parent. It is the listing a gallery or a docs page walks.

Exit codes: `0` the answer is on stdout, `1` the tree is wrong (`check`) or the
question has no answer (`blast-radius`, `order`, on a cycle), `2` the
invocation is wrong (no such design, no such root).

`blast-radius` never fails open. It decides what CI re-gates, so on a cycle or
an unparseable `derives.conf` it exits 1 with the reason on stderr rather than
printing a short list that looks like an answer. Unknown names are passed
through instead of dropped — the caller hands it whatever changed.

### Mesh identity: `mesh-hash` and `facet-count`

Two commands read one exported binary STL and never look at `designs/`, so
they take no `--root`. `scripts/gate.sh` compares parts with them.

```
$ lineage mesh-hash build/.lineage/flip-lid--top.stl
4a05bf59a1256560bc9d4611...
$ lineage facet-count build/.lineage/flip-lid--top.stl
24256
```

`mesh-hash` **canonicalises before hashing** — parse the facets, normalise
`-0.0` to `0.0`, sort the triangles, hash that — and the reason is the fifth
silent failure, the one you only meet when you build this gate:

> OpenSCAD 2021.01 writes the same mesh's facets in a **different order**
> between renders of unchanged source. Measured on `sushi-battleship`
> `part=top`, rendered twice with nothing edited: same facet count (24256),
> same file size (1 212 884 bytes), **3248 differing bytes**, and sorted
> triangle lists that match exactly.

A plain `sha256sum` of the file therefore says "different" for two renders of
the same thing — so in the override check the derivative always differs from
its parent, and the gate passes unconditionally. Small models do reproduce
byte for byte, which is exactly why a byte hash survives every toy test and
then quietly stops working on real designs. `tests/test_lineage.py` shuffles a
mesh's facet order and asserts the hash does not move.

A missing file hashes to the sentinel `empty-mesh` and counts 0 facets: that
is what a base-safe design renders to (OpenSCAD writes no file at all when the
top level emits nothing). A file that exists but is not a readable binary STL
is exit 1, never a quiet zero — a truncated export must not be able to prove a
design base-safe by failing to parse.

## What `lineage check` enforces

1. Unknown key.
2. `reuses:` — retired (see above).
3. A line with no `:`.
4. A duplicate key in one file. Keeping the last one silently is the exact
   footgun a lineage record exists to remove.
5. A parent that is not a design directory with a matching entry `.scad`.
6. Self-reference.
7. A cycle anywhere in the graph, named as a full path.
8. The same parent named in both `variant-of` and `derivative-of` (or twice
   under one key) — it would enter the ordered parent list twice, which no set
   of include lines can match.
9. A `replaces` entry that is not exactly `parent:part`. With more than one
   parent, a bare part name cannot be resolved.
10. A `replaces` parent that is not among this design's declared parents.
11. A `replaces` part that is not in the parent's `ci.parts`. When the parent
    ships no `ci.parts`, its only render is the default one (`parent:`).
12. **Declaration/include drift** — the declared parent list must equal the
    parent designs the entry `.scad` actually `include`s, *in the same order*.
    A declared-but-not-included parent is a derivative that overrides nothing;
    an included-but-not-declared one is invisible to the blast radius, so a
    change to it would not re-gate the design; and same-set-wrong-order is the
    measured last-include-wins trap. A design with no `derives.conf` that
    includes another design's entry `.scad` fails the same rule.
13. **Diamonds** fail by default, naming the confluence and both paths.
    `diamond-ok: <ancestor>` downgrades that to allowed — the render gate then
    proves the base-safety claim separately.
14. A `diamond-ok` entry that is not actually a diamond confluence for this
    design. An assertion that has silently stopped applying is the same class
    of bug it was written to prevent.

Syntax is reported before semantics, per file: a `derives.conf` that did not
parse has no trustworthy parent list, and piling drift errors on top of a
missing colon sends the reader chasing a problem that does not exist.

## What it deliberately does not do

**It never renders anything.** The two claims that matter most cannot be made
from text:

- *that an override actually took* — proved by exporting the derivative's part
  and the parent's part and comparing the meshes, because a typo'd override
  reproduces the parent's;
- *that an ancestor is base-safe* — proved by rendering it and looking for
  top-level geometry.

Both need geometry, so both live in `scripts/gate.sh`, with this tool telling
it *which* parts to compare (`lineage replaces`) and *which* claims to prove
(`lineage base-safe-required`). Keeping the resolver render-free is what lets
CI run it in a classifier job with nothing installed.

It also does not judge printability (that is `tools/printcheck/`) or style
(`tools/stylelift/`), and it has no opinion about whether a derivative is a
*good* idea — that is `/pm` and the review skills.

## Layout

```
src/lineage/
  conf.py     parse derives.conf (syntax + structure problems)
  scad.py     read include/use targets out of a .scad, resolve them
  graph.py    the lineage graph: closure, cycles, diamonds, gallery order
  checks.py   the validation rules and their messages
  cli.py      subcommands, exit codes
tests/        pytest suite over temp designs/ trees
```

Install: `pip install -e tools/lineage`, which is what puts the `lineage`
console script on PATH. `./scripts/lineage.sh <subcommand>` is the repo-root
wrapper the other scripts call.

Run tests: `python -m pytest tools/lineage/tests -q` — no install required,
`tests/conftest.py` puts `src/` on the path.
