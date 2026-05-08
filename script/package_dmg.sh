#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacDev"
VERSION="${MACDEV_VERSION:-0.1.0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

cd "$ROOT_DIR"
MACDEV_VERSION="$VERSION" MACDEV_CONFIGURATION=release ./script/build_and_run.sh build-only

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "create-dmg is required for release DMGs. Install it with: brew install create-dmg" >&2
  exit 1
fi

rm -f "$DMG_PATH" "$DIST_DIR/$APP_NAME $VERSION.dmg" "$DIST_DIR/$APP_NAME.dmg"

CREATE_DMG_HELP="$(create-dmg --help 2>&1 || true)"
if [[ "$CREATE_DMG_HELP" == *"--dmg-title"* ]]; then
  create-dmg \
    --overwrite \
    --no-code-sign \
    --dmg-title="$APP_NAME $VERSION" \
    "$APP_BUNDLE" \
    "$DIST_DIR"
else
  create-dmg "$APP_BUNDLE" "$DIST_DIR"
fi

if [[ -f "$DIST_DIR/$APP_NAME $VERSION.dmg" ]]; then
  mv "$DIST_DIR/$APP_NAME $VERSION.dmg" "$DMG_PATH"
elif [[ -f "$DIST_DIR/$APP_NAME.dmg" ]]; then
  mv "$DIST_DIR/$APP_NAME.dmg" "$DMG_PATH"
fi

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Expected DMG was not created at $DMG_PATH" >&2
  exit 1
fi

echo "$DMG_PATH"
