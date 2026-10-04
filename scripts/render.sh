#!/bin/bash
# Generate every config file in build/ from team.env + templates/.
# Run this after ANY change to team.env (on every laptop).
source "$(dirname "$0")/common.sh"

step "Rendering configs for ${DOMAIN}"

# Basic sanity check of the IPs in team.env.
for var in DNS_PRIMARY_IP DNS_BACKUP_IP EDGE_IP EDGE_STANDBY_IP BACKEND_A_IP BACKEND_B_IP; do
  val="${!var}"
  [[ "$val" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || die "$var='$val' is not an IPv4 address (check team.env)"
done

mkdir -p "$BUILD_DIR/dns" "$BUILD_DIR/nginx" "$BUILD_DIR/pf" "$RUN_DIR/nginx-tmp"

# render <template> <output> [KEY=VALUE ...]
# Replaces {{KEY}} placeholders. Uses {{ }} so nginx's own $variables are untouched.
render() {
  local tmpl="$1" out="$2"; shift 2
  env "$@" python3 - "$tmpl" "$out" <<'PY'
import os, re, sys
tmpl, out = sys.argv[1], sys.argv[2]
text = open(tmpl).read()
def sub(m):
    key = m.group(1)
    if key not in os.environ:
        sys.exit(f"render: no value for {{{{{key}}}}} in {tmpl}")
    return os.environ[key]
open(out, "w").write(re.sub(r"\{\{([A-Z0-9_]+)\}\}", sub, text))
PY
  info "wrote ${out#$ROOT/}"
}

COMMON=(
  DOMAIN="$DOMAIN" RUN_DIR="$RUN_DIR" CERT_DIR="$CERT_DIR" RECORDS_FILE="$RECORDS_FILE"
  DNS_PRIMARY_IP="$DNS_PRIMARY_IP" DNS_BACKUP_IP="$DNS_BACKUP_IP"
  EDGE_IP="$EDGE_IP" EDGE_STANDBY_IP="$EDGE_STANDBY_IP"
  BACKEND_A_IP="$BACKEND_A_IP" BACKEND_B_IP="$BACKEND_B_IP"
  BACKEND_A_PORT="$BACKEND_A_PORT" BACKEND_B_PORT="$BACKEND_B_PORT"
  HTTP_PORT="$HTTP_PORT" HTTPS_PORT="$HTTPS_PORT" HTTPS_PORT_SUFFIX="$HTTPS_PORT_SUFFIX"
  DNS_PORT="$DNS_PORT" DNS_TTL="$DNS_TTL" UPSTREAM_DNS="$UPSTREAM_DNS"
)

# DNS (Task B + Extension A)
render "$ROOT/templates/records.hosts.tmpl"  "$RECORDS_FILE"                     "${COMMON[@]}"
render "$ROOT/templates/dnsmasq.conf.tmpl"   "$BUILD_DIR/dns/dnsmasq-primary.conf" "${COMMON[@]}" DNS_ROLE=primary LISTEN_IP="$DNS_PRIMARY_IP"
render "$ROOT/templates/dnsmasq.conf.tmpl"   "$BUILD_DIR/dns/dnsmasq-backup.conf"  "${COMMON[@]}" DNS_ROLE=backup  LISTEN_IP="$DNS_BACKUP_IP"

# Edge (Task D/E + Extension D/E)
render "$ROOT/templates/nginx.conf.tmpl"     "$BUILD_DIR/nginx/edge-primary.conf"  "${COMMON[@]}" EDGE_ROLE=primary EDGE_NAME="primary ($EDGE_IP)"
render "$ROOT/templates/nginx.conf.tmpl"     "$BUILD_DIR/nginx/edge-standby.conf"  "${COMMON[@]}" EDGE_ROLE=standby EDGE_NAME="standby ($EDGE_STANDBY_IP)"

# Firewall (Extension C)
render "$ROOT/templates/pf.rules.tmpl"       "$BUILD_DIR/pf/cnproject.rules"       "${COMMON[@]}"

echo
info "Done. Roles of THIS laptop:  ./scripts/whoami.sh"
