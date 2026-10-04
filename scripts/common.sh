#!/bin/bash
# Shared helpers - sourced by every script in this folder. Not run directly.
# Written for the bash 3.2 that ships with macOS.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEAM_ENV="${TEAM_ENV:-$ROOT/team.env}"
[ -f "$TEAM_ENV" ] || { echo "Missing $TEAM_ENV" >&2; exit 1; }
# shellcheck source=/dev/null
source "$TEAM_ENV"

BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
RUN_DIR="${RUN_DIR:-$ROOT/run}"
CERT_DIR="${CERT_DIR:-$ROOT/certs}"
EVIDENCE_DIR="$ROOT/evidence"
RECORDS_FILE="$BUILD_DIR/dns/records.hosts"
mkdir -p "$RUN_DIR/logs"

APP_HOST="app.${DOMAIN}"
API_HOST="api.${DOMAIN}"
if [ "$HTTPS_PORT" = "443" ]; then HTTPS_PORT_SUFFIX=""; else HTTPS_PORT_SUFFIX=":$HTTPS_PORT"; fi
APP_URL="https://${APP_HOST}${HTTPS_PORT_SUFFIX}"

# Homebrew puts dnsmasq in sbin, which is not always on PATH.
export PATH="$PATH:/opt/homebrew/sbin:/usr/local/sbin"

if [ -t 1 ]; then
  C_B=$'\033[1m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_C=$'\033[36m'; C_0=$'\033[0m'
else
  C_B=""; C_G=""; C_Y=""; C_R=""; C_C=""; C_0=""
fi
step() { echo; echo "${C_B}${C_C}==> $*${C_0}"; }
info() { echo "    $*"; }
ok()   { echo "${C_G}  [PASS]${C_0} $*"; }
warn() { echo "${C_Y}  [WARN]${C_0} $*"; }
fail() { echo "${C_R}  [FAIL]${C_0} $*"; }
die()  { echo "${C_R}ERROR:${C_0} $*" >&2; exit 1; }
run()  { echo "${C_B}\$ $*${C_0}"; "$@"; }   # echo a command, then run it

# All IPv4 addresses on this Mac (one per line).
my_ips() { ifconfig | awk '/inet /{print $2}'; }

# True if the given IP belongs to this Mac.
is_me() { my_ips | grep -qx "$1"; }

# Interface + network service name of the default route (e.g. en0 / Wi-Fi).
default_iface() { route -n get default 2>/dev/null | awk '/interface:/{print $2}'; }
default_service() {
  local dev; dev="$(default_iface)"
  networksetup -listnetworkserviceorder |
    awk -v dev="$dev" '/^\([0-9*]+\)/{sub(/^\([0-9*]+\) /,""); name=$0}
                       $0 ~ "Device: " dev "\\)" {print name; exit}'
}

# curl options so the CA we created is trusted even if the system keychain
# is not consulted by curl. This is NOT -k: the certificate is still fully
# validated, we only tell curl which CA to trust.
curl_ca_opts() {
  if [ -f "$CERT_DIR/ca.crt" ]; then echo "--cacert $CERT_DIR/ca.crt"; fi
}

need() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found. Install it: $2"; }
