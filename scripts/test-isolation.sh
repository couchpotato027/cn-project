#!/bin/bash
# Extension C - prove the backends are reachable ONLY through the edge.
# Run on a CLIENT laptop (not the edge).
source "$(dirname "$0")/common.sh"

step "1) Direct to the backends (should FAIL when isolation is on)"
for target in "$BACKEND_A_IP:$BACKEND_A_PORT" "$BACKEND_B_IP:$BACKEND_B_PORT"; do
  if curl -s -o /dev/null --connect-timeout 3 "http://$target/api/status"; then
    warn "http://$target reachable directly  (isolation is OFF, or this Mac is the edge)"
  else
    ok "http://$target blocked  (TCP connect timed out - SYN dropped by pf)"
  fi
done

step "2) Through the edge (should still WORK)"
# shellcheck disable=SC2046
if curl -s -o /dev/null -w '%{http_code}' $(curl_ca_opts) "$APP_URL/api/status" | grep -q 200; then
  ok "$APP_URL/api/status -> 200 via the edge"
else
  fail "$APP_URL/api/status failed - is the edge running?"
fi
