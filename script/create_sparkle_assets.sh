#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PortPirate"
VERSION="${PORTPIRATE_VERSION:-0.2.0}"
CHANNEL="${PORTPIRATE_UPDATE_CHANNEL:-stable}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ARCHIVES_DIR="$DIST_DIR/sparkle"
ZIP_PATH="$ARCHIVES_DIR/$APP_NAME-$VERSION.zip"
RELEASE_NOTES_PATH="$ARCHIVES_DIR/$APP_NAME-$VERSION.md"
GENERATE_APPCAST="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
DOWNLOAD_PREFIX="${PORTPIRATE_SPARKLE_DOWNLOAD_PREFIX:-https://github.com/jx-grxf/PortPirate/releases/download/v$VERSION}"
if [[ "$DOWNLOAD_PREFIX" != */ ]]; then
  DOWNLOAD_PREFIX="$DOWNLOAD_PREFIX/"
fi
EXPECTED_DOWNLOAD_URL="${DOWNLOAD_PREFIX}$APP_NAME-$VERSION.zip"

if [[ ! -x "$GENERATE_APPCAST" ]]; then
  echo "Sparkle generate_appcast tool is missing. Run: swift package resolve" >&2
  exit 1
fi

if [[ -z "${PORTPIRATE_SPARKLE_PRIVATE_KEY:-}" ]]; then
  echo "PORTPIRATE_SPARKLE_PRIVATE_KEY is required to sign Sparkle appcasts." >&2
  exit 1
fi

cd "$ROOT_DIR"
PORTPIRATE_VERSION="$VERSION" PORTPIRATE_CONFIGURATION=release ./script/build_and_run.sh build-only

rm -rf "$ARCHIVES_DIR"
mkdir -p "$ARCHIVES_DIR"

ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
cp RELEASE_NOTES.md "$RELEASE_NOTES_PATH"

appcast_args=(
  --download-url-prefix "$DOWNLOAD_PREFIX"
  --embed-release-notes
)

if [[ "$CHANNEL" == "beta" ]]; then
  appcast_args+=(--channel beta)
fi

printf '%s' "$PORTPIRATE_SPARKLE_PRIVATE_KEY" |
  "$GENERATE_APPCAST" --ed-key-file - "${appcast_args[@]}" "$ARCHIVES_DIR"

if ! grep -Fq "$EXPECTED_DOWNLOAD_URL" "$ARCHIVES_DIR/appcast.xml"; then
  echo "appcast.xml does not contain expected Sparkle enclosure URL: $EXPECTED_DOWNLOAD_URL" >&2
  exit 1
fi

echo "$ZIP_PATH"
echo "$ARCHIVES_DIR/appcast.xml"
