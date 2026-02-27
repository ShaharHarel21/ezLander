#!/usr/bin/env bash
#
# start.sh - Start the EzLander preview server with a Cloudflare tunnel.
#
# This script:
#   1. Installs npm dependencies if needed
#   2. Ensures cloudflared is installed (via Homebrew)
#   3. Starts the Node.js preview server
#   4. Starts a cloudflared tunnel pointing to localhost:3333
#   5. Prints the tunnel URL
#   6. Cleans up everything on exit
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

PORT=3333

# PIDs to clean up
SERVER_PID=""
TUNNEL_PID=""

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
cleanup() {
  echo ""
  echo "[start.sh] Shutting down..."

  if [[ -n "$TUNNEL_PID" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
    echo "[start.sh] Stopping cloudflared tunnel (PID $TUNNEL_PID)..."
    kill "$TUNNEL_PID" 2>/dev/null || true
    wait "$TUNNEL_PID" 2>/dev/null || true
  fi

  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "[start.sh] Stopping preview server (PID $SERVER_PID)..."
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi

  # Kill any EzLander preview instances
  pkill -f "EzLander.app.*--preview-mode" 2>/dev/null || true

  echo "[start.sh] Done."
  exit 0
}

trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# 1. Install npm dependencies
# ---------------------------------------------------------------------------
if [[ ! -d "node_modules" ]]; then
  echo "[start.sh] Installing npm dependencies..."
  npm install
else
  echo "[start.sh] node_modules already present. Skipping npm install."
fi

# ---------------------------------------------------------------------------
# 2. Ensure cloudflared is installed
# ---------------------------------------------------------------------------
if ! command -v cloudflared &>/dev/null; then
  echo "[start.sh] cloudflared not found. Installing via Homebrew..."
  if ! command -v brew &>/dev/null; then
    echo "[start.sh] ERROR: Homebrew is not installed. Please install it first:"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
  fi
  brew install cloudflared
else
  echo "[start.sh] cloudflared is already installed."
fi

# ---------------------------------------------------------------------------
# 3. Start the Node.js preview server
# ---------------------------------------------------------------------------
echo "[start.sh] Starting preview server on port $PORT..."
node server.js &
SERVER_PID=$!

# Give the server a moment to start
sleep 2

if ! kill -0 "$SERVER_PID" 2>/dev/null; then
  echo "[start.sh] ERROR: Server failed to start."
  exit 1
fi

echo "[start.sh] Server running (PID $SERVER_PID)"
echo "[start.sh] Local: http://localhost:$PORT"
echo ""

# ---------------------------------------------------------------------------
# 4. Start cloudflared tunnel
# ---------------------------------------------------------------------------
echo "[start.sh] Starting cloudflared tunnel..."

# Use a temporary file to capture tunnel output for URL extraction
TUNNEL_LOG=$(mktemp /tmp/cloudflared-log-XXXXXX)

cloudflared tunnel --url "http://localhost:$PORT" 2>"$TUNNEL_LOG" &
TUNNEL_PID=$!

# Wait for the tunnel URL to appear in the log
echo "[start.sh] Waiting for tunnel URL..."
TUNNEL_URL=""
for i in $(seq 1 30); do
  if TUNNEL_URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -1); then
    if [[ -n "$TUNNEL_URL" ]]; then
      break
    fi
  fi
  sleep 1
done

if [[ -n "$TUNNEL_URL" ]]; then
  echo ""
  echo "========================================"
  echo "  EzLander Live Preview"
  echo "========================================"
  echo "  Local:  http://localhost:$PORT"
  echo "  Tunnel: $TUNNEL_URL"
  echo "========================================"
  echo ""
else
  echo "[start.sh] WARNING: Could not detect tunnel URL. Check cloudflared output."
  echo "[start.sh] The server is still running at http://localhost:$PORT"
fi

# Clean up the temp log
rm -f "$TUNNEL_LOG" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 5. Wait for processes
# ---------------------------------------------------------------------------
echo "[start.sh] Press Ctrl+C to stop."
echo ""

# Wait for the server process (the main one)
wait "$SERVER_PID" 2>/dev/null || true
