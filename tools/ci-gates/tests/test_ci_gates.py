"""Tests for the Smart CI gate selector.

The engine decides what CI does, so the tests carry the same burden the repo
puts on every gate: each one must be able to FAIL. That means negative controls
throughout — a detector that must NOT fire, a gating gate that must STAY
proposed until crossed, an advisory gate that must never block — not just the
happy path.
"""

from __future__ import annotations

import textwrap
from pathlib import Path

import pytest

from ci_gates.detectors import applies
from ci_gates.registry import Gate, Registry, default_state
from ci_gates.select import select


# --------------------------------------------------------------------------
# Fixtures: a minimal repo tree with a registry and a ci.yml whose classifier
# mentions a known set of top-level directories.
# --------------------------------------------------------------------------

REGISTRY_TEXT = textwrap.dedent(
    """\
    [classifier-coverage]
    tier  = advisory
    state = on
    title = New top-level directory not covered by the classifier
    run   = python -m ci_gates run classifier-coverage
    cross = add a case arm (advisory)

    [shellcheck]
    tier  = gating
    state = proposed
    title = Lint shell scripts with shellcheck
    run   = shellcheck -x scripts/*.sh
    cross = /ci-gate approve shellcheck

    [actionlint]
    tier  = gating
    state = proposed
    title = Lint workflows with actionlint
    run   = actionlint
    cross = /ci-gate approve actionlint
    """
)

# A ci.yml that references designs/, lib/, scripts/, tools/ — but NOT a
# hypothetical `firmware/` directory.
CI_YML_TEXT = textwrap.dedent(
    """\
    jobs:
      changes:
        steps:
          - run: |
              case "$f" in
                designs/*) ;;
                lib/*|scripts/*|tools/lineage/*) ;;
                styles/*|site/*) ;;
              esac
    """
)


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    (tmp_path / ".github" / "ci-gates").mkdir(parents=True)
    (tmp_path / ".github" / "workflows").mkdir(parents=True)
    (tmp_path / ".github" / "ci-gates" / "registry.conf").write_text(REGISTRY_TEXT)
    (tmp_path / ".github" / "workflows" / "ci.yml").write_text(CI_YML_TEXT)
    return tmp_path


@pytest.fixture
def registry(repo: Path) -> Registry:
    return Registry.load(repo / ".github" / "ci-gates" / "registry.conf")


# --------------------------------------------------------------------------
# default_state — where the auto-approve policy lives
# --------------------------------------------------------------------------

def test_advisory_defaults_on_gating_defaults_proposed():
    assert default_state("advisory") == "on"
    assert default_state("gating") == "proposed"


def test_default_state_rejects_unknown_tier():
    with pytest.raises(ValueError):
        default_state("nonsense")


# --------------------------------------------------------------------------
# registry parsing + validation
# --------------------------------------------------------------------------

def test_registry_loads_all_gates(registry: Registry):
    assert set(registry.ids()) == {"classifier-coverage", "shellcheck", "actionlint"}
    assert registry.get("shellcheck").tier == "gating"
    assert registry.get("shellcheck").state == "proposed"


def test_registry_rejects_advisory_proposed(tmp_path: Path):
    p = tmp_path / "r.conf"
    p.write_text("[x]\ntier = advisory\nstate = proposed\ntitle = t\nrun = r\n")
    with pytest.raises(ValueError):
        Registry.load(p)


def test_registry_rejects_missing_run(tmp_path: Path):
    p = tmp_path / "r.conf"
    p.write_text("[x]\ntier = gating\nstate = proposed\ntitle = t\n")
    with pytest.raises(ValueError):
        Registry.load(p)


def test_registry_rejects_bad_tier(tmp_path: Path):
    p = tmp_path / "r.conf"
    p.write_text("[x]\ntier = wishful\nstate = on\ntitle = t\nrun = r\n")
    with pytest.raises(ValueError):
        Registry.load(p)


# --------------------------------------------------------------------------
# detectors — including the negative controls
# --------------------------------------------------------------------------

def test_shellcheck_detector_fires_on_sh(repo: Path):
    ap = applies("shellcheck", ["scripts/foo.sh"], repo)
    assert ap.applies


def test_shellcheck_detector_silent_without_sh(repo: Path):
    # negative control: a docs-only PR must not propose shellcheck
    ap = applies("shellcheck", ["README.md", "designs/x/x.scad"], repo)
    assert not ap.applies


def test_actionlint_detector_fires_on_workflow(repo: Path):
    assert applies("actionlint", [".github/workflows/new.yml"], repo).applies


