#!/bin/bash
# Task A - verify basic IP reachability to every team machine.
# Run it on EVERY laptop so you prove reachability between every pair.
source "$(dirname "$0")/common.sh"

OUT_DIR="$EVIDENCE_DIR/taskA"; mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/ping-from-$(hostname -s).txt"

# Unique list of all role IPs (+ optional LAPTOP3/4 when 4 members).
IPS="$(printf '%s\n' "${LAPTOP1_IP:-}" "${LAPTOP2_IP:-}" "${LAPTOP3_IP:-}" "${LAPTOP4_IP:-}" \
        "$DNS_PRIMARY_IP" "$DNS_BACKUP_IP" "$EDGE_IP" "$EDGE_STANDBY_IP" "$BACKEND_A_IP" "$BACKEND_B_IP" |
       awk 'NF && !seen[$0]++')"

status=0
{
  echo "Ping test from $(hostname -s) ($(date '+%Y-%m-%d %H:%M'))"
  for ip in $IPS; do
    if is_me "$ip"; then echo "-- $ip is THIS machine (skipped)"; continue; fi
    echo "-- ping $ip"
    if ping -c 3 -t 5 "$ip"; then echo "RESULT $ip: reachable"; else echo "RESULT $ip: UNREACHABLE"; status=1; fi
  done
} | tee "$OUT"
echo
info "Saved to ${OUT#$ROOT/}"
grep -q UNREACHABLE "$OUT" && warn "Some machines are unreachable - see docs/01-RUNBOOK.md 'Troubleshooting'." || ok "All team machines reachable"
