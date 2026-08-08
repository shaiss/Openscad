# shellcheck shell=bash
# shellcheck disable=SC2034  # consumed by the scripts that source this file
# Shared preview size budgets, sourced (not executed) by the renderers
# (animate.sh, product-shot.sh, lifestyle-clip.sh) and readme-gate.sh (the CI
# gate) so the two sides can never disagree on what "over budget" means.
# MAX_GIF_BYTES bounds every committed GIF — deterministic animations and AI
# motion clips alike; MAX_SHOT_BYTES bounds product-shot and lifestyle PNGs.
MAX_GIF_BYTES=$((6 * 1024 * 1024))
MAX_SHOT_BYTES=$((3 * 1024 * 1024))
