#!/bin/bash
# Task D / Extension D - send N requests through the edge and show which
# backend answered each one (X-Backend header).
#   ./scripts/test-lb.sh            10 requests
#   ./scripts/test-lb.sh 20 0.5     20 requests, 0.5 s apart
source "$(dirname "$0")/common.sh"
N="${1:-10}"; DELAY="${2:-0.3}"

step "$N requests to $APP_URL/api/status"
a=0; b=0; err=0
for i in $(seq 1 "$N"); do
  # shellcheck disable=SC2046
  HDRS="$(curl -sS -o /dev/null -D - --max-time 5 $(curl_ca_opts) "$APP_URL/api/status" 2>&1 || true)"
  CODE="$(echo "$HDRS" | awk 'toupper($1) ~ /^HTTP/{print $2; exit}')"
  BACKEND="$(echo "$HDRS" | awk -F': ' 'tolower($1)=="x-backend"{gsub(/\r/,"",$2); print $2}')"
  EDGE="$(echo "$HDRS" | awk -F': ' 'tolower($1)=="x-edge"{gsub(/\r/,"",$2); print $2}')"
  printf "    #%-3s HTTP %-4s X-Backend: %-3s X-Edge: %s\n" "$i" "${CODE:-ERR}" "${BACKEND:--}" "${EDGE:--}"
  case "$BACKEND" in A) a=$((a+1));; B) b=$((b+1));; *) err=$((err+1));; esac
  sleep "$DELAY"
done
echo
info "Backend A: $a   Backend B: $b   failed: $err"
if [ "$a" -gt 0 ] && [ "$b" -gt 0 ]; then ok "Load is shared across both backends"
elif [ "$err" = 0 ]; then warn "Only one backend answered (expected while the other is down - Extension D)"
else fail "Some requests failed"; fi
