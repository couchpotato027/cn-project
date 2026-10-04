#!/bin/bash
# Extension B - throw away this Mac's cached DNS answers immediately
# (instead of waiting for the TTL to expire).
source "$(dirname "$0")/common.sh"
step "Flushing this Mac's DNS cache"
run sudo dscacheutil -flushcache
run sudo killall -HUP mDNSResponder
ok "DNS cache flushed"
