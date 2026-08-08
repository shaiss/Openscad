"""Tests for the committed policy parser.

Strict parsing is the point: a typo'd key or a bad value must fail loudly, so
the routine never runs on a policy nobody wrote. Each guard has a
negative-control assertion.
"""

from __future__ import annotations

import pytest

from backlog_burn import config as cfg


def write(tmp_path, text):
    p = tmp_path / "backlog-burn.conf"
    p.write_text(text, encoding="utf-8")
    return str(p)


def test_parses_enabled_and_label(tmp_path):
    path = write(tmp_path, "enabled: true\nlabel: autonomy-ok\n")
    c = cfg.load(path)
    assert c.enabled is True
    assert c.label == "autonomy-ok"


def test_provider_defaults_to_anthropic(tmp_path):
    path = write(tmp_path, "enabled: true\n")
    assert cfg.load(path).provider == "anthropic"


def test_provider_zai(tmp_path):
    path = write(tmp_path, "enabled: true\nprovider: zai\n")
    assert cfg.load(path).provider == "zai"
    assert cfg.get("provider", path) == "zai"


def test_unknown_provider_fails_loudly(tmp_path):
    path = write(tmp_path, "provider: openai\n")
    with pytest.raises(ValueError, match="unknown provider 'openai'"):
        cfg.load(path)


def test_enabled_false(tmp_path):
    path = write(tmp_path, "enabled: false\nlabel: autonomy-ok\n")
    assert cfg.load(path).enabled is False


def test_comments_and_blank_lines_ignored(tmp_path):
    path = write(tmp_path, "# a comment\n\n  # indented comment\nenabled: true\n\nlabel: ship-me\n")
    c = cfg.load(path)
    assert c.enabled is True and c.label == "ship-me"


def test_missing_enabled_defaults_off(tmp_path):
    # Fail-safe: an incomplete file never reads as "on".
    path = write(tmp_path, "label: autonomy-ok\n")
    assert cfg.load(path).enabled is False


def test_unknown_key_fails_loudly(tmp_path):
    path = write(tmp_path, "enabled: true\nenabledd: true\n")
    with pytest.raises(ValueError, match="unknown key 'enabledd'"):
        cfg.load(path)


def test_duplicate_key_fails(tmp_path):
    path = write(tmp_path, "enabled: true\nenabled: false\n")
    with pytest.raises(ValueError, match="duplicate key 'enabled'"):
        cfg.load(path)


def test_bad_bool_fails(tmp_path):
    path = write(tmp_path, "enabled: yes\n")
    with pytest.raises(ValueError, match="must be 'true' or 'false'"):
        cfg.load(path)


def test_empty_label_fails(tmp_path):
    path = write(tmp_path, "enabled: true\nlabel:\n")
    with pytest.raises(ValueError, match="'label' must not be empty"):
        cfg.load(path)


def test_missing_colon_fails(tmp_path):
    path = write(tmp_path, "enabled true\n")
    with pytest.raises(ValueError, match="expected 'key: value'"):
        cfg.load(path)


def test_get_renders_strings(tmp_path):
    path = write(tmp_path, "enabled: true\nlabel: autonomy-ok\n")
    assert cfg.get("enabled", path) == "true"
    assert cfg.get("label", path) == "autonomy-ok"
    assert cfg.get("enabled", write(tmp_path, "enabled: false\n")) == "false"


def test_get_unknown_key_raises(tmp_path):
    path = write(tmp_path, "enabled: true\n")
    with pytest.raises(KeyError):
        cfg.get("cadence", path)


def test_committed_repo_config_is_wellformed():
    # The real committed file must parse and be well-formed — but deliberately
    # do NOT pin its values: flipping `enabled` or renaming `label` in a
    # reviewed PR is the intended toggle and must stay green, while a malformed
    # file still fails loudly (the guards above).
    c = cfg.load(".github/backlog-burn.conf")
    assert isinstance(c.enabled, bool)
    assert isinstance(c.label, str) and c.label.strip()
    assert c.provider in cfg.KNOWN_PROVIDERS
