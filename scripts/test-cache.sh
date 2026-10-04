#!/bin/bash
# Task F - HTTP caching: full response vs. conditional request (304).
source "$(dirname "$0")/common.sh"
URL="$APP_URL/api/data"
OUT_DIR="$EVIDENCE_DIR/caching"; mkdir -p "$OUT_DIR"

{
step "1) FULL request - no cache yet: server sends 200 + body + validators"
# shellcheck disable=SC2046
run curl -sS -D - -o /dev/null $(curl_ca_opts) "$URL"
# shellcheck disable=SC2046
ETAG="$(curl -sS -D - -o /dev/null $(curl_ca_opts) "$URL" | awk -F': ' 'tolower($1)=="etag"{gsub(/\r/,"",$2); print $2}')"
info "Cache-Control: max-age=60 -> for 60 s a cache may reuse this WITHOUT asking (fresh hit)."
info "ETag $ETAG -> afterwards, ask 'has it changed?' instead of downloading again."

step "2) CONDITIONAL request - If-None-Match: $ETAG"
# shellcheck disable=SC2046
run curl -sS -D - -o /dev/null $(curl_ca_opts) -H "If-None-Match: $ETAG" "$URL"
info "304 Not Modified = headers only, no body: 'your copy is still valid'."

step "3) Conditional request with a STALE ETag -> full 200 again"
# shellcheck disable=SC2046
run curl -sS -D - -o /dev/null $(curl_ca_opts) -H 'If-None-Match: "old-version"' "$URL"

step "4) Size comparison"
# shellcheck disable=SC2046
FULL="$(curl -sS -o /dev/null -w '%{http_code} %{size_download}' $(curl_ca_opts) "$URL")"
# shellcheck disable=SC2046
COND="$(curl -sS -o /dev/null -w '%{http_code} %{size_download}' $(curl_ca_opts) -H "If-None-Match: $ETAG" "$URL")"
info "full request        -> HTTP ${FULL% *}, body ${FULL#* } bytes"
info "conditional request -> HTTP ${COND% *}, body ${COND#* } bytes"
info "Fresh cache hit (no request at all) is shown in the BROWSER: DevTools -> Network,"
info "reload $URL within 60 s -> Size column says '(disk cache)' / '(memory cache)'."
} 2>&1 | tee "$OUT_DIR/caching-$(date +%H%M%S).txt"
