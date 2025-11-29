#!/bin/bash
# =============================================================================
# Production-Ready DNS Health Check Script for Keepalived
# 2-Pi DNS HA Architecture - SECONDARY Node
# =============================================================================
#
# This script verifies that the local DNS services (Pi-hole and Unbound) are
# operational. Keepalived uses this to decide whether to keep the VIP on this
# node or failover to the secondary.
#
# Exit codes:
#   0 = healthy (keepalived maintains or increases priority)
#   1 = unhealthy (keepalived reduces priority, potentially triggers failover)
#
# =============================================================================

set -euo pipefail

# Configuration
readonly TIMEOUT=${DNS_CHECK_TIMEOUT:-2}
readonly RETRIES=${DNS_CHECK_RETRIES:-3}
readonly TEST_DOMAIN=${TEST_DOMAIN:-google.com}
readonly LOG_TAG="keepalived-check-secondary"

# Node-specific configuration
readonly NODE_ROLE="secondary"
readonly PIHOLE_CONTAINER="pihole_secondary"
readonly UNBOUND_CONTAINER="unbound_secondary"
readonly LOCAL_DNS="127.0.0.1"

# Logging function
log() {
    local level=$1
    shift
    logger -t "${LOG_TAG}" -p "daemon.${level}" "$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level^^}] $*"
}

# Check if a Docker container is running and healthy
check_container() {
    local container=$1
    local status
    
    # Check if container exists and is running
    status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "not_found")
    
    if [[ "$status" != "running" ]]; then
        log "err" "Container $container is not running (status: $status)"
        return 1
    fi
    
    # Check container health if healthcheck is configured
    local health
    health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no_healthcheck{{end}}' "$container" 2>/dev/null || echo "unknown")
    
    if [[ "$health" == "unhealthy" ]]; then
        log "warning" "Container $container is unhealthy"
        return 1
    fi
    
    return 0
}

# Check DNS resolution
check_dns_resolution() {
    local dns_server=$1
    local port=${2:-53}
    local attempt=1
    
    while [[ $attempt -le $RETRIES ]]; do
        if dig "@${dns_server}" -p "$port" "${TEST_DOMAIN}" +short +time="${TIMEOUT}" +tries=1 &>/dev/null; then
            return 0
        fi
        log "warning" "DNS resolution attempt $attempt failed for ${dns_server}:${port}"
        attempt=$((attempt + 1))
        sleep 1
    done
    
    return 1
}

# Check Pi-hole API (optional, provides more detailed status)
check_pihole_api() {
    local api_url="http://localhost/admin/api.php?status"
    local response
    
    response=$(curl -s --connect-timeout 2 --max-time 5 "$api_url" 2>/dev/null || echo "")
    
    if [[ -z "$response" ]]; then
        log "warning" "Pi-hole API not responding"
        return 1
    fi
    
    # Check if Pi-hole is enabled
    if echo "$response" | grep -q '"status":"enabled"'; then
        return 0
    fi
    
    log "warning" "Pi-hole status is not 'enabled'"
    return 1
}

# Main health check logic
main() {
    local failures=0
    
    log "info" "Starting health check for ${NODE_ROLE} node..."
    
    # Check 1: Verify Pi-hole container is running
    if ! check_container "${PIHOLE_CONTAINER}"; then
        log "err" "FAILED: Pi-hole container check"
        failures=$((failures + 1))
    else
        log "info" "PASSED: Pi-hole container is running"
    fi
    
    # Check 2: Verify Unbound container is running
    if ! check_container "${UNBOUND_CONTAINER}"; then
        log "err" "FAILED: Unbound container check"
        failures=$((failures + 1))
    else
        log "info" "PASSED: Unbound container is running"
    fi
    
    # Check 3: Verify DNS resolution works via Pi-hole
    if ! check_dns_resolution "${LOCAL_DNS}" 53; then
        log "err" "FAILED: DNS resolution via Pi-hole"
        failures=$((failures + 1))
    else
        log "info" "PASSED: DNS resolution via Pi-hole"
    fi
    
    # Check 4: Verify Unbound is responding (optional, may fail if not directly accessible)
    # This check uses the Unbound port (5335) on localhost if accessible
    if docker exec "${UNBOUND_CONTAINER}" drill "@127.0.0.1" -p 5335 cloudflare.com +short &>/dev/null; then
        log "info" "PASSED: Unbound recursive resolution"
    else
        log "warning" "Unbound direct check skipped or failed (non-critical)"
    fi
    
    # Evaluate results
    if [[ $failures -gt 0 ]]; then
        log "err" "Health check FAILED with $failures failures"
        # Create failure marker for monitoring
        echo "$(date '+%Y-%m-%d %H:%M:%S'): FAILED ($failures failures)" >> /tmp/keepalived_health_status
        exit 1
    fi
    
    log "info" "Health check PASSED - all services operational"
    # Create success marker for monitoring
    echo "$(date '+%Y-%m-%d %H:%M:%S'): OK" > /tmp/keepalived_health_status
    exit 0
}

# Run the health check
main
