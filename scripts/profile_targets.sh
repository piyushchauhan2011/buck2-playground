#!/usr/bin/env bash
# Compute Buck targets for a profile (all targets in includeFolders).
# Outputs same format as affected_targets.sh: BUILD_*, TEST_*, QUALITY_*, NEEDS_*.
#
# Usage: bash scripts/profile_targets.sh <profile_name>
# Requires: buck2 in PATH, profile JSON at common/profiles/<name>.json
set -uo pipefail

PROFILE="${1:?Usage: profile_targets.sh <profile_name>}"
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PROFILE_JSON="$REPO_ROOT/common/profiles/${PROFILE}.json"

cd "$REPO_ROOT"

if [[ ! -f "$PROFILE_JSON" ]]; then
  echo "Profile not found: $PROFILE_JSON" >&2
  echo "export BUILD_TARGETS=''"
  echo "export TEST_TARGETS=''"
  echo "export QUALITY_TARGETS=''"
  echo "export BUILD_NODE=''"
  echo "export BUILD_PYTHON=''"
  echo "export BUILD_PHP=''"
  echo "export BUILD_OTHER=''"
  echo "export TEST_NODE=''"
  echo "export TEST_PYTHON=''"
  echo "export TEST_PHP=''"
  echo "export TEST_OTHER=''"
  echo "export QUALITY_NODE=''"
  echo "export QUALITY_PYTHON=''"
  echo "export QUALITY_PHP=''"
  echo "export QUALITY_OTHER=''"
  echo "export NEEDS_NODE='false'"
  echo "export NEEDS_PYTHON='false'"
  echo "export NEEDS_PHP='false'"
  exit 0
fi

mapfile -t DIRS < <(jq -r '.includeFolders[]' "$PROFILE_JSON" 2>/dev/null || true)
>&2 echo "[profile] Dirs: ${DIRS[*]:-<none>}"

strip_config() { sed 's/ ([^)]*)$//' 2>/dev/null || cat; }

OWNING_TARGETS=""
for d in "${DIRS[@]}"; do
  [[ -z "$d" ]] && continue
  [[ ! -f "$REPO_ROOT/$d/BUCK" ]] && continue
  res=$(buck2 uquery "kind('genrule|sh_test', //$d/...)" 2>/dev/null \
    | strip_config || true)
  OWNING_TARGETS+=$'\n'"$res"
done
OWNING_TARGETS="$(echo "$OWNING_TARGETS" | sed '/^$/d' | sort -u)"

if [[ -z "$OWNING_TARGETS" ]]; then
  echo "export BUILD_TARGETS=''"
  echo "export TEST_TARGETS=''"
  echo "export QUALITY_TARGETS=''"
  echo "export BUILD_NODE=''"
  echo "export BUILD_PYTHON=''"
  echo "export BUILD_PHP=''"
  echo "export BUILD_OTHER=''"
  echo "export TEST_NODE=''"
  echo "export TEST_PYTHON=''"
  echo "export TEST_PHP=''"
  echo "export TEST_OTHER=''"
  echo "export QUALITY_NODE=''"
  echo "export QUALITY_PYTHON=''"
  echo "export QUALITY_PHP=''"
  echo "export QUALITY_OTHER=''"
  echo "export NEEDS_NODE='false'"
  echo "export NEEDS_PYTHON='false'"
  echo "export NEEDS_PHP='false'"
  exit 0
fi

>&2 echo "[profile] Targets: $(echo "$OWNING_TARGETS" | tr '\n' ' ')"

# Include deps for full build closure (e.g. libs/utils when building domains/api/python)
TARGETS_SET="set($(echo "$OWNING_TARGETS" | tr '\n' ' '))"
ALL_DEPS=$(buck2 uquery "deps($TARGETS_SET)" 2>/dev/null \
  | strip_config | sed '/^$/d' || true)
OWNING_TARGETS=$(echo -e "${OWNING_TARGETS}\n${ALL_DEPS}" | grep '^root//' | sort -u || true)

# Detect toolchains
mapfile -t AFFECTED_PKGS < <(
  echo "$OWNING_TARGETS" | grep -oE '//[^:]+' | sed 's|^//||' | sed 's|^root/||' | sort -u
)
NEEDS_NODE=false
NEEDS_PYTHON=false
NEEDS_PHP=false
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
  if [[ -f "$REPO_ROOT/$pkg/composer.json" ]] \
      || git cat-file -e "HEAD:$pkg/composer.json" 2>/dev/null; then
    NEEDS_PHP=true
  fi
