#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

legacy_product="Mac""Dev"
legacy_lower="mac""dev"
legacy_upper="MAC""DEV"
legacy_bundle="at.johannesgrof.""$legacy_product"
legacy_pattern="$legacy_product|$legacy_lower|$legacy_upper|com\\.[^[:space:]]*$legacy_lower|$legacy_bundle"
tracked_files="$(mktemp)"
trap 'rm -f "$tracked_files"' EXIT

git ls-files -z >"$tracked_files"

if xargs -0 grep -InE "$legacy_pattern" <"$tracked_files"; then
  echo "Legacy product identifiers remain in tracked files." >&2
  exit 1
fi

required_patterns=(
  'name: "PortPirate"'
  'name: "PortPirateCore"'
  'BUNDLE_ID="at.johannesgrof.PortPirate"'
  'https://github.com/jx-grxf/PortPirate/releases/latest/download/appcast.xml'
)

for pattern in "${required_patterns[@]}"; do
  if ! grep -RIFq "$pattern" Package.swift script Sources Tests docs README.md .github 2>/dev/null; then
    echo "Expected PortPirate release identity marker missing: $pattern" >&2
    exit 1
  fi
done

echo "PortPirate release identity audit passed."
