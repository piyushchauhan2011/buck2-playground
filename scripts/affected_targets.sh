#!/usr/bin/env bash
# Compute affected Buck targets from changed files.
# Outputs shell exports: BUILD_TARGETS, TEST_TARGETS, QUALITY_TARGETS
#
# Target discovery: reads BUCK files directly with grep — no running buck2
# instance required.  This makes the script reliable in CI environments where
# the build graph hasn't been initialised.
#
# Rdeps expansion (finding targets that *consume* the changed packages) would
# need a live buck2 process; that's a future enhancement.  Direct-package
# detection is the right conservative default.
set -uo pipefail

BASE_REF="${1:-HEAD~1}"
CHANGED_FILES=()
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

cd "$REPO_ROOT"

if [[ "$BASE_REF" == "--files" ]]; then
  shift
  CHANGED_FILES=("$@")
else
  # Three-dot diff: merge-base(BASE_REF, HEAD)..HEAD — "what changed in this PR".
  # Works correctly in CI (clean tree) and locally (dirty tree).
  mapfile -t CHANGED_FILES < <(git diff --name-only "${BASE_REF}...HEAD" 2>/dev/null || true)
fi

>&2 echo "Changed files (${#CHANGED_FILES[@]}): ${CHANGED_FILES[*]:-<none>}"

if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
  echo "export BUILD_TARGETS=''"
  echo "export TEST_TARGETS=''"
  echo "export QUALITY_TARGETS=''"
  exit 0
fi

# Walk up from a file path until a directory containing a BUCK file is found.
nearest_package() {
  local file="$1"
  local d
  d="$(dirname "$file")"
  while [[ "$d" != "." && "$d" != "/" ]]; do
    if [[ -f "$d/BUCK" ]]; then
      echo "$d"
      return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}

mapfile -t PACKAGES < <(
  for f in "${CHANGED_FILES[@]}"; do
    [[ -z "$f" ]] && continue
    nearest_package "$f" || true
  done | sort -u
)

>&2 echo "Affected packages (${#PACKAGES[@]}): ${PACKAGES[*]:-<none>}"

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  echo "export BUILD_TARGETS=''"
  echo "export TEST_TARGETS=''"
  echo "export QUALITY_TARGETS=''"
  exit 0
fi

# Extract all named targets from a BUCK file without running buck2.
# Matches lines of the form:  name = "some_target"
# Uses grep -oE to pull the quoted value directly — avoids sed \s portability issues.
extract_targets() {
  local buck_file="$1"
  grep -E '^\s*name\s*=\s*"' "$buck_file" \
    | grep -oE '"[^"]+"' \
    | tr -d '"'
}

OWNING_TARGETS=""
for pkg in "${PACKAGES[@]}"; do
  buck_file="$REPO_ROOT/$pkg/BUCK"
  [[ ! -f "$buck_file" ]] && continue
  while IFS= read -r target_name; do
    [[ -z "$target_name" ]] && continue
    OWNING_TARGETS+=$'\n'"//$pkg:$target_name"
  done < <(extract_targets "$buck_file")
done
OWNING_TARGETS="$(echo "$OWNING_TARGETS" | sed '/^$/d' | sort -u)"

>&2 echo "Owning targets: $(echo "$OWNING_TARGETS" | tr '\n' ' ')"

if [[ -z "$OWNING_TARGETS" ]]; then
  echo "export BUILD_TARGETS=''"
  echo "export TEST_TARGETS=''"
  echo "export QUALITY_TARGETS=''"
  exit 0
fi

# Classify targets by naming convention (grep -E is universally available).
TEST_TARGETS="$(echo "$OWNING_TARGETS"    | grep -E '(_test$|_vitest$)'                          || true)"
QUALITY_TARGETS="$(echo "$OWNING_TARGETS" | grep -E '(lint$|fmt$|sast$|typecheck$)'              || true)"
BUILD_TARGETS="$(echo "$OWNING_TARGETS"   | grep -Ev '(_test$|_vitest$|lint$|fmt$|sast$|typecheck$)' || true)"

# Flatten to space-separated one-liners for $GITHUB_OUTPUT / eval.
BUILD_TARGETS="$(echo   "$BUILD_TARGETS"   | tr '\n' ' ' | xargs || true)"
TEST_TARGETS="$(echo    "$TEST_TARGETS"    | tr '\n' ' ' | xargs || true)"
QUALITY_TARGETS="$(echo "$QUALITY_TARGETS" | tr '\n' ' ' | xargs || true)"

echo "export BUILD_TARGETS='$BUILD_TARGETS'"
echo "export TEST_TARGETS='$TEST_TARGETS'"
echo "export QUALITY_TARGETS='$QUALITY_TARGETS'"
