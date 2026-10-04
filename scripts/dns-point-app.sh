#!/bin/bash
# Extension B / E - change where app.<team>.test and api.<team>.test point, LIVE.
#   ./scripts/dns-point-app.sh standby       -> EDGE_STANDBY_IP  (Ext E cutover)
#   ./scripts/dns-point-app.sh edge          -> EDGE_IP          (move back)
#   ./scripts/dns-point-app.sh 192.168.1.99  -> any IP           (Ext B / wrong-IP failure demo)
# Run it on EVERY machine running dnsmasq (primary AND backup) so both answer the same.
source "$(dirname "$0")/common.sh"

case "${1:-}" in
  edge)    NEW_IP="$EDGE_IP" ;;
  standby) NEW_IP="$EDGE_STANDBY_IP" ;;
  "")      die "usage: $0 edge|standby|<ip>" ;;
  *)       NEW_IP="$1" ;;
esac
[[ "$NEW_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || die "'$NEW_IP' is not an IPv4 address"
[ -f "$RECORDS_FILE" ] || die "Run ./scripts/render.sh first"

OLD_IP="$(awk -v h="$APP_HOST" '$2==h{print $1}' "$RECORDS_FILE")"
# Rewrite only the app/api lines; keep everything else.
awk -v ip="$NEW_IP" -v a="$APP_HOST" -v b="$API_HOST" \
    '($2==a || $2==b){print ip "\t" $2; next} {print}' "$RECORDS_FILE" > "$RECORDS_FILE.tmp"
mv "$RECORDS_FILE.tmp" "$RECORDS_FILE"

step "$APP_HOST: $OLD_IP  ->  $NEW_IP   (records file updated)"

# SIGHUP = dnsmasq re-reads the records file and clears ITS OWN cache.
# Clients that already cached the old answer keep it until their TTL runs out.
reloaded=0
for pidfile in "$RUN_DIR"/dnsmasq-*.pid; do
  [ -f "$pidfile" ] || continue
  pid="$(cat "$pidfile")"
  if kill -0 "$pid" 2>/dev/null || sudo kill -0 "$pid" 2>/dev/null; then
    kill -HUP "$pid" 2>/dev/null || sudo kill -HUP "$pid"
    ok "dnsmasq (pid $pid) reloaded"
    reloaded=1
  fi
done
[ "$reloaded" = 1 ] || warn "No running dnsmasq on this Mac - the change applies next time it starts."
info "Clients may keep the OLD answer for up to ${DNS_TTL}s (TTL). Watch it with: ./scripts/watch-dns.sh"
