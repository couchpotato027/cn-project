#!/bin/bash
# Task G - capture packets to evidence/pcap/<name>.pcap for Wireshark.
#   ./scripts/capture.sh full-flow          start capturing, then make requests
#                                           in another terminal, Ctrl+C to stop.
#   ./scripts/capture.sh full-flow --auto   capture while the script itself does
#                                           flush DNS -> dig -> curl (TLS 1.2 + 1.3)
# Captures DNS (53), HTTPS, HTTP and both backend ports on the active interface.
source "$(dirname "$0")/common.sh"
NAME="${1:-capture}"; MODE="${2:-}"
IFACE="${IFACE:-$(default_iface)}"
OUT_DIR="$EVIDENCE_DIR/pcap"; mkdir -p "$OUT_DIR"
PCAP="$OUT_DIR/$NAME-$(date +%H%M%S).pcap"
FILTER="port $DNS_PORT or port $HTTPS_PORT or port $HTTP_PORT or port $BACKEND_A_PORT or port $BACKEND_B_PORT"

step "Capturing on $IFACE -> ${PCAP#$ROOT/}"
info "filter: $FILTER"
if is_me "$DNS_PRIMARY_IP"; then
  # Traffic from a Mac to its own IP goes over loopback (lo0), never over $IFACE.
  warn "This Mac IS the DNS server, so its own DNS queries won't appear on $IFACE."
  info "For DNS evidence, run this capture on another team laptop (a client)."
fi

if [ "$MODE" != "--auto" ]; then
  info "Make your requests in another terminal now. Ctrl+C here to stop."
  run sudo tcpdump -i "$IFACE" -n -s 0 -w "$PCAP" "$FILTER" || true
  sudo chown "$(id -u)" "$PCAP" 2>/dev/null || true
  ok "Saved ${PCAP#$ROOT/}  -> open with: open -a Wireshark '$PCAP'"
  exit 0
fi

sudo -v   # ask for the password up front
sudo tcpdump -i "$IFACE" -n -s 0 -U -w "$PCAP" "$FILTER" 2>/dev/null &
TCPDUMP=$!
sleep 1
"$(dirname "$0")/flush-dns.sh" >/dev/null

step "DNS: query the team DNS server"
run dig "$APP_HOST" @"$DNS_PRIMARY_IP" -p "$DNS_PORT" +noall +answer
step "HTTPS with TLS 1.2 (Certificate message travels in CLEAR -> visible in Wireshark)"
# shellcheck disable=SC2046
run curl -sS -o /dev/null -w 'HTTP %{http_code}  local %{local_ip}:%{local_port} -> %{remote_ip}:%{remote_port}\n' \
  $(curl_ca_opts) --tlsv1.2 --tls-max 1.2 --http1.1 "$APP_URL/api/status"
step "HTTPS with TLS 1.3 + HTTP/2 (Certificate is ENCRYPTED in TLS 1.3)"
# shellcheck disable=SC2046
run curl -sS -o /dev/null -w 'HTTP %{http_code} (HTTP/%{http_version})  local %{local_ip}:%{local_port} -> %{remote_ip}:%{remote_port}\n' \
  $(curl_ca_opts) "$APP_URL/api/status"
sleep 1
sudo kill -INT "$TCPDUMP"; wait "$TCPDUMP" 2>/dev/null || true
sudo chown "$(id -u)" "$PCAP" 2>/dev/null || true
ok "Saved ${PCAP#$ROOT/}  ($(tcpdump -r "$PCAP" 2>/dev/null | wc -l | xargs) packets)"
info "Open it:  open -a Wireshark '$PCAP'"
info "Useful Wireshark display filters:  dns  |  tcp.flags.syn==1  |  tls.handshake  |  tls.handshake.type==11"
[ "$HTTPS_PORT" = "443" ] || info "HTTPS is on $HTTPS_PORT: right-click a packet -> Decode As -> TLS so Wireshark dissects it."
