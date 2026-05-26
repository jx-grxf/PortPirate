#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PortPirate"
VERSION="${PORTPIRATE_VERSION:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
DMG_PATH="${PORTPIRATE_DMG_PATH:-}"

if [[ "${PORTPIRATE_NOTARY_ENABLED:-false}" != "true" ]]; then
  echo "Skipping notarization because PORTPIRATE_NOTARY_ENABLED is not true."
  exit 0
fi

if [[ -z "$DMG_PATH" ]]; then
  if [[ -z "$VERSION" ]]; then
    echo "PORTPIRATE_VERSION or PORTPIRATE_DMG_PATH is required." >&2
    exit 1
  fi
  DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
fi

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found: $DMG_PATH" >&2
  exit 1
fi

notary_args=()
if [[ -n "${PORTPIRATE_NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  notary_args=(--keychain-profile "$PORTPIRATE_NOTARY_KEYCHAIN_PROFILE")
else
  missing=()
  [[ -z "${PORTPIRATE_NOTARY_APPLE_ID:-}" ]] && missing+=(PORTPIRATE_NOTARY_APPLE_ID)
  [[ -z "${PORTPIRATE_NOTARY_TEAM_ID:-}" ]] && missing+=(PORTPIRATE_NOTARY_TEAM_ID)
  [[ -z "${PORTPIRATE_NOTARY_PASSWORD:-}" ]] && missing+=(PORTPIRATE_NOTARY_PASSWORD)
  if (( ${#missing[@]} > 0 )); then
    printf 'Missing notarization secrets: %s\n' "${missing[*]}" >&2
    exit 1
  fi
  notary_args=(
    --apple-id "$PORTPIRATE_NOTARY_APPLE_ID"
    --team-id "$PORTPIRATE_NOTARY_TEAM_ID"
    --password "$PORTPIRATE_NOTARY_PASSWORD"
  )
fi

xcrun notarytool submit "$DMG_PATH" "${notary_args[@]}" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
