#!/usr/bin/env bash
# Apply a sparse checkout profile to the current clone.
#
# Requires Sparo (npm install -g sparo).
# Profiles are defined in common/sparo-profiles/<name>.json.
# See: https://tiktok.github.io/sparo/pages/guide/sparo_profiles/
#
# Usage:
#   ./scripts/sparse-checkout.sh <profile>            # apply to existing clone
#   ./scripts/sparse-checkout.sh --list               # list available profiles
#   ./scripts/sparse-checkout.sh --new-clone <profile> <repo-url>  # fresh clone
#
# Profiles: backend  frontend  ml  infra  jvm
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILES_DIR="$REPO_ROOT/common/sparo-profiles"

# ── Helpers ───────────────────────────────────────────────────────────────────
list_profiles() {
  echo "Available profiles:"
  for f in "$PROFILES_DIR"/*.json; do
    name="$(basename "$f" .json)"
    owner="$(grep -oP '(?<=OWNER:   ).*' "$f" 2>/dev/null | head -1 || echo "")"
    dirs="$(jq -r '.includeFolders | map(select(. != "toolchains" and . != "scripts" and . != ".github")) | join(", ")' "$f" 2>/dev/null || echo "?")"
    printf "  %-12s  %-28s  %s\n" "$name" "${owner:-unknown owner}" "$dirs"
  done
}

require_sparo() {
  if ! command -v sparo &>/dev/null; then
    echo "Sparo is not installed. Run: npm install -g sparo" >&2
    echo "  https://tiktok.github.io/sparo/" >&2
    exit 1
  fi
}

# ── Argument parsing ──────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <profile>" >&2
  echo "       $0 --list" >&2
  echo "       $0 --new-clone <profile> <repo-url>" >&2
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
    require_sparo
    echo "Cloning $REPO_URL with blobless filter…"
    # sparo-ci clone uses treeless filter optimised for CI.
    # For local dev, use a blobless clone so history is available.
    git clone --filter=blob:none --no-checkout "$REPO_URL"
    REPO_DIR="$(basename "$REPO_URL" .git)"
    cd "$REPO_DIR"
    git sparse-checkout init --cone
    # Checkout just the scripts + profiles first so sparo can read them
    git sparse-checkout set scripts .github toolchains common/sparo-profiles
    git checkout
    # Now apply the full profile via sparo
    sparo checkout --profile "$PROFILE"
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
PROFILE_FILE="$PROFILES_DIR/$PROFILE.json"
if [[ ! -f "$PROFILE_FILE" ]]; then
  echo "Unknown profile: '$PROFILE'" >&2
  echo "" >&2
  list_profiles
  exit 1
fi

require_sparo

cd "$REPO_ROOT"
echo "Applying Sparo profile: $PROFILE"
sparo checkout --profile "$PROFILE"

echo ""
echo "Sparse cone after applying '$PROFILE' profile:"
git sparse-checkout list
