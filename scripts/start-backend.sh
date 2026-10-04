#!/bin/bash
# Task C - run Backend A or B in the FOREGROUND (Ctrl+C = "backend down" demo).
#   ./scripts/start-backend.sh A
#   ./scripts/start-backend.sh B
source "$(dirname "$0")/common.sh"

case "${1:-}" in
  A|a) NAME=A; PORT="$BACKEND_A_PORT"; IP="$BACKEND_A_IP" ;;
  B|b) NAME=B; PORT="$BACKEND_B_PORT"; IP="$BACKEND_B_IP" ;;
  *) die "usage: $0 A|B" ;;
esac
is_me "$IP" || warn "team.env says Backend $NAME lives on $IP, which is not this Mac. Starting anyway."

step "Backend $NAME -> http://$IP:$PORT   (listening on all interfaces)"
info "Each request is logged with the TCP peer (should be the EDGE) and X-Forwarded-For (the real client)."
exec python3 "$ROOT/backend/server.py" --name "$NAME" --port "$PORT"
