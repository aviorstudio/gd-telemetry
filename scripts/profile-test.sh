#!/usr/bin/env bash
set -euo pipefail
export RUNNER_TEMP="${RUNNER_TEMP:-$PWD/.artifacts/tmp}"
mkdir -p "$RUNNER_TEMP"
./tests/gate_controls.sh
./tests/test.sh
