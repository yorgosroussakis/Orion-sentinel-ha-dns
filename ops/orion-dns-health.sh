#!/usr/bin/env bash
# =============================================================================
# Orion DNS Health Check & Auto-Healing Script
# =============================================================================
# Host-level health check that monitors DNS services and restarts containers
# when repeated failures are detected.
#
# Usage:
#   ./ops/orion-dns-health.sh              # Run health check
#   ./ops/orion-dns-health.sh --verbose    # Verbose output
#
# Install as systemd timer for auto-healing (see systemd/orion-dns-health.timer)
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
STATE_DIR="${REPO_DIR}/run"
LOG_DIR="${REPO_DIR}/logs"

# Create directories
mkdir -p "${STATE_DIR}" "${LOG_DIR}"

# State files
FAIL_STATE_FILE="${STATE_DIR}/health_fail_count"
LAST_RESTART_FILE="${STATE_DIR}/last_restart"

# Thresholds
MAX_CONSECUTIVE_FAILURES="${MAX_CONSECUTIVE_FAILURES:-3}"
RESTART_COOLDOWN_SECONDS="${RESTART_COOLDOWN_SECONDS:-300}"  # 5 minutes

# Test domains
TEST_DOMAINS=("google.com" "cloudflare.com" "github.com")

# Verbose mode
VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    local msg
    msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "${LOG_DIR}/health.log"
    [[ "${VERBOSE}" == "true" ]] && echo -e "$msg"
}

log_info() { log "${GREEN}[INFO]${NC} $*"; }
log_warn() { log "${YELLOW}[WARN]${NC} $*"; }
log_error() { log "${RED}[ERROR]${NC} $*"; }

# =============================================================================
# Health Checks
# =============================================================================

check_container_running() {
    local container="$1"
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        return 0
    fi
    return 1
}

check_container_healthy() {
    local container="$1"
    local health
    health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no_healthcheck{{end}}' "$container" 2>/dev/null || echo "unknown")
    
    if [[ "$health" == "healthy" || "$health" == "no_healthcheck" ]]; then
        return 0
    fi
    return 1
}

check_dns_resolution() {
    local domain="${1:-google.com}"
    if dig @127.0.0.1 -p 53 "$domain" +short +time=3 +tries=1 &>/dev/null; then
        return 0
    fi
    return 1
}

run_health_checks() {
    local failures=0

    # Check 1: pihole_unbound container running
    if ! check_container_running "pihole_unbound"; then
        log_error "pihole_unbound container not running"
        ((failures++))
    else
        log_info "pihole_unbound container: running"
    fi

    # Check 2: pihole_unbound container healthy
    if ! check_container_healthy "pihole_unbound"; then
        log_warn "pihole_unbound container: unhealthy"
        ((failures++))
    else
        log_info "pihole_unbound container: healthy"
    fi

    # Check 3: DNS resolution
    local dns_ok=false
    for domain in "${TEST_DOMAINS[@]}"; do
        if check_dns_resolution "$domain"; then
            dns_ok=true
            log_info "DNS resolution: ${domain} OK"
            break
        fi
    done
    if [[ "$dns_ok" == "false" ]]; then
        log_error "DNS resolution: FAILED for all test domains"
        ((failures++))
    fi

    # Check 4: keepalived (if HA mode)
    if docker ps --format '{{.Names}}' | grep -q "^keepalived$"; then
        if ! check_container_running "keepalived"; then
            log_error "keepalived container not running"
            ((failures++))
        else
            log_info "keepalived container: running"
        fi
    fi

    return $failures
}

# =============================================================================
# State Management
# =============================================================================

get_fail_count() {
    if [[ -f "${FAIL_STATE_FILE}" ]]; then
        cat "${FAIL_STATE_FILE}"
    else
        echo "0"
    fi
}

set_fail_count() {
    echo "$1" > "${FAIL_STATE_FILE}"
}

get_last_restart() {
    if [[ -f "${LAST_RESTART_FILE}" ]]; then
        cat "${LAST_RESTART_FILE}"
    else
        echo "0"
    fi
}

set_last_restart() {
    date +%s > "${LAST_RESTART_FILE}"
}

can_restart() {
    local last_restart
    last_restart=$(get_last_restart)
    local now
    now=$(date +%s)
    local elapsed=$((now - last_restart))

    if [[ $elapsed -ge ${RESTART_COOLDOWN_SECONDS} ]]; then
        return 0
    fi
    log_warn "Restart cooldown active (${elapsed}s / ${RESTART_COOLDOWN_SECONDS}s)"
    return 1
}

# =============================================================================
# Recovery Actions
# =============================================================================

restart_services() {
    log_warn "Attempting service restart..."

    cd "${REPO_DIR}"

    # Determine which profile is active
    local profile=""
    if docker ps --format '{{.Names}}' | grep -q "keepalived"; then
        # Check if primary or backup based on container hostname
        local hostname
        hostname=$(docker inspect --format='{{.Config.Hostname}}' keepalived 2>/dev/null || echo "")
        if [[ "$hostname" == *"primary"* ]]; then
            profile="two-node-ha-primary"
        else
            profile="two-node-ha-backup"
        fi
    else
        profile="single-node"
    fi

    log_info "Restarting with profile: ${profile}"

    # Stop and start
    docker compose --profile "${profile}" down
    sleep 5
    docker compose --profile "${profile}" up -d

    set_last_restart
    set_fail_count 0

    log_info "Services restarted successfully"
}

# =============================================================================
# Main
# =============================================================================

main() {
    log_info "Starting health check..."

    local fail_count
    fail_count=$(get_fail_count)

    if run_health_checks; then
        # All checks passed
        log_info "All health checks passed"
        set_fail_count 0
        exit 0
    else
        # Some checks failed
        fail_count=$((fail_count + 1))
        set_fail_count "$fail_count"

        log_warn "Health check failed (${fail_count}/${MAX_CONSECUTIVE_FAILURES})"

        if [[ $fail_count -ge ${MAX_CONSECUTIVE_FAILURES} ]]; then
            if can_restart; then
                restart_services
            fi
        fi

        exit 1
    fi
}

main "$@"
