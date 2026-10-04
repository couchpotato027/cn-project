#!/bin/bash
# Print which project roles THIS laptop plays, according to team.env,
# and the exact commands to start each one.
source "$(dirname "$0")/common.sh"

step "This laptop: $(hostname)   IPs: $(my_ips | grep -v '^127\.' | tr '\n' ' ')"
found=0
role() { # role <ip> <description> <start command>
  if is_me "$1"; then found=1; printf "    %-34s -> %s\n" "$2" "$3"; fi
}
role "$DNS_PRIMARY_IP"  "Primary DNS   (Task B)"          "./scripts/start-dns.sh primary"
role "$DNS_BACKUP_IP"   "Backup DNS    (Extension A)"     "./scripts/start-dns.sh backup"
role "$EDGE_IP"         "Edge nginx    (Task D/E)"        "./scripts/start-edge.sh primary"
role "$EDGE_STANDBY_IP" "Standby edge  (Extension E)"     "./scripts/start-edge.sh standby"
role "$BACKEND_A_IP"    "Backend A     (Task C)"          "./scripts/start-backend.sh A"
role "$BACKEND_B_IP"    "Backend B     (Task C)"          "./scripts/start-backend.sh B"
info "Every laptop can be a test client: ./scripts/set-client-dns.sh, then ./scripts/verify.sh"
if [ "$found" = 0 ]; then
  warn "None of the IPs in team.env belong to this Mac."
  info "Run ./scripts/network-info.sh, put the real IPs in team.env, then ./scripts/render.sh"
fi
