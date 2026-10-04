#!/bin/bash
# Extension B / E - watch name resolution change over time (TTL behaviour).
# Every 3 s prints:
#   - what the macOS resolver (with its cache, like a browser) returns
#   - what the DNS server itself answers right now, and the TTL it hands out
# Ctrl+C to stop.
source "$(dirname "$0")/common.sh"
need dig "it ships with macOS"
SERVER="${1:-$DNS_PRIMARY_IP}"

step "Watching $APP_HOST  (OS cache vs. server $SERVER). Ctrl+C to stop."
printf "    %-9s %-18s %-18s %s\n" "time" "OS resolver" "server answer" "server TTL"
while true; do
  OS_IP="$(dscacheutil -q host -a name "$APP_HOST" 2>/dev/null | awk '/ip_address:/{print $2; exit}')"
  ANSWER="$(dig +noall +answer +time=1 +tries=1 @"$SERVER" -p "$DNS_PORT" "$APP_HOST" A 2>/dev/null | awk '$4=="A"{print $5, $2; exit}')"
  printf "    %-9s %-18s %-18s %s\n" "$(date +%H:%M:%S)" "${OS_IP:-<none>}" "${ANSWER%% *}" "${ANSWER##* }"
  sleep 3
done
