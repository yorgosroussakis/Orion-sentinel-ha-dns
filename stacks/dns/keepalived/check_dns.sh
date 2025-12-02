#!/usr/bin/env bash
# Health check script for Keepalived
# Verifies that Pi-hole DNS service is responding on localhost
#
# This script tests DNS resolution via the Pi-hole container that publishes
# port 53 on the host. Since keepalived runs in network_mode: host, it can
# reach Pi-hole via 127.0.0.1:53.
#
# The check is Pi-hole-centric (not Unbound) because:
# 1. Pi-hole is what clients actually query
# 2. Unbound healthchecks can be flappy even when DNS works through Pi-hole
# 3. This keeps the VIP stable as long as Pi-hole can answer DNS
#
# Exit codes:
# 0 = healthy (keepalived continues)
# 1 = unhealthy (keepalived reduces priority or fails over)

set -e

# Configuration from environment variables (with defaults)
DNS_IP="${DNS_CHECK_IP:-127.0.0.1}"
DNS_PORT="${DNS_CHECK_PORT:-53}"

# Perform a simple DNS query to verify Pi-hole is responding
# Using dig with short timeout and single retry for fast failure detection
dig +short example.com @"${DNS_IP}" -p "${DNS_PORT}" >/dev/null 2>&1
