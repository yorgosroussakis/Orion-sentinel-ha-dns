#!/usr/bin/env bash
set -euo pipefail

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
message="${timestamp} [FAULT] VIP=${VIP_ADDRESS:-} IFACE=${NETWORK_INTERFACE:-} NODE_ROLE=${NODE_ROLE:-} ROUTER_ID=${ROUTER_ID:-} ARGS=$*"

echo "${message}"
{ echo "${message}" >> /var/log/keepalived-notify.log; } || true
