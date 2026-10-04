#!/bin/bash
# Task D / E (primary) and Extension E (standby) - start or reload nginx.
#   ./scripts/start-edge.sh primary     (on EDGE_IP)
#   ./scripts/start-edge.sh standby     (on EDGE_STANDBY_IP)
# Running it again while nginx is up = graceful reload of the config.
source "$(dirname "$0")/common.sh"
need nginx "brew install nginx"

ROLE="${1:-}"
case "$ROLE" in
  primary) IP="$EDGE_IP" ;;
  standby) IP="$EDGE_STANDBY_IP" ;;
  *) die "usage: $0 primary|standby" ;;
esac
CONF="$BUILD_DIR/nginx/edge-$ROLE.conf"
[ -f "$CONF" ] || die "$CONF missing - run ./scripts/render.sh first"
[ -f "$CERT_DIR/server.crt" ] && [ -f "$CERT_DIR/server.key" ] ||
  die "No TLS certificate yet - run ./scripts/make-certs.sh (on the primary edge) and copy certs/ to the standby."
is_me "$IP" || warn "team.env says the $ROLE edge is $IP, which is not this Mac. Starting anyway."

mkdir -p "$RUN_DIR/nginx-tmp"
NGINX=(nginx -p "$RUN_DIR" -e "$RUN_DIR/logs/edge-$ROLE-error.log" -c "$CONF")
# No sudo: nginx listens on the wildcard address, which macOS lets any user
# bind even on ports 80/443.

"${NGINX[@]}" -t -q || die "nginx config test failed (see message above)"

PIDFILE="$RUN_DIR/nginx-$ROLE.pid"
if [ -f "$PIDFILE" ] && "${NGINX[@]}" -s reload 2>/dev/null; then
  ok "$ROLE edge reloaded with the current config"
else
  "${NGINX[@]}"
  ok "$ROLE edge started"
fi
info "HTTPS : ${APP_URL}   (TLS terminated here, HTTP/2 enabled)"
info "HTTP  : port $HTTP_PORT -> redirects to HTTPS"
info "Pool  : A=$BACKEND_A_IP:$BACKEND_A_PORT  B=$BACKEND_B_IP:$BACKEND_B_PORT  (round robin)"
info "Logs  : ./scripts/edge-logs.sh $ROLE      Stop: ./scripts/stop-edge.sh $ROLE"
