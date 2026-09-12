#!/bin/bash
set -euo pipefail
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
expect_fail() {
    if TIMEOUT_SECONDS=1 "$DIR/run_fixture.sh" "$1"; then
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
if TESTS_DIR="$empty" "$DIR/test.sh"; then
    echo "missing-suite control unexpectedly passed" >&2
    exit 1
fi
echo "EXPECTED_GATE_FAILURE:missing-suite"
"$DIR/run_fixture.sh" "$DIR/fixtures/good.fixture.gd"
echo "RESTORED_GATE_PASS:good.fixture.gd"
