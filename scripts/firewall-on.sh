#!/bin/bash
# Extension C - only the edge may reach the backend ports.
# Run on every BACKEND machine. Needs your Mac password (pf is a system firewall).
#
# Safety: our rules go into a SEPARATE pf anchor ("com.apple/cnproject"),
# which macOS's default /etc/pf.conf already includes. /etc/pf.conf itself is
# never edited, and ./scripts/firewall-off.sh removes everything again.
source "$(dirname "$0")/common.sh"
RULES="$BUILD_DIR/pf/cnproject.rules"
[ -f "$RULES" ] || die "Run ./scripts/render.sh first"
ANCHOR="com.apple/cnproject"

step "Saving a rollback copy of the current firewall state"
mkdir -p "$RUN_DIR/pf"
sudo pfctl -s info  > "$RUN_DIR/pf/before-info.txt"  2>/dev/null || true
sudo pfctl -s rules > "$RUN_DIR/pf/before-rules.txt" 2>/dev/null || true
cp /etc/pf.conf "$RUN_DIR/pf/etc-pf.conf.backup"
info "Saved to ${RUN_DIR#$ROOT/}/pf/  (pf was $(awk '/Status:/{print $2; exit}' "$RUN_DIR/pf/before-info.txt"))"

step "Loading rules into anchor $ANCHOR"
sed 's/^/      /' "$RULES"
run sudo pfctl -a "$ANCHOR" -f "$RULES"
# -E enables pf and returns a reference token; firewall-off.sh releases it, so
# pf goes back to exactly the on/off state it had before.
TOKEN="$(sudo pfctl -E 2>&1 | awk '/Token/{print $NF}')"
echo "$TOKEN" > "$RUN_DIR/pf/token"

step "Active rules in our anchor"
run sudo pfctl -a "$ANCHOR" -s rules
ok "Isolation ON: only $EDGE_IP may connect to ports $BACKEND_A_PORT/$BACKEND_B_PORT"
info "Prove it from a CLIENT laptop:  ./scripts/test-isolation.sh"
info "Roll back:                      ./scripts/firewall-off.sh"