done
>&2 echo "[profile] Toolchains: node=$NEEDS_NODE python=$NEEDS_PYTHON php=$NEEDS_PHP"

# Classify build / test / quality
UNIVERSE="set($(echo "$OWNING_TARGETS" | tr '\n' ' '))"
TEST_TARGETS=$(buck2 uquery \
  "filter('(_test|_vitest)$', $UNIVERSE)" 2>/dev/null | strip_config || true)
QUALITY_TARGETS=$(buck2 uquery \
  "attrregexfilter(name, '(lint|fmt|sast|typecheck)$', $UNIVERSE)" 2>/dev/null \
  | strip_config || true)
BUILD_TARGETS=$(echo "$OWNING_TARGETS" | tr '\n' ' ' | xargs || true)

BUILD_TARGETS="$(echo   "$BUILD_TARGETS"   | tr '\n' ' ' | xargs || true)"
TEST_TARGETS="$(echo    "$TEST_TARGETS"    | tr '\n' ' ' | xargs || true)"
QUALITY_TARGETS="$(echo "$QUALITY_TARGETS" | tr '\n' ' ' | xargs || true)"

# Split by language
classify_target() {
  local target="$1" pkg
  pkg=$(echo "$target" | grep -oE '//[^:]+' | sed 's|^//||' | sed 's|^root/||')
  [[ -z "$pkg" ]] && echo "other" && return
  if [[ -f "$REPO_ROOT/$pkg/composer.json" ]] \
      || git cat-file -e "HEAD:$pkg/composer.json" 2>/dev/null; then
    echo "php"
  elif [[ -f "$REPO_ROOT/$pkg/package.json" ]] \
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
  local targets="$1" node="" python="" php="" other="" lang
  for t in $targets; do
    [[ -z "$t" ]] && continue
    lang="$(classify_target "$t" | tr -d '[:space:]')"
    case "$lang" in
      node)   node="$node $t" ;;
      python) python="$python $t" ;;
      php)    php="$php $t" ;;
      *)      other="$other $t" ;;
    esac
  done
  printf '%s\n' "$(echo "$node" | xargs)" "$(echo "$python" | xargs)" "$(echo "$php" | xargs)" "$(echo "$other" | xargs)"
}

{ read -r BUILD_NODE; read -r BUILD_PYTHON; read -r BUILD_PHP; read -r BUILD_OTHER; } <<< "$(split_by_lang "$BUILD_TARGETS")"
{ read -r TEST_NODE; read -r TEST_PYTHON; read -r TEST_PHP; read -r TEST_OTHER; } <<< "$(split_by_lang "$TEST_TARGETS")"
{ read -r QUALITY_NODE; read -r QUALITY_PYTHON; read -r QUALITY_PHP; read -r QUALITY_OTHER; } <<< "$(split_by_lang "$QUALITY_TARGETS")"

echo "export BUILD_TARGETS='$BUILD_TARGETS'"
echo "export TEST_TARGETS='$TEST_TARGETS'"
echo "export QUALITY_TARGETS='$QUALITY_TARGETS'"
echo "export BUILD_NODE='$BUILD_NODE'"
echo "export BUILD_PYTHON='$BUILD_PYTHON'"
echo "export BUILD_PHP='$BUILD_PHP'"
echo "export BUILD_OTHER='$BUILD_OTHER'"
echo "export TEST_NODE='$TEST_NODE'"
echo "export TEST_PYTHON='$TEST_PYTHON'"
echo "export TEST_PHP='$TEST_PHP'"
echo "export TEST_OTHER='$TEST_OTHER'"
echo "export QUALITY_NODE='$QUALITY_NODE'"
echo "export QUALITY_PYTHON='$QUALITY_PYTHON'"
echo "export QUALITY_PHP='$QUALITY_PHP'"
echo "export QUALITY_OTHER='$QUALITY_OTHER'"
echo "export NEEDS_NODE='$NEEDS_NODE'"
echo "export NEEDS_PYTHON='$NEEDS_PYTHON'"
echo "export NEEDS_PHP='$NEEDS_PHP'"
