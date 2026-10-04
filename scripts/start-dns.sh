#!/bin/bash
# Task B / Extension A - run the private DNS server in the FOREGROUND.
#   ./scripts/start-dns.sh primary     (on the DNS_PRIMARY_IP laptop)
#   ./scripts/start-dns.sh backup      (on the DNS_BACKUP_IP laptop)
# Every query is printed live. Press Ctrl+C to stop it (= "DNS failure" demo).
source "$(dirname "$0")/common.sh"
need dnsmasq "brew install dnsmasq"

ROLE="${1:-}"
case "$ROLE" in
  primary) LISTEN_IP="$DNS_PRIMARY_IP" ;;
  backup)  LISTEN_IP="$DNS_BACKUP_IP" ;;
  *) die "usage: $0 primary|backup" ;;
esac
CONF="$BUILD_DIR/dns/dnsmasq-$ROLE.conf"
[ -f "$CONF" ] || die "$CONF missing - run ./scripts/render.sh first"
is_me "$LISTEN_IP" || die "team.env says the $ROLE DNS is $LISTEN_IP, but that is not this Mac ($(my_ips | grep -v '^127\.' | tr '\n' ' '))."

# dnsmasq checks the config before starting.
dnsmasq --test --conf-file="$CONF" 2>&1 | grep -v "syntax check OK" || true

step "Starting $ROLE DNS for *.${DOMAIN} on ${LISTEN_IP}:${DNS_PORT}  (TTL ${DNS_TTL}s)"
info "Records (from ${RECORDS_FILE#$ROOT/}):"
grep -v '^#' "$RECORDS_FILE" | sed 's/^/      /'
info "Ctrl+C stops the DNS server."
echo

# On macOS dnsmasq binds each address separately, and binding a SPECIFIC
# address on port 53 requires root -> sudo (asks for your Mac password).
# After binding, dnsmasq drops from root to YOUR user, so it can still re-read
# the records file (in your home folder) when ./scripts/dns-point-app.sh
# sends it SIGHUP.
SUDO=""; [ "$DNS_PORT" -lt 1024 ] && SUDO="sudo"
exec $SUDO "$(command -v dnsmasq)" --keep-in-foreground --conf-file="$CONF" --log-facility=- \
     --pid-file="$RUN_DIR/dnsmasq-$ROLE.pid" --user="$(id -un)" --group="$(id -gn)"
