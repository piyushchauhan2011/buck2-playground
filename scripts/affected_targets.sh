#!/usr/bin/env bash
# Affected targets and tests for PR/CI - maps changed files to owning targets,
# computes rdeps (impacted targets) and testsof (impacted tests).
set -uo pipefail

BASE_REF="${1:-HEAD~1}"
CHANGED_FILES=""
BUCK2="${BUCK2:-buck2}"
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

cd "$REPO_ROOT"

# Get changed files (relative to repo root)
if [[ "$BASE_REF" == "--files" ]]; then
    shift
    CHANGED_FILES="$*"
else
    CHANGED_FILES=$(git diff --name-only "$BASE_REF" 2>/dev/null || true)
fi

if [[ -z "$CHANGED_FILES" ]]; then
    echo "export BUILD_TARGETS=''"
    echo "export TEST_TARGETS=''"
    echo "export QUALITY_TARGETS=''"
    exit 0
fi

# Convert file paths to owning package patterns (domains/api/rust/main.rs -> domains/api/...)
get_packages() {
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        d="$(dirname "$f")"
        while [[ "$d" != "." ]] && [[ -n "$d" ]]; do
            [[ -f "$d/BUCK" ]] && { echo "$d/..."; break; }
            d=$(dirname "$d")
        done
        [[ -z "$d" ]] || [[ "$d" == "." ]] && echo "$(dirname "$f")/..."
    done <<< "$CHANGED_FILES"
}

PACKAGES=$(get_packages | sort -u)
FIRST_PKG=$(echo "$PACKAGES" | head -1)

# Build union of patterns for multi-package
build_union() {
    local first=1
    local result=""
    for p in $PACKAGES; do
        if [[ $first -eq 1 ]]; then
            result="//${p}"
            first=0
        else
            result="union($result, //${p})"
        fi
    done
    echo "$result"
}
PATTERNS=$(build_union)

strip_config() { sed 's/ (prelude[^)]*)//' 2>/dev/null || cat; }

# Owned targets (suppress buck2 daemon logs)
OWNING_TARGETS=$($BUCK2 cquery "kind(genrule, $PATTERNS)" 2>/dev/null | strip_config | grep -v '^$' || true)
[[ -z "$OWNING_TARGETS" ]] && OWNING_TARGETS=$($BUCK2 cquery "$PATTERNS" 2>/dev/null | strip_config || true)

# Impacted = rdeps of owning targets
IMPACTED=""
for t in $OWNING_TARGETS; do
    [[ -z "$t" ]] && continue
    IMPACTED="${IMPACTED}"$'\n'"$($BUCK2 cquery "rdeps(//..., $t)" 2>/dev/null | strip_config || true)"
done
IMPACTED=$(echo "$IMPACTED" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ' || true)

# Tests in affected packages + testsof
TESTS=$($BUCK2 cquery "filter('test', kind(genrule, $PATTERNS))" 2>/dev/null | strip_config || true)
TESTS="$TESTS $($BUCK2 cquery "testsof($PATTERNS)" 2>/dev/null | strip_config || true)"
TESTS=$(echo "$TESTS" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ' || true)

# Quality targets
QUALITY=$($BUCK2 cquery "attrregexfilter(name, 'lint|fmt|sast', $PATTERNS)" 2>/dev/null | strip_config || true)
QUALITY=$(echo "$QUALITY" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ' || true)

echo "export BUILD_TARGETS='$IMPACTED'"
echo "export TEST_TARGETS='$TESTS'"
echo "export QUALITY_TARGETS='$QUALITY'"
