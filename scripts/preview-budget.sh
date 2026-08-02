# shellcheck shell=bash
# shellcheck disable=SC2034  # consumed by the scripts that source this file
# Shared preview-GIF size budget, sourced (not executed) by animate.sh
# (the renderer) and readme-gate.sh (the CI gate) so the two can never
# disagree on what "over budget" means.
MAX_GIF_BYTES=$((6 * 1024 * 1024))
