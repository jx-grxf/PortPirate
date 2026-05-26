#!/usr/bin/env bash
# Ephemeral demo stack for PortPirate: frontend + backend + fake DB listeners.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DURATION_SEC="${1:-120}"

mkdir -p "$REPO_ROOT/.tmp"
TEMP_DIR="$(mktemp -d "$REPO_ROOT/.tmp/demo-stack-XXXXXX")"

cleanup() {
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
  rm -rf "$TEMP_DIR"
}

trap cleanup EXIT INT TERM

cat >"$TEMP_DIR/README.md" <<EOF
# PortPirate demo stack (auto teardown)

Frontend :3000 | Backend :8080 | Fake DB :5432
EOF

PIDS=()
start_listener() {
  local port="$1"
  local label="$2"
  echo "$label" >"$TEMP_DIR/.port-$port"
  python3 -m http.server "$port" --directory "$TEMP_DIR" >/dev/null 2>&1 &
  PIDS+=("$!")
}

start_listener 3000 "frontend"
start_listener 8080 "backend"
start_listener 5432 "database"

echo "TEMP_DIR=$TEMP_DIR"
echo "FRONTEND_PID=${PIDS[0]} PORT=3000"
echo "BACKEND_PID=${PIDS[1]} PORT=8080"
echo "DATABASE_PID=${PIDS[2]} PORT=5432"
echo "TEARDOWN_IN_SEC=$DURATION_SEC"

sleep "$DURATION_SEC"
