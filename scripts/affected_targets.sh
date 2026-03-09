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
  echo "export BUILD_NODE=''"
  echo "export BUILD_PYTHON=''"
  echo "export BUILD_OTHER=''"
  echo "export TEST_NODE=''"
  echo "export TEST_PYTHON=''"
  echo "export TEST_OTHER=''"
  echo "export QUALITY_NODE=''"
  echo "export QUALITY_PYTHON=''"
  echo "export QUALITY_OTHER=''"
  echo "export NEEDS_NODE='false'"
  echo "export NEEDS_PYTHON='false'"
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
  echo "export BUILD_NODE=''"
  echo "export BUILD_PYTHON=''"
  echo "export BUILD_OTHER=''"
  echo "export TEST_NODE=''"
  echo "export TEST_PYTHON=''"
  echo "export TEST_OTHER=''"
  echo "export QUALITY_NODE=''"
  echo "export QUALITY_PYTHON=''"
  echo "export QUALITY_OTHER=''"
  echo "export NEEDS_NODE='false'"
  echo "export NEEDS_PYTHON='false'"
  exit 0
fi

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
  echo "export BUILD_NODE=''"
  echo "export BUILD_PYTHON=''"
  echo "export BUILD_OTHER=''"
  echo "export TEST_NODE=''"
  echo "export TEST_PYTHON=''"
  echo "export TEST_OTHER=''"
  echo "export QUALITY_NODE=''"
  echo "export QUALITY_PYTHON=''"
  echo "export QUALITY_OTHER=''"
  echo "export NEEDS_NODE='false'"
  echo "export NEEDS_PYTHON='false'"
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

# ── Detect toolchains from ALL affected packages (after rdeps expansion) ─────
# Checking PACKAGES (directly changed) was insufficient — packages pulled in
# via rdeps (e.g. domains/api/python when libs/common changes) were missed.
# After Phase-2 sparse expansion, every dir in OWNING_TARGETS is on disk.
# Fall back to git cat-file for packages outside the sparse cone.
mapfile -t AFFECTED_PKGS < <(
  echo "$OWNING_TARGETS" | grep -oE '//[^:]+' | sed 's|^//||' | sort -u
)
NEEDS_NODE=false
NEEDS_PYTHON=false
for pkg in "${AFFECTED_PKGS[@]}"; do
  if [[ -f "$REPO_ROOT/$pkg/package.json" ]] \
      || git cat-file -e "HEAD:$pkg/package.json" 2>/dev/null; then
    NEEDS_NODE=true
  fi
  if [[ -f "$REPO_ROOT/$pkg/requirements.txt" ]] \
      || [[ -f "$REPO_ROOT/$pkg/pyproject.toml" ]] \
      || git cat-file -e "HEAD:$pkg/requirements.txt" 2>/dev/null \
      || git cat-file -e "HEAD:$pkg/pyproject.toml" 2>/dev/null; then
    NEEDS_PYTHON=true
  fi
done
>&2 echo "Toolchains needed: node=$NEEDS_NODE python=$NEEDS_PYTHON"

# ── Classify into build / test / quality ─────────────────────────────────────
# Buck2 uses Rust's regex crate, which does NOT support lookaheads.
# Use filter/attrregexfilter for test and quality, then subtract via except()
# to get pure build targets — avoids the broken (?!...) negative lookahead.
UNIVERSE="set($(echo "$OWNING_TARGETS" | tr '\n' ' '))"

TEST_TARGETS=$(buck2 uquery \
  "filter('(_test|_vitest)$', $UNIVERSE)" 2>/dev/null | strip_config || true)

QUALITY_TARGETS=$(buck2 uquery \
  "attrregexfilter(name, '(lint|fmt|sast|typecheck)$', $UNIVERSE)" 2>/dev/null \
  | strip_config || true)

# BUILD = all affected targets.
# Running `buck2 build` on test/quality genrules is safe: genrules execute
# their cmd and cache the result; sh_test targets are just prepared, not run
# (only `buck2 test` executes them).  Keeping the full set avoids a fragile
# except() query whose result is cached anyway by the Test/Quality steps.
BUILD_TARGETS=$(echo "$OWNING_TARGETS" | tr '\n' ' ' | xargs || true)

