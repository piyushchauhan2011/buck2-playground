#!/usr/bin/env bash
# Apply a sparse checkout profile to the current clone.
#
# Profiles are defined in common/profiles/<name>.json and list the
# directories each team needs.  Base directories (scripts, .github,
# toolchains, common/profiles) are always included automatically.
#
# Usage:
#   ./scripts/sparse-checkout.sh <profile>                          # apply to existing clone
#   ./scripts/sparse-checkout.sh --list                             # list available profiles
#   ./scripts/sparse-checkout.sh --new-clone <profile> <repo-url>   # fresh clone
#
# Profiles: backend  frontend  ml  infra  jvm
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILES_DIR="$REPO_ROOT/common/profiles"

# Always-present base directories in every sparse cone.
BASE_DIRS=(common/profiles scripts .github toolchains)

# ── Helpers ───────────────────────────────────────────────────────────────────
require_jq() {
  if ! command -v jq &>/dev/null; then
    echo "jq is not installed." >&2
    echo "  macOS:  brew install jq" >&2
    echo "  Ubuntu: apt-get install -y jq" >&2
    exit 1
  fi
}

list_profiles() {
  require_jq
  echo "Available profiles:"
  for f in "$PROFILES_DIR"/*.json; do
    name="$(basename "$f" .json)"
    owner="$(jq -r '.owner // "unknown owner"' "$f")"
    dirs="$(jq -r '.includeFolders | join(", ")' "$f")"
    printf "  %-12s  %-36s  %s\n" "$name" "$owner" "$dirs"
  done
}

apply_profile() {
  local profile="$1"
  local profile_file="$PROFILES_DIR/$profile.json"
  if [[ ! -f "$profile_file" ]]; then
    echo "Unknown profile: '$profile'" >&2
    echo "" >&2
    list_profiles
    exit 1
  fi
  mapfile -t PROFILE_DIRS < <(jq -r '.includeFolders[]' "$profile_file")
  git sparse-checkout set "${BASE_DIRS[@]}" "${PROFILE_DIRS[@]}"
}

# ── Argument parsing ──────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <profile>" >&2
  echo "       $0 --list" >&2
  echo "       $0 --new-clone <profile> <repo-url>" >&2
  echo "" >&2
  list_profiles
  exit 1
fi

case "$1" in
  --list)
    list_profiles
    exit 0
    ;;

  --new-clone)
    PROFILE="${2:?Usage: $0 --new-clone <profile> <repo-url>}"
    REPO_URL="${3:?Usage: $0 --new-clone <profile> <repo-url>}"
    require_jq
    echo "Cloning $REPO_URL with blobless filter…"
    git clone --filter=blob:none --no-checkout "$REPO_URL"
    REPO_DIR="$(basename "$REPO_URL" .git)"
    cd "$REPO_DIR"
    git sparse-checkout init --cone
    # Checkout base dirs first so the profile JSON file is on disk.
    git sparse-checkout set "${BASE_DIRS[@]}"
    git checkout
    # Now expand to the full profile.
    PROFILES_DIR="$PWD/common/profiles"
    apply_profile "$PROFILE"
    echo ""
    echo "Done. Sparse cone for profile '$PROFILE':"
    git sparse-checkout list
    exit 0
    ;;

  *)
    PROFILE="$1"
    ;;
esac

# ── Apply profile to existing clone ──────────────────────────────────────────
require_jq
cd "$REPO_ROOT"
echo "Applying profile: $PROFILE"
apply_profile "$PROFILE"

echo ""
echo "Sparse cone after applying '$PROFILE' profile:"
git sparse-checkout list
