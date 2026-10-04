#!/bin/bash
# Task B - verify name resolution from a client, three ways.
source "$(dirname "$0")/common.sh"
need dig "it ships with macOS"
OUT_DIR="$EVIDENCE_DIR/dns"; mkdir -p "$OUT_DIR"

{
step "1) Ask the PRIMARY team DNS server directly"
run dig "$APP_HOST" @"$DNS_PRIMARY_IP" -p "$DNS_PORT" +noall +answer +stats || true
step "2) Ask the BACKUP team DNS server directly"
run dig "$APP_HOST" @"$DNS_BACKUP_IP" -p "$DNS_PORT" +noall +answer +time=2 +tries=1 || true
step "3) Ask the way apps do (macOS resolver = System Settings DNS + cache)"
run dscacheutil -q host -a name "$APP_HOST" || true
step "4) nslookup (uses the first configured DNS server)"
run nslookup "$APP_HOST" || true
info "Expected answer: $APP_HOST -> $EDGE_IP (the edge, NOT a backend)."
info "The answer section line reads: name  TTL  IN  A  address"
} 2>&1 | tee "$OUT_DIR/dns-$(hostname -s)-$(date +%H%M%S).txt"
