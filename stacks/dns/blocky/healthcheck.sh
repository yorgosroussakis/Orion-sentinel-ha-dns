#!/bin/bash
# Blocky DNS Gateway Health Check Script
# 
# Performs health checks for the DoH/DoT gateway:
# 1. Checks if Blocky API is responding
# 2. Optionally checks DoT port connectivity
#
# Exit codes:
#   0 - Healthy (API responding correctly)
#   1 - Unhealthy (API not responding or returned error)

set -e

# Configuration
API_HOST="127.0.0.1"
API_PORT="${BLOCKY_API_PORT:-4000}"
DOT_PORT="853"

# Check 1: Verify Blocky API is responding
# Uses the blocking status endpoint which returns JSON
if curl -sf "http://${API_HOST}:${API_PORT}/api/blocking/status" > /dev/null 2>&1; then
    # API is responding
    
    # Check 2: Verify DoT port is listening using nc
    if nc -z "${API_HOST}" "${DOT_PORT}" 2>/dev/null; then
        # Both API and DoT port are healthy
        exit 0
    else
        # API is up but DoT might still be initializing
        # Still consider healthy as long as API responds
        exit 0
    fi
else
    echo "HEALTHCHECK FAILED: Blocky API not responding on port ${API_PORT}"
    exit 1
fi
