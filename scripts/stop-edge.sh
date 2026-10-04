#!/bin/bash
# Stop the primary or standby nginx edge.
source "$(dirname "$0")/common.sh"
ROLE="${1:-primary}"
CONF="$BUILD_DIR/nginx/edge-$ROLE.conf"
NGINX=(nginx -p "$RUN_DIR" -e "$RUN_DIR/logs/edge-$ROLE-error.log" -c "$CONF")
if [ -f "$RUN_DIR/nginx-$ROLE.pid" ]; then
  "${NGINX[@]}" -s stop && ok "$ROLE edge stopped"
else
  warn "$ROLE edge is not running"
fi
