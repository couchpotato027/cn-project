#!/bin/bash
# Task B / Extension A - make THIS Mac use the team DNS servers.
#   ./scripts/set-client-dns.sh              primary + backup  (normal setup)
#   ./scripts/set-client-dns.sh --primary-only
#   ./scripts/set-client-dns.sh --wrong      bogus resolver    (failure demo #1)
# Same effect as System Settings -> Network -> Wi-Fi -> Details -> DNS.
# Your original DNS settings are saved and restored by ./scripts/restore-client-dns.sh
source "$(dirname "$0")/common.sh"

SERVICE="$(default_service)"
[ -n "$SERVICE" ] || die "Could not find the active network service"

case "${1:-}" in
  "")             SERVERS="$DNS_PRIMARY_IP $DNS_BACKUP_IP" ;;
  --primary-only) SERVERS="$DNS_PRIMARY_IP" ;;
  # TEST-NET-1 (RFC 5737): guaranteed to exist nowhere -> lookups time out.
  --wrong)        SERVERS="192.0.2.53" ;;
  *) die "usage: $0 [--primary-only|--wrong]" ;;
esac

BACKUP="$RUN_DIR/dns-before-$(echo "$SERVICE" | tr ' /' '__').txt"
if [ ! -f "$BACKUP" ]; then
  networksetup -getdnsservers "$SERVICE" > "$BACKUP"
  info "Saved original DNS settings of '$SERVICE' to ${BACKUP#$ROOT/}"
fi

step "Setting DNS of '$SERVICE' to: $SERVERS"
# shellcheck disable=SC2086
run sudo networksetup -setdnsservers "$SERVICE" $SERVERS
"$(dirname "$0")/flush-dns.sh"
info "Now in use:"; scutil --dns | awk '/resolver #1/{f=1} f&&/nameserver/{print "      "$0} /resolver #2/{exit}'
