#!/bin/bash
# Follow the edge access log: one line per request showing the client socket,
# TLS version, HTTP version and WHICH backend (upstream) served it.
source "$(dirname "$0")/common.sh"
ROLE="${1:-primary}"
LOG="$RUN_DIR/logs/edge-$ROLE-access.log"
touch "$LOG"
step "Following ${LOG#$ROOT/} (Ctrl+C to stop)"
tail -n 20 -f "$LOG" "$RUN_DIR/logs/edge-$ROLE-error.log"
