#!/bin/bash
# Extension C rollback - remove our pf rules and restore the original state.
source "$(dirname "$0")/common.sh"
ANCHOR="com.apple/cnproject"

step "Flushing anchor $ANCHOR"
run sudo pfctl -a "$ANCHOR" -F all 2>/dev/null || true
if [ -f "$RUN_DIR/pf/token" ] && [ -n "$(cat "$RUN_DIR/pf/token")" ]; then
  run sudo pfctl -X "$(cat "$RUN_DIR/pf/token")" || true
  rm -f "$RUN_DIR/pf/token"
fi
info "Rules left in our anchor (should be empty):"
sudo pfctl -a "$ANCHOR" -s rules 2>/dev/null | sed 's/^/      /'
ok "Isolation OFF - original firewall configuration restored"