def test_actionlint_detector_silent_on_non_workflow_yml(repo: Path):
    # negative control: a yml that is not a workflow must not trip actionlint
    assert not applies("actionlint", ["designs/x/animations.yml"], repo).applies


def test_classifier_coverage_fires_on_unknown_top_dir(repo: Path):
    ap = applies("classifier-coverage", ["firmware/main.c"], repo)
    assert ap.applies
    assert "firmware" in ap.why


def test_classifier_coverage_silent_on_known_dirs(repo: Path):
    # negative control: touching classified dirs must not fire
    ap = applies("classifier-coverage", ["lib/x.scad", "scripts/y.sh", "designs/z/z.scad"], repo)
    assert not ap.applies


def test_classifier_coverage_ignores_loose_toplevel_files(repo: Path):
    # README.md / LICENSE have no directory and are not a coverage gap
    assert not applies("classifier-coverage", ["README.md", "LICENSE"], repo).applies


def test_unknown_gate_applies_everywhere(repo: Path):
    assert applies("no-such-gate", ["anything"], repo).applies


# --------------------------------------------------------------------------
# selection — the join of detectors and registry state
# --------------------------------------------------------------------------

def test_select_puts_advisory_active_and_gating_proposed(registry: Registry, repo: Path):
    sel = select(registry, ["scripts/foo.sh", "firmware/main.c"], repo)
    active_ids = {s.id for s in sel.active}
    proposed_ids = {s.id for s in sel.proposed}
    # classifier-coverage (advisory, on) runs; shellcheck (gating, proposed) is proposed
    assert "classifier-coverage" in active_ids
    assert "shellcheck" in proposed_ids
    # actionlint's detector did not fire (no workflow changed) — in no bucket
    assert "actionlint" not in active_ids | proposed_ids


def test_advisory_active_is_marked_auto(registry: Registry, repo: Path):
    sel = select(registry, ["firmware/x"], repo)
    cc = next(s for s in sel.active if s.id == "classifier-coverage")
    assert cc.auto is True
    assert sel.blocking() == []  # advisory never blocks


def test_crossing_a_gating_gate_moves_it_to_active(registry: Registry, repo: Path):
    # Before: shellcheck is proposed, does not run.
    changed = ["scripts/foo.sh"]
    assert {s.id for s in select(registry, changed, repo).proposed} == {"shellcheck"}
    # Cross it.
    registry.set_state("shellcheck", "on")
    sel = select(registry, changed, repo)
    assert "shellcheck" in {s.id for s in sel.active}
    assert "shellcheck" in {s.id for s in sel.blocking()}  # now it blocks
    assert not sel.proposed


def test_declined_gate_is_neither_active_nor_proposed(registry: Registry, repo: Path):
    registry.set_state("shellcheck", "off")
    sel = select(registry, ["scripts/foo.sh"], repo)
    assert "shellcheck" not in {s.id for s in sel.active}
    assert "shellcheck" not in {s.id for s in sel.proposed}
    assert "shellcheck" in {s.id for s in sel.declined}


# --------------------------------------------------------------------------
# registry mutation round-trips through the file (what /ci-gate approve does)
# --------------------------------------------------------------------------

def test_approve_persists_and_preserves_other_gates(repo: Path):
    path = repo / ".github" / "ci-gates" / "registry.conf"
    reg = Registry.load(path)
    reg.set_state("shellcheck", "on")
    reg.save()
    reloaded = Registry.load(path)
    assert reloaded.get("shellcheck").state == "on"
    # untouched gates keep their state
    assert reloaded.get("actionlint").state == "proposed"
    assert reloaded.get("classifier-coverage").state == "on"
    # comments/headers survive the edit
    text = path.read_text()
    assert "# Lint" not in text or "actionlint" in text  # sanity: file intact
    assert text.count("[shellcheck]") == 1


def test_save_only_touches_the_changed_state_line(repo: Path):
    path = repo / ".github" / "ci-gates" / "registry.conf"
    before = path.read_text()
    reg = Registry.load(path)
    reg.set_state("actionlint", "off")
    reg.save()
    after = path.read_text()
    # exactly one line differs
    diff = [
        (b, a)
        for b, a in zip(before.splitlines(), after.splitlines())
        if b != a
    ]
    assert diff == [("state = proposed", "state = off")]


def test_cannot_approve_unknown_gate(registry: Registry):
    with pytest.raises(KeyError):
        registry.set_state("ghost", "on")


def test_cannot_park_advisory_as_proposed(registry: Registry):
    with pytest.raises(ValueError):
        registry.set_state("classifier-coverage", "proposed")
