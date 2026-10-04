#!/bin/bash
# Task A - record this Mac's network identity.
# Saves a copy to evidence/taskA/<hostname>.txt for the evidence folder.
source "$(dirname "$0")/common.sh"

IFACE="$(default_iface)"
[ -n "$IFACE" ] || die "No default route - are you connected to the Wi-Fi/LAN?"

IP="$(ipconfig getifaddr "$IFACE" || true)"
MASK="$(ipconfig getoption "$IFACE" subnet_mask || true)"
GATEWAY="$(route -n get default | awk '/gateway:/{print $2}')"
MAC="$(ifconfig "$IFACE" | awk '/ether /{print $2}')"
SERVICE="$(default_service)"
SSID="$(ipconfig getsummary "$IFACE" 2>/dev/null | awk -F' : ' '/ SSID :/{print $2; exit}')"
# Count the 1-bits of the mask -> CIDR prefix length.
PREFIX="$(python3 -c "import ipaddress,sys; print(ipaddress.IPv4Network('0.0.0.0/'+sys.argv[1]).prefixlen)" "$MASK" 2>/dev/null || echo '?')"
NETWORK="$(python3 -c "import ipaddress,sys; print(ipaddress.IPv4Interface(sys.argv[1]+'/'+sys.argv[2]).network)" "$IP" "$MASK" 2>/dev/null || echo '?')"
DNS_SERVERS="$(scutil --dns | awk '/nameserver\[[0-9]+\]/{print $3}' | awk '!seen[$0]++' | tr '\n' ' ')"

OUT_DIR="$EVIDENCE_DIR/taskA"; mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/$(hostname -s).txt"
{
  echo "Task A - network identity of $(hostname -s)   ($(date '+%Y-%m-%d %H:%M'))"
  printf '%-22s %s\n' "Network service"     "$SERVICE"
  printf '%-22s %s\n' "Wi-Fi SSID"          "${SSID:-n/a}"
  printf '%-22s %s\n' "Active interface"    "$IFACE"
  printf '%-22s %s\n' "Private IPv4"        "$IP"
  printf '%-22s %s  (/%s)\n' "Subnet mask"  "$MASK" "$PREFIX"
  printf '%-22s %s\n' "Network"             "$NETWORK"
  printf '%-22s %s\n' "Default gateway"     "$GATEWAY"
  printf '%-22s %s\n' "MAC address"         "$MAC"
  printf '%-22s %s\n' "DNS resolvers in use" "$DNS_SERVERS"
} | tee "$OUT"
echo
info "Saved to ${OUT#$ROOT/}"
info "Note: macOS 'Private Wi-Fi Address' may show a randomised MAC - that is expected."
