#!/usr/bin/env bash
# Phase-1 sparse checkout helper.
#
# Prerequisites (set up by the workflow before this script runs):
#   • All BUCK files checked out  (git ls-tree | xargs git checkout HEAD --)
#   • buck2 in PATH               (installed before this step)
#
# With those in place, buck2 uquery has a full view of the repository's
# build graph and can resolve dependencies and reverse-dependencies
# globally — no git show, grep, or sed on BUCK file content required.
#
# uquery (unconfigured query) is used rather than cquery because at this
# phase only BUCK files are on disk; source files for packages outside the
# initial sparse cone do not exist yet.  cquery validates source attributes
# and silently drops packages whose srcs/test files are absent, causing rdeps
# to miss downstream consumers.  uquery reads only dependency edges and is
# unaffected by missing source blobs.
#
# Usage:  bash scripts/compute_sparse_dirs.sh [BASE_REF]
#         bash scripts/compute_sparse_dirs.sh --files file1 file2 ...
#
# Outputs (eval-friendly shell exports):
#   SPARSE_DIRS   — space-separated package dirs that must be checked out
#   NEEDS_NODE    — true | false
#   NEEDS_PYTHON  — true | false
set -uo pipefail

BASE_REF="${1:-HEAD~1}"
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

cd "$REPO_ROOT"

strip_config() { sed 's/ ([^)]*)$//' 2>/dev/null || cat; }

# ── Changed files ─────────────────────────────────────────────────────────────
if [[ "$BASE_REF" == "--files" ]]; then
  shift
  mapfile -t CHANGED < <(printf '%s\n' "$@")
else
  mapfile -t CHANGED < <(git diff --name-only "${BASE_REF}...HEAD" 2>/dev/null || true)
fi

>&2 echo "[sparse] Changed files (${#CHANGED[@]}): ${CHANGED[*]:-<none>}"

_empty() {
  echo "export SPARSE_DIRS=''"
  echo "export NEEDS_NODE='false'"
  echo "export NEEDS_PYTHON='false'"
}

[[ ${#CHANGED[@]} -eq 0 ]] && _empty && exit 0

# ── Find affected packages (filesystem walk — BUCK files are on disk now) ────
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
  for f in "${CHANGED[@]}"; do
    [[ -z "$f" ]] && continue
    nearest_package "$f" || true
  done | sort -u
)

>&2 echo "[sparse] Affected packages (${#PACKAGES[@]}): ${PACKAGES[*]:-<none>}"
[[ ${#PACKAGES[@]} -eq 0 ]] && _empty && exit 0

# ── Enumerate owning targets via uquery ───────────────────────────────────────
# uquery (unconfigured) reads only BUCK file structure and dependency edges —
# it does NOT validate that source files exist on disk.  This is critical here
# because only BUCK files have been checked out (via git cat-file); actual
# source files for packages outside the initial sparse cone are absent.
# cquery would fail silently for those packages; uquery handles them correctly.
OWNING=""
for pkg in "${PACKAGES[@]}"; do
  res=$(buck2 uquery "kind('genrule|sh_test', //$pkg/...)" 2>/dev/null \
    | strip_config || true)
  OWNING+=$'\n'"$res"
done
OWNING="$(echo "$OWNING" | sed '/^$/d' | sort -u)"

>&2 echo "[sparse] Owning targets: $(echo "$OWNING" | tr '\n' ' ')"
[[ -z "$OWNING" ]] && _empty && exit 0

# ── Expand to transitive reverse-deps — //... = full repo (all BUCK on disk) ──
TARGETS_SET="set($(echo "$OWNING" | tr '\n' ' '))"
# No 2>/dev/null — let Buck2 errors surface in the CI log so we can debug
# if uquery fails to load a package or resolve a dependency.
ALL_IMPACTED=$(buck2 uquery "rdeps(//..., $TARGETS_SET)" \
  | strip_config | sed '/^$/d' || true)
[[ -n "$ALL_IMPACTED" ]] && OWNING="$ALL_IMPACTED"

>&2 echo "[sparse] All impacted: $(echo "$OWNING" | tr '\n' ' ')"

# ── Extract unique package directories from target labels ─────────────────────
# //domains/api/js:api_js_lint  →  domains/api/js
mapfile -t DIRS < <(
  echo "$OWNING" | grep -oE '//[^:]+' | sed 's|^//||' | sort -u
)

>&2 echo "[sparse] Sparse dirs (${#DIRS[@]}): ${DIRS[*]:-<none>}"
[[ ${#DIRS[@]} -eq 0 ]] && _empty && exit 0

# ── Detect required toolchains (git cat-file — no source blobs needed) ────────
NEEDS_NODE=false
NEEDS_PYTHON=false
for d in "${DIRS[@]}"; do
  git cat-file -e "HEAD:$d/package.json"     2>/dev/null && NEEDS_NODE=true
  git cat-file -e "HEAD:$d/requirements.txt" 2>/dev/null && NEEDS_PYTHON=true
  git cat-file -e "HEAD:$d/pyproject.toml"   2>/dev/null && NEEDS_PYTHON=true
done

>&2 echo "[sparse] Toolchains: node=$NEEDS_NODE python=$NEEDS_PYTHON"

echo "export SPARSE_DIRS='${DIRS[*]}'"
echo "export NEEDS_NODE='$NEEDS_NODE'"
echo "export NEEDS_PYTHON='$NEEDS_PYTHON'"
