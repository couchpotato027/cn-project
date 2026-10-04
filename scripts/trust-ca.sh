#!/bin/bash
# Task E - add the team CA to THIS Mac's System keychain as a trusted root,
# so Safari/Chrome/curl accept https://app.<team>.test without warnings.
# You will be asked for your Mac password (it changes system trust settings).
# Undo with: ./scripts/trust-ca.sh --remove
source "$(dirname "$0")/common.sh"
CA="$CERT_DIR/ca.crt"
[ -f "$CA" ] || die "certs/ca.crt not found - copy it from the laptop that ran make-certs.sh"

if [ "${1:-}" = "--remove" ]; then
  step "Removing the team CA from the System keychain"
  run sudo security remove-trusted-cert -d "$CA" || true
  run sudo security delete-certificate -c "CN Project ${TEAM_ID} Local CA" /Library/Keychains/System.keychain || true
  exit 0
fi

step "Trusting $(openssl x509 -in "$CA" -noout -subject)"
run sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CA"
ok "CA trusted. Restart your browser so it picks up the change."
info "Check in Keychain Access -> System -> Certificates: 'CN Project ${TEAM_ID} Local CA'."
