#!/usr/bin/env bash
set -euo pipefail
export RUNNER_TEMP="${RUNNER_TEMP:-$PWD/.artifacts/tmp}"
mkdir -p "$RUNNER_TEMP"
set -euo pipefail
test -f addon/plugin.cfg
python3 scripts/package_addon.py build dist/@aviorstudio_gd-telemetry.zip
python3 scripts/package_addon.py verify dist/@aviorstudio_gd-telemetry.zip
