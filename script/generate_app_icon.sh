#!/usr/bin/env bash
set -euo pipefail

SOURCE_ICON="${1:-Assets/AppIcon/Source/macdev_logo.icon}"
WEBSITE_ROOT="${2:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ICON_DIR="$ROOT_DIR/Assets/AppIcon"
ICON_TOOL="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"

if [[ ! -d "$ROOT_DIR/$SOURCE_ICON" && ! -d "$SOURCE_ICON" ]]; then
  echo "source .icon bundle not found: $SOURCE_ICON" >&2
  exit 1
fi

if [[ ! -x "$ICON_TOOL" ]]; then
  echo "Icon Composer ictool not found at: $ICON_TOOL" >&2
  exit 1
fi

SOURCE_PATH="$SOURCE_ICON"
if [[ -d "$ROOT_DIR/$SOURCE_ICON" ]]; then
  SOURCE_PATH="$ROOT_DIR/$SOURCE_ICON"
fi

TMP_DIR="$(mktemp -d)"
ICONSET="$TMP_DIR/AppIcon.iconset"
mkdir -p "$ICONSET" "$APP_ICON_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

export_png() {
  local size="$1"
  local output="$2"
  "$ICON_TOOL" "$SOURCE_PATH" \
    --export-image \
    --output-file "$output" \
    --platform macOS \
    --rendition Default \
    --width "$size" \
    --height "$size" \
    --scale 1 >/dev/null
}

export_png 1024 "$APP_ICON_DIR/AppIcon1024.png"

for size in 16 32 128 256 512; do
  export_png "$size" "$ICONSET/icon_${size}x${size}.png"
  double_size=$((size * 2))
  export_png "$double_size" "$ICONSET/icon_${size}x${size}@2x.png"
done

iconutil -c icns "$ICONSET" -o "$APP_ICON_DIR/AppIcon.icns"

if [[ -n "$WEBSITE_ROOT" ]]; then
  mkdir -p "$WEBSITE_ROOT/public/projects/macdev"
  cp "$APP_ICON_DIR/AppIcon1024.png" "$WEBSITE_ROOT/public/projects/macdev/app-icon.png"
fi

echo "Generated MacDev app icon from $SOURCE_PATH"
