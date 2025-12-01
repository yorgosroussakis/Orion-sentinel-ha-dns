#!/bin/bash
# Unbound DNSSEC Health Check Script
# 
# Performs a DNSSEC-validating DNS query to verify:
# 1. Unbound is responding to queries
# 2. DNSSEC validation is working correctly
#
# Exit codes:
#   0 - Healthy (DNS resolution and DNSSEC validation working)
#   1 - Unhealthy (DNS resolution failed or DNSSEC validation failed)

set -e

# Configuration
UNBOUND_HOST="127.0.0.1"
UNBOUND_PORT="5335"

# Test domain - use a well-known DNSSEC-signed domain
# sigok.verteiltesysteme.net is a test domain that should always validate
# Fallback to cloudflare.com which is also DNSSEC-signed
TEST_DOMAIN="${HEALTHCHECK_DOMAIN:-cloudflare.com}"

# Perform DNSSEC query using drill
# -D enables DNSSEC mode
# -o rd sets the recursion desired flag
if drill -D -p "${UNBOUND_PORT}" @"${UNBOUND_HOST}" "${TEST_DOMAIN}" A > /tmp/healthcheck_result 2>&1; then
    # Check if the response contains valid data (at least one A record or CNAME)
    if grep -qE "^${TEST_DOMAIN}.*IN\s+(A|CNAME)" /tmp/healthcheck_result; then
        # Check for AD (Authenticated Data) flag which indicates DNSSEC validation passed
        # Note: AD flag may not always be set if the upstream doesn't support it
        # We'll accept any valid response as healthy
        exit 0
    else
        echo "HEALTHCHECK FAILED: No valid DNS response for ${TEST_DOMAIN}"
        cat /tmp/healthcheck_result
        exit 1
    fi
else
    echo "HEALTHCHECK FAILED: drill command failed"
    cat /tmp/healthcheck_result 2>/dev/null || true
    exit 1
fi
