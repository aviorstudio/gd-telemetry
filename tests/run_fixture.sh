#!/bin/bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GODOT="${GODOT_BIN:-godot}"
fixture="$1"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
status=0
timeout --foreground "${TIMEOUT_SECONDS:-5}s" "$GODOT" --headless --path "$ROOT_DIR" --script "$fixture" >"$log" 2>&1 || status=$?
cat "$log"
if [ "$status" -ne 0 ]; then
    exit 1
fi
if grep -Eq '(^| )ERROR:|SCRIPT ERROR:|USER ERROR:' "$log"; then
    exit 1
fi
sentinel="$(basename "$fixture" | sed 's/\.fixture//')"
if ! grep -Fq "TEST_REACHED:$sentinel" "$log"; then
    exit 1
fi
