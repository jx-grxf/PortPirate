#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PortPirate"
VERSION="${PORTPIRATE_VERSION:-0.1.0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
STAGING_DIR="$DIST_DIR/dmg-staging"

cd "$ROOT_DIR"
PORTPIRATE_VERSION="$VERSION" PORTPIRATE_CONFIGURATION=release ./script/build_and_run.sh build-only

BACKGROUND_SRC="$ROOT_DIR/Assets/dmg/dmg-background.tiff"
BACKGROUND_1X_SRC="$ROOT_DIR/Assets/dmg/dmg-background.png"
BACKGROUND_2X_SRC="$ROOT_DIR/Assets/dmg/dmg-background@2x.png"
if [[ ! -f "$BACKGROUND_SRC" || ! -f "$BACKGROUND_1X_SRC" || ! -f "$BACKGROUND_2X_SRC" ]]; then
  echo "Regenerating DMG background assets..."
  /usr/bin/swift "$ROOT_DIR/script/generate_dmg_background.swift"
fi

CREATE_DMG_BIN=""
for candidate in \
  "/opt/homebrew/opt/create-dmg/bin/create-dmg" \
  "/usr/local/opt/create-dmg/bin/create-dmg" \
  "/opt/homebrew/bin/create-dmg" \
  "/usr/local/bin/create-dmg" \
  "$(command -v create-dmg 2>/dev/null || true)"; do
  [[ -z "$candidate" ]] && continue
  [[ ! -x "$candidate" ]] && continue
  if "$candidate" --help 2>&1 | grep -q -- "--volname"; then
    CREATE_DMG_BIN="$candidate"
    break
  fi
done

if [[ -z "$CREATE_DMG_BIN" ]]; then
  if ! command -v create-dmg >/dev/null 2>&1; then
    echo "create-dmg is required for release DMGs. Install it with: brew install create-dmg" >&2
    exit 1
  fi
  CREATE_DMG_BIN="$(command -v create-dmg)"
  echo "warning: using $CREATE_DMG_BIN, which does not support custom background. Install the Homebrew create-dmg formula for the branded DMG layout." >&2
fi

rm -rf "$STAGING_DIR"
rm -f "$DMG_PATH" "$DIST_DIR/$APP_NAME $VERSION.dmg" "$DIST_DIR/$APP_NAME.dmg"

CREATE_DMG_HELP="$("$CREATE_DMG_BIN" --help 2>&1 || true)"
if [[ "$CREATE_DMG_HELP" == *"--volname"* ]]; then
  mkdir -p "$STAGING_DIR"
  cp -R "$APP_BUNDLE" "$STAGING_DIR/"
  "$CREATE_DMG_BIN" \
    --volname "$APP_NAME $VERSION" \
    --background "$BACKGROUND_SRC" \
    --window-pos 200 120 \
    --window-size 540 380 \
    --icon-size 112 \
    --icon "$APP_NAME.app" 140 200 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 400 200 \
    "$DMG_PATH" \
    "$STAGING_DIR"
elif [[ "$CREATE_DMG_HELP" == *"--dmg-title"* ]]; then
  "$CREATE_DMG_BIN" \
    --overwrite \
    --no-code-sign \
    --dmg-title="$APP_NAME $VERSION" \
    "$APP_BUNDLE" \
    "$DIST_DIR"
else
  mkdir -p "$STAGING_DIR"
  cp -R "$APP_BUNDLE" "$STAGING_DIR/"
  ln -s /Applications "$STAGING_DIR/Applications"
  "$CREATE_DMG_BIN" "$DMG_PATH" "$STAGING_DIR"
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

rm -rf "$STAGING_DIR"
echo "$DMG_PATH"
