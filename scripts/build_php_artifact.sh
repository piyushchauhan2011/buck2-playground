#!/usr/bin/env bash
# Build a deployable tarball for a PHP/Laravel app.
#
# Usage: build_php_artifact.sh <app_name> <version> [repo_root]
#
# App names (must match release workflow):
#   api-php       -> domains/api/php
#   api-php-admin -> domains/api/php-admin
#
# Output: {app_name}-{version}.tar.gz in repo root
set -euo pipefail

APP="${1:?Usage: build_php_artifact.sh <app_name> <version> [repo_root]}"
VERSION="${2:?Usage: build_php_artifact.sh <app_name> <version> [repo_root]}"
REPO_ROOT="${3:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

case "$APP" in
  api-php)
    APP_DIR="domains/api/php"
    ;;
  api-php-admin)
    APP_DIR="domains/api/php-admin"
    ;;
  *)
    echo "Unknown app: $APP" >&2
    echo "Valid apps: api-php, api-php-admin" >&2
    exit 1
    ;;
esac

cd "$REPO_ROOT"
APP_PATH="$REPO_ROOT/$APP_DIR"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App dir not found: $APP_PATH" >&2
  exit 1
fi

cd "$APP_PATH"
composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist

# Create tarball: app dir contents (including vendor) at top level
OUT_NAME="${APP}-${VERSION}.tar.gz"
OUT_PATH="$REPO_ROOT/$OUT_NAME"
tar -czf "$OUT_PATH" \
  --exclude='.env' \
  --exclude='.phpunit.result.cache' \
  --exclude='node_modules' \
  --exclude='storage/framework/views/*.php' \
  --exclude='bootstrap/cache/*.php' \
  -C "$REPO_ROOT" \
  "$APP_DIR"

echo "$OUT_PATH"
