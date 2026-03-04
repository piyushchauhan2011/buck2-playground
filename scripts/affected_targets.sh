#!/usr/bin/env bash
# Compute affected Buck targets from changed files.
# Outputs shell exports: BUILD_TARGETS, TEST_TARGETS, QUALITY_TARGETS
#
# Requires buck2 in PATH (installed by the workflow before this script runs).
# Uses native Buck2 query functions:
#   kind()             — enumerate genrule/sh_test targets in affected packages
#   rdeps()            — transitive reverse-dependencies within sparse universe
#   filter()           — classify test targets by name pattern
#   attrregexfilter()  — classify quality targets by name attribute
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

# Detect required toolchains from manifest files on disk.
NEEDS_NODE=false
NEEDS_PYTHON=false
for pkg in "${PACKAGES[@]}"; do
  [[ -f "$REPO_ROOT/$pkg/package.json" ]]                                           && NEEDS_NODE=true
  [[ -f "$REPO_ROOT/$pkg/requirements.txt" || -f "$REPO_ROOT/$pkg/pyproject.toml" ]] && NEEDS_PYTHON=true
done
>&2 echo "Toolchains needed: node=$NEEDS_NODE python=$NEEDS_PYTHON"

# Strip Buck2 configuration suffix, e.g. " (prelude//platforms:default#abc123)"
# uquery output has no suffix; this is a no-op for uquery results.
strip_config() { sed 's/ ([^)]*)$//' 2>/dev/null || cat; }

# ── Enumerate targets in affected packages ────────────────────────────────────
# Use uquery (unconfigured) so Buck2 reads only BUCK file dependency edges,
# not source file artifacts.  After Phase 2 sparse-checkout, affected package
# source files ARE on disk — but consumer packages (e.g. domains/api/js) that
# depend on a shared lib might only have their BUCK file present.  uquery
# handles that correctly; cquery would silently skip those packages.
OWNING_TARGETS=""
for pkg in "${PACKAGES[@]}"; do
  res=$(buck2 uquery "kind('genrule|sh_test', //$pkg/...)" 2>/dev/null \
    | strip_config || true)
  OWNING_TARGETS+=$'\n'"$res"
done
OWNING_TARGETS="$(echo "$OWNING_TARGETS" | sed '/^$/d' | sort -u)"
>&2 echo "Owning targets: $(echo "$OWNING_TARGETS" | tr '\n' ' ')"

if [[ -z "$OWNING_TARGETS" ]]; then
  echo "export BUILD_TARGETS=''"
  echo "export TEST_TARGETS=''"
  echo "export QUALITY_TARGETS=''"
  echo "export NEEDS_NODE='$NEEDS_NODE'"
  echo "export NEEDS_PYTHON='$NEEDS_PYTHON'"
  exit 0
fi

# ── Expand to transitive reverse-dependencies ─────────────────────────────────
# //... is bounded by BUCK files on disk — all present since the git cat-file
# step runs before this script.  uquery resolves the full cross-package graph.
TARGETS_SET="set($(echo "$OWNING_TARGETS" | tr '\n' ' '))"
# No 2>/dev/null — let Buck2 errors surface in the CI log so we can debug
# if uquery fails to load a package or resolve a dependency.
IMPACTED=$(buck2 uquery "rdeps(//..., $TARGETS_SET)" \
  | strip_config | sed '/^$/d' || true)
[[ -n "$IMPACTED" ]] && OWNING_TARGETS="$IMPACTED"
>&2 echo "After rdeps: $(echo "$OWNING_TARGETS" | tr '\n' ' ')"

# ── Classify into build / test / quality ─────────────────────────────────────
UNIVERSE="set($(echo "$OWNING_TARGETS" | tr '\n' ' '))"

TEST_TARGETS=$(buck2 uquery \
  "filter('(_test|_vitest)$', $UNIVERSE)" 2>/dev/null | strip_config || true)

QUALITY_TARGETS=$(buck2 uquery \
  "attrregexfilter(name, '(lint|fmt|sast|typecheck)$', $UNIVERSE)" 2>/dev/null \
  | strip_config || true)

BUILD_TARGETS=$(buck2 uquery \
  "filter('(?!.*((_test|_vitest|lint|fmt|sast|typecheck)$))', $UNIVERSE)" 2>/dev/null \
  | strip_config || true)

BUILD_TARGETS="$(echo   "$BUILD_TARGETS"   | tr '\n' ' ' | xargs || true)"
TEST_TARGETS="$(echo    "$TEST_TARGETS"    | tr '\n' ' ' | xargs || true)"
QUALITY_TARGETS="$(echo "$QUALITY_TARGETS" | tr '\n' ' ' | xargs || true)"

echo "export BUILD_TARGETS='$BUILD_TARGETS'"
echo "export TEST_TARGETS='$TEST_TARGETS'"
echo "export QUALITY_TARGETS='$QUALITY_TARGETS'"
echo "export NEEDS_NODE='$NEEDS_NODE'"
echo "export NEEDS_PYTHON='$NEEDS_PYTHON'"
