#!/usr/bin/env bash
# Run affected build, test, and quality checks for PR.
# Usage: ./scripts/run_affected.sh [base_ref]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=== Affected pipeline ==="
eval "$(bash "$SCRIPT_DIR/affected_targets.sh" "$@" 2>/dev/null)"

BUILD_TARGETS="${BUILD_TARGETS:-}"
TEST_TARGETS="${TEST_TARGETS:-}"
QUALITY_TARGETS="${QUALITY_TARGETS:-}"

run_build() {
    if [[ -n "$BUILD_TARGETS" ]]; then
        echo "--- Building affected targets ---"
        buck2 build $BUILD_TARGETS
    else
        echo "No affected build targets."
    fi
}

run_tests() {
    if [[ -n "$TEST_TARGETS" ]]; then
        echo "--- Running affected tests ---"
        buck2 test $TEST_TARGETS
    else
        echo "No affected tests."
    fi
}

run_quality() {
    if [[ -n "$QUALITY_TARGETS" ]]; then
        echo "--- Running affected quality checks ---"
        buck2 build $QUALITY_TARGETS
    else
        echo "No affected quality targets."
    fi
}

# Fallback: if no targets detected, run full domain build
if [[ -z "$BUILD_TARGETS" ]] && [[ -z "$TEST_TARGETS" ]] && [[ -z "$QUALITY_TARGETS" ]]; then
    echo "Fallback: running //domains/..."
    buck2 build //domains/...
    buck2 build $(buck2 cquery "attrregexfilter(name, 'lint|fmt|sast', //domains/...)" 2>/dev/null | sed 's/ (prelude[^)]*)//' || true)
else
    run_build
    run_tests
    run_quality
fi
