#!/bin/bash
# Phase 1 gate check - run from a CLIENT laptop. Exits non-zero if anything fails.
# "Phase 1 is complete when a client resolves app.teamX.test, connects over
#  HTTPS, and receives responses from both backends through the load balancer."
source "$(dirname "$0")/common.sh"
# A checker must keep going when something is down and report it, not exit
# at the first failed curl (common.sh turns on "exit on error").
set +e
FAILS=0
bad() { fail "$*"; FAILS=$((FAILS+1)); }

step "Reachability (ping)"
for ip in $(printf '%s\n' "$DNS_PRIMARY_IP" "$EDGE_IP" "$BACKEND_A_IP" "$BACKEND_B_IP" | awk '!s[$0]++'); do
  if is_me "$ip" || ping -c 1 -t 2 "$ip" >/dev/null 2>&1; then ok "$ip reachable"; else bad "$ip not reachable"; fi
done

step "DNS (Task B)"
ANS="$(dig +short +time=2 +tries=1 "$APP_HOST" @"$DNS_PRIMARY_IP" -p "$DNS_PORT" | head -1)"
[ "$ANS" = "$EDGE_IP" ] && ok "team DNS: $APP_HOST -> $ANS" || bad "team DNS answered '${ANS:-nothing}', expected $EDGE_IP"
OS="$(dscacheutil -q host -a name "$APP_HOST" | awk '/ip_address:/{print $2; exit}')"
[ "$OS" = "$EDGE_IP" ] && ok "this Mac resolves $APP_HOST -> $OS (System DNS points at the team DNS)" ||
  bad "this Mac resolves $APP_HOST to '${OS:-nothing}' - run ./scripts/set-client-dns.sh"

step "Backends (Task C) - direct, bypassing the edge"
for t in "A $BACKEND_A_IP:$BACKEND_A_PORT" "B $BACKEND_B_IP:$BACKEND_B_PORT"; do
  set -- $t
  H="$(curl -s -D - -o /dev/null --connect-timeout 3 "http://$2/api/status" | awk -F': ' 'tolower($1)=="x-backend"{gsub(/\r/,"",$2);print $2}')"
  if [ "$H" = "$1" ]; then ok "backend $1 at $2 answers with X-Backend: $H"
  else warn "backend $1 at $2 not reachable directly: is it running? (expected ONLY if Extension C firewall is on)"; fi
done

step "HTTPS through the edge (Task D/E) - by NAME, certificate validated"
# shellcheck disable=SC2046
R="$(curl -sS -o /dev/null -w '%{http_code} %{http_version} %{ssl_verify_result} %{remote_ip}' $(curl_ca_opts) "$APP_URL/api/status" 2>&1 || true)"
set -- $R
if [ "${1:-}" = "200" ] && [ "${3:-}" = "0" ]; then
  ok "$APP_URL -> HTTP $1, HTTP/$2, certificate verified, connected to $4"
else
  bad "$APP_URL failed: $R"
fi

step "Load balancing (Task D)"
SEEN=""
for i in 1 2 3 4 5 6; do
  # shellcheck disable=SC2046
  SEEN="$SEEN$(curl -s -D - -o /dev/null $(curl_ca_opts) "$APP_URL/api/status" | awk -F': ' 'tolower($1)=="x-backend"{gsub(/\r/,"",$2);print $2}')"
done
info "sequence of backends: $SEEN"
case "$SEEN" in *A*B*|*B*A*) ok "both backends served requests" ;; *) bad "only saw: $SEEN" ;; esac

step "Caching (Task F)"
# shellcheck disable=SC2046
ETAG="$(curl -s -D - -o /dev/null $(curl_ca_opts) "$APP_URL/api/data" | awk -F': ' 'tolower($1)=="etag"{gsub(/\r/,"",$2);print $2}')"
# shellcheck disable=SC2046
C="$(curl -s -o /dev/null -w '%{http_code}' $(curl_ca_opts) -H "If-None-Match: $ETAG" "$APP_URL/api/data")"
[ "$C" = "304" ] && ok "conditional request -> 304 Not Modified" || bad "conditional request returned $C"

echo
if [ "$FAILS" = 0 ]; then ok "${C_B}PHASE 1 GATE PASSED${C_0}"; else fail "$FAILS check(s) failed"; exit 1; fi
