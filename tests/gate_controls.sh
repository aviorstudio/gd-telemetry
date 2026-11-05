#!/bin/bash
set -euo pipefail
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
expect_fail() {
    if python3 "${TOOLS_ROOT:?Pinned cookbook required}/helpers/godot-test.py" --project "$DIR/.." --program "$1" --sentinel "TEST_REACHED:$(basename "$1" | sed 's/\.fixture//')" --timeout 1; then
        echo "negative control unexpectedly passed: $1" >&2
        exit 1
    fi
    echo "EXPECTED_GATE_FAILURE:$(basename "$1")"
}
expect_fail "$DIR/fixtures/runtime_error_zero.fixture.gd"
expect_fail "$DIR/fixtures/assertion_overwrite.fixture.gd"
expect_fail "$DIR/fixtures/parse_error.fixture.gd"
expect_fail "$DIR/fixtures/hang.fixture.gd"
empty="$(mktemp -d)"
trap 'rm -rf "$empty"' EXIT
if python3 "${TOOLS_ROOT:?Pinned cookbook required}/helpers/godot-test.py" --project "$DIR/.." --directory "$empty" --sentinel-prefix "TEST_REACHED:"; then
    echo "missing-suite control unexpectedly passed" >&2
    exit 1
fi
echo "EXPECTED_GATE_FAILURE:missing-suite"
python3 "${TOOLS_ROOT:?Pinned cookbook required}/helpers/godot-test.py" --project "$DIR/.." --program "$DIR/fixtures/good.fixture.gd" --sentinel "TEST_REACHED:good.gd" --timeout 5
echo "RESTORED_GATE_PASS:good.fixture.gd"
