#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(git -C "$PROJECT_DIR" rev-parse --show-toplevel)"

if [ ! -d "$WORKSPACE_ROOT/node_modules" ]; then
  pnpm install --dir "$WORKSPACE_ROOT" >/dev/null 2>&1
fi

pnpm run --dir "$PROJECT_DIR" test
