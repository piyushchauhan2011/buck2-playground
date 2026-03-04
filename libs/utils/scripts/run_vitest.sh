#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

npm install --prefix "$PROJECT_DIR" >/dev/null 2>&1
npm run --prefix "$PROJECT_DIR" test
