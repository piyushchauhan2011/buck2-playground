#!/usr/bin/env bash
# Compute affected Buck targets from changed files.
# Outputs shell exports: BUILD_TARGETS, TEST_TARGETS, QUALITY_TARGETS
set -euo pipefail

BASE_REF="${1:-HEAD~1}"
CHANGED_FILES=()
BUCK2="${BUCK2:-buck2}"
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

cd "$REPO_ROOT"

if [[ "$BASE_REF" == "--files" ]]; then
  shift
  CHANGED_FILES=("$@")
else
  mapfile -t CHANGED_FILES < <(git diff --name-only "$BASE_REF" 2>/dev/null || true)
fi

if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
  echo "export BUILD_TARGETS=''"
  echo "export TEST_TARGETS=''"
  echo "export QUALITY_TARGETS=''"
  exit 0
fi

strip_config() {
  sed 's/ (prelude[^)]*)//' 2>/dev/null || cat
}

# nearest BUCK owner package: e.g. domains/api/js/src/app.ts -> domains/api/js
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

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  echo "export BUILD_TARGETS=''"
  echo "export TEST_TARGETS=''"
  echo "export QUALITY_TARGETS=''"
  exit 0
fi

# Query all owning targets for changed packages.
OWNING_TARGETS=""
for pkg in "${PACKAGES[@]}"; do
  q="//$pkg/..."
  res="$($BUCK2 cquery "$q" 2>/dev/null | strip_config || true)"
  OWNING_TARGETS+=$'\n'"$res"
done
OWNING_TARGETS="$(echo "$OWNING_TARGETS" | tr ' ' '\n' | sed '/^$/d' | sort -u)"

if [[ -z "$OWNING_TARGETS" ]]; then
  echo "export BUILD_TARGETS=''"
  echo "export TEST_TARGETS=''"
  echo "export QUALITY_TARGETS=''"
  exit 0
fi

# Expand to impacted (reverse deps across repo)
IMPACTED=""
while IFS= read -r t; do
  [[ -z "$t" ]] && continue
  res="$($BUCK2 cquery "rdeps(//..., $t)" 2>/dev/null | strip_config || true)"
  IMPACTED+=$'\n'"$res"
done <<< "$OWNING_TARGETS"
IMPACTED="$(echo "$IMPACTED" | tr ' ' '\n' | sed '/^$/d' | sort -u)"

# Classify by target label naming convention
TEST_TARGETS="$(echo "$IMPACTED" | rg '(_test$|_vitest$)' || true)"
QUALITY_TARGETS="$(echo "$IMPACTED" | rg '(lint$|fmt$|sast$|typecheck$)' || true)"
BUILD_TARGETS="$(echo "$IMPACTED" | rg -v '(_test$|_vitest$|lint$|fmt$|sast$|typecheck$)' || true)"

# Flatten to space-separated exports
BUILD_TARGETS="$(echo "$BUILD_TARGETS" | tr '\n' ' ' | xargs || true)"
TEST_TARGETS="$(echo "$TEST_TARGETS" | tr '\n' ' ' | xargs || true)"
QUALITY_TARGETS="$(echo "$QUALITY_TARGETS" | tr '\n' ' ' | xargs || true)"

echo "export BUILD_TARGETS='$BUILD_TARGETS'"
echo "export TEST_TARGETS='$TEST_TARGETS'"
echo "export QUALITY_TARGETS='$QUALITY_TARGETS'"
