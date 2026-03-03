#!/usr/bin/env bash
# Compute affected Buck targets from changed files.
# Outputs shell exports: BUILD_TARGETS, TEST_TARGETS, QUALITY_TARGETS
#
# Target discovery strategy (tried in order):
#   1. buck2 cquery  — accurate, uses native Buck2 semantics + rdeps expansion.
#                      Requires buck2 in PATH and BUCK files on disk (Phase 2).
#   2. grep fallback — parses BUCK files directly; works with no running daemon.
#                      No rdeps expansion; only directly-touched packages.
set -uo pipefail

BASE_REF="${1:-HEAD~1}"
CHANGED_FILES=()
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

cd "$REPO_ROOT"

if [[ "$BASE_REF" == "--files" ]]; then
  shift
  CHANGED_FILES=("$@")
else
  mapfile -t CHANGED_FILES < <(git diff --name-only "${BASE_REF}...HEAD" 2>/dev/null || true)
fi

>&2 echo "Changed files (${#CHANGED_FILES[@]}): ${CHANGED_FILES[*]:-<none>}"

if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
  echo "export BUILD_TARGETS=''"
  echo "export TEST_TARGETS=''"
  echo "export QUALITY_TARGETS=''"
  exit 0
fi

# Walk up from a file to find its nearest BUCK package directory.
nearest_package() {
  local file="$1" d
  d="$(dirname "$file")"
  while [[ "$d" != "." && "$d" != "/" ]]; do
    [[ -f "$d/BUCK" ]] && echo "$d" && return 0
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
  echo "export NEEDS_NODE='false'"
  echo "export NEEDS_PYTHON='false'"
  exit 0
fi

# Detect required toolchains from manifest files.
NEEDS_NODE=false
NEEDS_PYTHON=false
for pkg in "${PACKAGES[@]}"; do
  [[ -f "$REPO_ROOT/$pkg/package.json" ]]                                           && NEEDS_NODE=true
  [[ -f "$REPO_ROOT/$pkg/requirements.txt" || -f "$REPO_ROOT/$pkg/pyproject.toml" ]] && NEEDS_PYTHON=true
done
>&2 echo "Toolchains needed: node=$NEEDS_NODE python=$NEEDS_PYTHON"

# Strip Buck2 configuration suffix from cquery output lines.
strip_config() { sed 's/ ([^)]*)$//' 2>/dev/null || cat; }

# ── Strategy 1: buck2 cquery ─────────────────────────────────────────────────
# Used when buck2 is in PATH (CI after "Install Buck2"; local dev).
# Steps:
#   a) Enumerate all named targets in affected packages.
#   b) Expand to reverse-dependencies within the sparse checkout universe.
#   c) Classify with filter() and attrregexfilter().
OWNING_TARGETS=""
USED_CQUERY=false

if command -v buck2 >/dev/null 2>&1; then
  >&2 echo "Strategy: buck2 cquery"
  for pkg in "${PACKAGES[@]}"; do
    res=$(buck2 cquery "kind('genrule|sh_test', //$pkg/...)" 2>/dev/null \
      | strip_config || true)
    OWNING_TARGETS+=$'\n'"$res"
  done
  OWNING_TARGETS="$(echo "$OWNING_TARGETS" | sed '/^$/d' | sort -u)"

  if [[ -n "$OWNING_TARGETS" ]]; then
    USED_CQUERY=true
    # rdeps: find everything in the sparse-checkout universe that transitively
    # depends on the targets we just found.  //... is bounded by whatever
    # directories are currently checked out — exactly right for sparse CI.
    TARGETS_SET="set($(echo "$OWNING_TARGETS" | tr '\n' ' '))"
    IMPACTED=$(buck2 cquery "rdeps(//..., $TARGETS_SET)" 2>/dev/null \
      | strip_config || true)
    [[ -n "$IMPACTED" ]] && OWNING_TARGETS="$IMPACTED"
    >&2 echo "Owning+rdeps targets: $(echo "$OWNING_TARGETS" | tr '\n' ' ')"
  fi
fi

# ── Strategy 2: grep fallback ────────────────────────────────────────────────
# Used when buck2 is not available (e.g. Phase-1 of sparse CI, local without
# buck2 installed).  Reads BUCK files directly with grep.
if [[ -z "$(echo "$OWNING_TARGETS" | sed '/^$/d')" ]]; then
  >&2 echo "Strategy: BUCK file grep (fallback)"
  extract_targets() {
    grep -E '^\s*name\s*=\s*"' "$1" | grep -oE '"[^"]+"' | tr -d '"'
  }
  for pkg in "${PACKAGES[@]}"; do
    buck_file="$REPO_ROOT/$pkg/BUCK"
    [[ ! -f "$buck_file" ]] && continue
    while IFS= read -r t; do
      [[ -z "$t" ]] && continue
      OWNING_TARGETS+=$'\n'"//$pkg:$t"
    done < <(extract_targets "$buck_file")
  done
  OWNING_TARGETS="$(echo "$OWNING_TARGETS" | sed '/^$/d' | sort -u)"
  >&2 echo "Owning targets: $(echo "$OWNING_TARGETS" | tr '\n' ' ')"
fi

if [[ -z "$OWNING_TARGETS" ]]; then
  echo "export BUILD_TARGETS=''"
  echo "export TEST_TARGETS=''"
  echo "export QUALITY_TARGETS=''"
  echo "export NEEDS_NODE='$NEEDS_NODE'"
  echo "export NEEDS_PYTHON='$NEEDS_PYTHON'"
  exit 0
fi

# ── Classify into build / test / quality ─────────────────────────────────────
# When cquery is available use Buck2's native filter() functions for accuracy.
# Fall back to grep on the label string otherwise.
TEST_TARGETS=""
QUALITY_TARGETS=""
BUILD_TARGETS=""

if $USED_CQUERY; then
  UNIVERSE="set($(echo "$OWNING_TARGETS" | tr '\n' ' '))"
  TEST_TARGETS=$(buck2 cquery \
    "filter('(_test|_vitest)$', $UNIVERSE)" 2>/dev/null | strip_config || true)
  QUALITY_TARGETS=$(buck2 cquery \
    "attrregexfilter(name, '(lint|fmt|sast|typecheck)$', $UNIVERSE)" 2>/dev/null \
    | strip_config || true)
  BUILD_TARGETS=$(buck2 cquery \
    "filter('(?!.*((_test|_vitest|lint|fmt|sast|typecheck)$))', $UNIVERSE)" 2>/dev/null \
    | strip_config || true)
fi

# grep fallback for classification (also used when cquery classification fails)
if [[ -z "$TEST_TARGETS" && -z "$QUALITY_TARGETS" && -z "$BUILD_TARGETS" ]]; then
  TEST_TARGETS="$(echo    "$OWNING_TARGETS" | grep -E '(_test$|_vitest$)'                              || true)"
  QUALITY_TARGETS="$(echo "$OWNING_TARGETS" | grep -E '(lint$|fmt$|sast$|typecheck$)'                 || true)"
  BUILD_TARGETS="$(echo   "$OWNING_TARGETS" | grep -Ev '(_test$|_vitest$|lint$|fmt$|sast$|typecheck$)' || true)"
fi

BUILD_TARGETS="$(echo   "$BUILD_TARGETS"   | tr '\n' ' ' | xargs || true)"
TEST_TARGETS="$(echo    "$TEST_TARGETS"    | tr '\n' ' ' | xargs || true)"
QUALITY_TARGETS="$(echo "$QUALITY_TARGETS" | tr '\n' ' ' | xargs || true)"

echo "export BUILD_TARGETS='$BUILD_TARGETS'"
echo "export TEST_TARGETS='$TEST_TARGETS'"
echo "export QUALITY_TARGETS='$QUALITY_TARGETS'"
echo "export NEEDS_NODE='$NEEDS_NODE'"
echo "export NEEDS_PYTHON='$NEEDS_PYTHON'"