BUILD_TARGETS="$(echo   "$BUILD_TARGETS"   | tr '\n' ' ' | xargs || true)"
TEST_TARGETS="$(echo    "$TEST_TARGETS"    | tr '\n' ' ' | xargs || true)"
QUALITY_TARGETS="$(echo "$QUALITY_TARGETS" | tr '\n' ' ' | xargs || true)"

# ── Split by language (node/python/other) for parallel job execution ──────────
# Package path: root//domains/api/js:api_js → domains/api/js
# Node: package.json; Python: requirements.txt or pyproject.toml
classify_target() {
  local target="$1" pkg
  pkg=$(echo "$target" | grep -oE '//[^:]+' | sed 's|^//||' | sed 's|^root/||')
  [[ -z "$pkg" ]] && echo "other" && return
  if [[ -f "$REPO_ROOT/$pkg/package.json" ]] \
      || git cat-file -e "HEAD:$pkg/package.json" 2>/dev/null; then
    echo "node"
  elif [[ -f "$REPO_ROOT/$pkg/requirements.txt" ]] \
      || [[ -f "$REPO_ROOT/$pkg/pyproject.toml" ]] \
      || git cat-file -e "HEAD:$pkg/requirements.txt" 2>/dev/null \
      || git cat-file -e "HEAD:$pkg/pyproject.toml" 2>/dev/null; then
    echo "python"
  else
    echo "other"
  fi
}

split_by_lang() {
  local targets="$1" node="" python="" other=""
  for t in $targets; do
    [[ -z "$t" ]] && continue
    case "$(classify_target "$t")" in
      node)   node=""$node" $t" ;;
      python) python=""$python" $t" ;;
      *)     other=""$other" $t" ;;
    esac
  done
  echo "$node" | xargs
  echo "$python" | xargs
  echo "$other" | xargs
}

{ read -r BUILD_NODE; read -r BUILD_PYTHON; read -r BUILD_OTHER; } <<< "$(split_by_lang "$BUILD_TARGETS")"
{ read -r TEST_NODE; read -r TEST_PYTHON; read -r TEST_OTHER; } <<< "$(split_by_lang "$TEST_TARGETS")"
{ read -r QUALITY_NODE; read -r QUALITY_PYTHON; read -r QUALITY_OTHER; } <<< "$(split_by_lang "$QUALITY_TARGETS")"

>&2 echo "Build  node: $BUILD_NODE"
>&2 echo "Build  python: $BUILD_PYTHON"
>&2 echo "Build  other: $BUILD_OTHER"
>&2 echo "Test   node: $TEST_NODE"
>&2 echo "Test   python: $TEST_PYTHON"
>&2 echo "Test   other: $TEST_OTHER"
>&2 echo "Quality node: $QUALITY_NODE"
>&2 echo "Quality python: $QUALITY_PYTHON"
>&2 echo "Quality other: $QUALITY_OTHER"

echo "export BUILD_TARGETS='$BUILD_TARGETS'"
echo "export TEST_TARGETS='$TEST_TARGETS'"
echo "export QUALITY_TARGETS='$QUALITY_TARGETS'"
echo "export BUILD_NODE='$BUILD_NODE'"
echo "export BUILD_PYTHON='$BUILD_PYTHON'"
echo "export BUILD_OTHER='$BUILD_OTHER'"
echo "export TEST_NODE='$TEST_NODE'"
echo "export TEST_PYTHON='$TEST_PYTHON'"
echo "export TEST_OTHER='$TEST_OTHER'"
echo "export QUALITY_NODE='$QUALITY_NODE'"
echo "export QUALITY_PYTHON='$QUALITY_PYTHON'"
echo "export QUALITY_OTHER='$QUALITY_OTHER'"
echo "export NEEDS_NODE='$NEEDS_NODE'"
echo "export NEEDS_PYTHON='$NEEDS_PYTHON'"
