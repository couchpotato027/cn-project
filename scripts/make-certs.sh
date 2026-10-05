#!/bin/bash
# Task E - create our own Certificate Authority (CA) and a server certificate
# for app.<team>.test / api.<team>.test signed by it.
#   certs/ca.crt      -> install on EVERY client Mac (./scripts/trust-ca.sh)
#   certs/ca.key      -> the CA's private key. Keep it secret, never commit it.
#   certs/server.crt  -> the certificate nginx presents
#   certs/server.key  -> nginx's private key (copy to the standby edge too)
# Re-running keeps the existing CA (so clients stay trusted) and only re-issues
# the server certificate. Use --force-new-ca to start from scratch.
source "$(dirname "$0")/common.sh"
# macOS's own /usr/bin/openssl is LibreSSL, which lacks some options used here
# (-addext, -ext). Prefer Homebrew's OpenSSL 3.
OPENSSL="$(brew --prefix openssl@3 2>/dev/null)/bin/openssl"
[ -x "$OPENSSL" ] || OPENSSL="$(command -v openssl)"
"$OPENSSL" version | grep -qE '^OpenSSL [3-9]' || die "Need OpenSSL 3 or newer: brew install openssl@3"
openssl() { "$OPENSSL" "$@"; }
mkdir -p "$CERT_DIR"; cd "$CERT_DIR"

if [ "${1:-}" = "--force-new-ca" ]; then rm -f ca.key ca.crt ca.srl; fi

if [ ! -f ca.key ] || [ ! -f ca.crt ]; then
  step "Creating the team Certificate Authority"
  openssl req -x509 -new -nodes -newkey rsa:2048 -sha256 -days 825 \
    -keyout ca.key -out ca.crt \
    -subj "/O=CN Project ${TEAM_ID}/CN=CN Project ${TEAM_ID} Local CA" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -addext "subjectKeyIdentifier=hash"
  chmod 600 ca.key
  ok "CA created: certs/ca.crt"
else
  info "Re-using existing CA certs/ca.crt"
fi

step "Issuing server certificate for $APP_HOST and $API_HOST"
cat > server.ext <<EOF
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = DNS:${APP_HOST}, DNS:${API_HOST}
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF
# macOS rejects server certificates valid for more than 825 days and
# certificates without the names in subjectAltName - both handled here.
openssl req -new -nodes -newkey rsa:2048 -keyout server.key -out server.csr \
  -subj "/O=CN Project ${TEAM_ID}/CN=${APP_HOST}"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 397 -sha256 -extfile server.ext 2>/dev/null
chmod 600 server.key
rm -f server.csr

openssl verify -CAfile ca.crt server.crt
info "Subject : $(openssl x509 -in server.crt -noout -subject)"
info "Issuer  : $(openssl x509 -in server.crt -noout -issuer)"
info "Names   : $(openssl x509 -in server.crt -noout -ext subjectAltName | tail -1 | xargs)"
info "Valid   : $(openssl x509 -in server.crt -noout -enddate)"
echo
info "Next: on EVERY client Mac run ./scripts/trust-ca.sh (needs certs/ca.crt copied there)."
info "      Copy certs/server.crt + certs/server.key to the standby edge for Extension E."
