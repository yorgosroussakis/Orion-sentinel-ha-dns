#!/bin/bash
# =============================================================================
# DNS Health Check Script for Keepalived
# =============================================================================
# Checks if Pi-hole/Unbound is responding to DNS queries
# Exit code 0 = healthy, non-zero = unhealthy
# Used by keepalived vrrp_script to adjust priority
# =============================================================================

# Test DNS resolution against local Pi-hole
# Using dig with short timeout to quickly detect failures
if dig @127.0.0.1 -p 53 google.com +short +time=2 +tries=1 >/dev/null 2>&1; then
    exit 0
fi

# Fallback: try a different domain
if dig @127.0.0.1 -p 53 cloudflare.com +short +time=2 +tries=1 >/dev/null 2>&1; then
    exit 0
fi

# DNS is not responding
exit 1
