#!/usr/bin/env bash
# Apply sparse checkout for a team profile.
# Usage: ./scripts/sparse-checkout.sh <profile> [repo_url]
# Profiles: backend, frontend, ml, infra, jvm
set -euo pipefail

PROFILE="${1:?Usage: $0 <profile> [repo_url]}"
REPO_URL="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_FILE="$SCRIPT_DIR/sparse-checkout-profiles/$PROFILE"

if [[ ! -f "$PROFILE_FILE" ]]; then
    echo "Unknown profile: $PROFILE. Available: backend, frontend, ml, infra, jvm" >&2
    exit 1
fi

if [[ -n "$REPO_URL" ]]; then
    echo "Clone with sparse checkout:"
    echo "  git clone --filter=blob:none --sparse $REPO_URL"
    echo "  cd <repo>"
    echo "  git sparse-checkout set \$(cat $PROFILE_FILE | tr '\n' ' ')"
    exit 0
fi

# Apply to existing repo
git sparse-checkout init --cone
git sparse-checkout set $(cat "$PROFILE_FILE" | tr '\n' ' ')
echo "Sparse checkout applied: $PROFILE"
git sparse-checkout list
