"""Telemetry: the repo measures itself (issue #93).

Capture turns one gate run (the gate.sh log, the preview tree, run metadata)
into one JSON line; report renders the committed NDJSON log into markdown.
Stdlib-only on purpose — see pyproject.toml.
"""
