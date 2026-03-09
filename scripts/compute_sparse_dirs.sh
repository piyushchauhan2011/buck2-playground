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

# ── Include transitive dependencies (deps) for full build closure ──────────────
# rdeps gives consumers; we also need deps to build (e.g. api_js_build needs
# libs/common:common_build and libs/utils:utils_build). Without deps, sparse
# checkout omits libs/utils and the build fails with "tsconfig.build.json not found".
IMPACTED_SET="set($(echo "$OWNING" | tr '\n' ' '))"
ALL_DEPS=$(buck2 uquery "deps($IMPACTED_SET)" 2>/dev/null \
  | strip_config | sed '/^$/d' || true)
ALL_NEEDED=$(echo -e "${OWNING}\n${ALL_DEPS}" | sort -u)

>&2 echo "[sparse] All needed (impacted + deps): $(echo "$ALL_NEEDED" | tr '\n' ' ')"

# ── Extract unique package directories from target labels ─────────────────────
# //domains/api/js:api_js_lint  →  domains/api/js
# Only root// targets (our repo); exclude prelude// and toolchains// deps.
mapfile -t DIRS < <(
  echo "$ALL_NEEDED" | grep '^root//' | grep -oE '//[^:]+' | sed 's|^//||' | sed 's|^root/||' | sort -u
)

>&2 echo "[sparse] Sparse dirs (${#DIRS[@]}): ${DIRS[*]:-<none>}"
[[ ${#DIRS[@]} -eq 0 ]] && _empty && exit 0

# Toolchain detection (NEEDS_NODE / NEEDS_PYTHON) is intentionally NOT done
# here.  Phase-1 only has BUCK files on disk, so git cat-file checks can
# miss packages that become affected via rdeps but lack a direct dependency
# on the changed target.  Toolchain detection runs in affected_targets.sh
# instead, after Phase-2 has expanded the sparse cone and source files
# (including package.json / requirements.txt) are on disk.
echo "export SPARSE_DIRS='${DIRS[*]}'"
