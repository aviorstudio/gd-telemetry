#!/usr/bin/env bash
set -euo pipefail
export RUNNER_TEMP="${RUNNER_TEMP:-$PWD/.artifacts/tmp}"
mkdir -p "$RUNNER_TEMP"
./tests/package_controls.sh dist/@aviorstudio_gd-telemetry.zip
