#!/bin/bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GODOT="${GODOT_BIN:-godot}"
FAILURES=0
for test in "$SCRIPT_DIR"/tests/*_test.gd; do
    echo "Running $(basename "$test")..."
    if ! "$GODOT" --headless --path "$SCRIPT_DIR" --script "$test" 2>&1; then
        FAILURES=$((FAILURES + 1))
    fi
done
exit $FAILURES