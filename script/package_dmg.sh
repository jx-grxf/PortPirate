#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacDev"
VERSION="${MACDEV_VERSION:-0.1.0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
STAGING_DIR="$DIST_DIR/dmg-staging"

cd "$ROOT_DIR"
MACDEV_VERSION="$VERSION" MACDEV_CONFIGURATION=release ./script/build_and_run.sh build-only

rm -rf "$STAGING_DIR"
rm -f "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"

hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Expected DMG was not created at $DMG_PATH" >&2
  exit 1
fi

rm -rf "$STAGING_DIR"
echo "$DMG_PATH"
