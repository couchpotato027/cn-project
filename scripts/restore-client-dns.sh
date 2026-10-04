#!/bin/bash
# Undo set-client-dns.sh: put back this Mac's original DNS settings.
source "$(dirname "$0")/common.sh"

SERVICE="$(default_service)"
BACKUP="$RUN_DIR/dns-before-$(echo "$SERVICE" | tr ' /' '__').txt"
if [ -f "$BACKUP" ] && ! grep -q "aren't any" "$BACKUP"; then
  SERVERS="$(tr '\n' ' ' < "$BACKUP")"
else
  SERVERS="Empty"   # = automatic (DNS from the router via DHCP)
fi
step "Restoring DNS of '$SERVICE' to: $SERVERS"
# shellcheck disable=SC2086
run sudo networksetup -setdnsservers "$SERVICE" $SERVERS
rm -f "$BACKUP"
"$(dirname "$0")/flush-dns.sh"
