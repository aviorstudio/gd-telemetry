#!/bin/bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TESTS_DIR="${TESTS_DIR:-$SCRIPT_DIR}"
GODOT="${GODOT_BIN:-godot}"
FAILURES=0
REACHED=0
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-60}"
shopt -s nullglob
tests=("$TESTS_DIR"/*_test.gd)
if [ "${#tests[@]}" -eq 0 ]; then
    echo "ERROR: no Godot test scripts found" >&2
    exit 1
fi
for test in "${tests[@]}"; do
    echo "Running $(basename "$test")..."
    log="$(mktemp)"
    status=0
    timeout --foreground "${TIMEOUT_SECONDS}s" "$GODOT" --headless --path "$ROOT_DIR" --script "$test" >"$log" 2>&1 || status=$?
    cat "$log"
    if [ "$status" -ne 0 ]; then
        echo "ERROR: $(basename "$test") exited $status" >&2
        FAILURES=$((FAILURES + 1))
    fi
    if grep -Eq '(^| )ERROR:|SCRIPT ERROR:|USER ERROR:' "$log"; then
        echo "ERROR: unexpected Godot error output in $(basename "$test")" >&2
        FAILURES=$((FAILURES + 1))
    fi
    if grep -Fq "TEST_REACHED:$(basename "$test")" "$log"; then
        REACHED=$((REACHED + 1))
    else
        echo "ERROR: assertion sentinel not reached in $(basename "$test")" >&2
        FAILURES=$((FAILURES + 1))
    fi
    rm -f "$log"
done
echo "TEST_ASSERTIONS_REACHED=$REACHED/${#tests[@]}"
exit $FAILURES
