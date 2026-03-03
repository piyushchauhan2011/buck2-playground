#!/usr/bin/env bash
# Phase-1 sparse checkout helper.
#
# Determines which package directories and language toolchains are needed for
# a PR using ONLY git tree/commit metadata — no file content (blobs) required.
# Safe to run immediately after a blobless partial clone where only scripts/
# and .github/ have been checked out.
#
# Usage:  bash scripts/compute_sparse_dirs.sh [BASE_REF]
#         bash scripts/compute_sparse_dirs.sh --files file1 file2 ...
#
# Outputs (eval-friendly shell exports):
#   SPARSE_DIRS   — space-separated list of affected package directories
#   NEEDS_NODE    — true | false
#   NEEDS_PYTHON  — true | false
set -uo pipefail

BASE_REF="${1:-HEAD~1}"
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

cd "$REPO_ROOT"

# ── Changed files ─────────────────────────────────────────────────────────────
if [[ "$BASE_REF" == "--files" ]]; then
  shift
  mapfile -t CHANGED < <(printf '%s\n' "$@")
else
  mapfile -t CHANGED < <(git diff --name-only "${BASE_REF}...HEAD" 2>/dev/null || true)
fi

>&2 echo "[sparse] Changed files (${#CHANGED[@]}): ${CHANGED[*]:-<none>}"

_empty_output() {
  echo "export SPARSE_DIRS=''"
  echo "export NEEDS_NODE='false'"
  echo "export NEEDS_PYTHON='false'"
}

if [[ ${#CHANGED[@]} -eq 0 ]]; then
  _empty_output; exit 0
fi

# ── All BUCK file paths from the git tree (no checkout needed) ────────────────
# git ls-tree only needs tree objects, which a blobless clone has.
mapfile -t BUCK_PATHS < <(
  git ls-tree -r --name-only HEAD 2>/dev/null | grep -E '(^|/)BUCK$' || true
)

>&2 echo "[sparse] BUCK files in tree: ${#BUCK_PATHS[@]}"

# ── Map each changed file to its nearest owning BUCK package ──────────────────
declare -A seen
DIRS=()
for f in "${CHANGED[@]}"; do
  [[ -z "$f" ]] && continue
  d="$(dirname "$f")"
  while [[ "$d" != "." && "$d" != "/" ]]; do
    # Check tree listing instead of filesystem (works with blobless clone)
    if printf '%s\n' "${BUCK_PATHS[@]}" | grep -qx "$d/BUCK"; then
      if [[ -z "${seen[$d]+x}" ]]; then
        seen[$d]=1
        DIRS+=("$d")
      fi
      break
    fi
    d="$(dirname "$d")"
  done
done

>&2 echo "[sparse] Affected dirs (${#DIRS[@]}): ${DIRS[*]:-<none>}"

if [[ ${#DIRS[@]} -eq 0 ]]; then
  _empty_output; exit 0
fi

# ── Detect required toolchains via git cat-file (no file content needed) ──────
# git cat-file -e exits 0 if the object exists at HEAD, 1 if not.
NEEDS_NODE=false
NEEDS_PYTHON=false
for d in "${DIRS[@]}"; do
  git cat-file -e "HEAD:$d/package.json"     2>/dev/null && NEEDS_NODE=true
  git cat-file -e "HEAD:$d/requirements.txt" 2>/dev/null && NEEDS_PYTHON=true
  git cat-file -e "HEAD:$d/pyproject.toml"   2>/dev/null && NEEDS_PYTHON=true
done

>&2 echo "[sparse] Toolchains needed: node=$NEEDS_NODE python=$NEEDS_PYTHON"

echo "export SPARSE_DIRS='${DIRS[*]}'"
echo "export NEEDS_NODE='$NEEDS_NODE'"
echo "export NEEDS_PYTHON='$NEEDS_PYTHON'"
