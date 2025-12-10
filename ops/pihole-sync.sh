#!/usr/bin/env bash
# =============================================================================
# Pi-hole Sync Script - Sync configuration from Primary to Secondary
# =============================================================================
# Syncs Pi-hole configuration (blocklists, whitelist, blacklist, settings)
# from the primary node to the secondary node.
#
# Usage:
#   ./ops/pihole-sync.sh              # Sync from primary to secondary
#   ./ops/pihole-sync.sh --dry-run    # Show what would be synced
#
# Requirements:
#   - SSH key-based authentication between nodes
#   - Run on PRIMARY node only
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

# Load environment
# shellcheck source=/dev/null
if [[ -f "${REPO_DIR}/.env" ]]; then
    source "${REPO_DIR}/.env"
fi

# Defaults
PRIMARY_IP="${PRIMARY_IP:-192.168.8.249}"
SECONDARY_IP="${PEER_IP:-192.168.8.243}"
SSH_USER="${SSH_USER:-pi}"
SSH_KEY="${SSH_KEY:-}"
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# SSH options
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
if [[ -n "${SSH_KEY}" ]]; then
    SSH_OPTS="${SSH_OPTS} -i ${SSH_KEY}"
fi

# =============================================================================
# Functions
# =============================================================================

check_connectivity() {
    log_info "Checking connectivity to secondary node (${SECONDARY_IP})..."
    # shellcheck disable=SC2086
    if ! ssh ${SSH_OPTS} "${SSH_USER}@${SECONDARY_IP}" "echo ok" &>/dev/null; then
        log_error "Cannot connect to secondary node. Check SSH key authentication."
        exit 1
    fi
    log_info "Secondary node is reachable."
}

sync_pihole_config() {
    local container="pihole_unbound"
    local files_to_sync=(
        "/etc/pihole/adlists.list"
        "/etc/pihole/custom.list"
        "/etc/pihole/whitelist.txt"
        "/etc/pihole/blacklist.txt"
        "/etc/pihole/regex.list"
        "/etc/pihole/pihole-FTL.conf"
    )

    log_info "Syncing Pi-hole configuration to secondary node..."

    for file in "${files_to_sync[@]}"; do
        local filename
        filename=$(basename "$file")
        local temp_file="/tmp/pihole-sync-${filename}"

        # Extract file from primary container
        if docker exec "${container}" test -f "$file" 2>/dev/null; then
            log_info "  Syncing: ${filename}"
            
            if [[ "${DRY_RUN}" == "true" ]]; then
                log_info "    [DRY-RUN] Would sync ${file}"
                continue
            fi

            # Copy from container to temp
            docker cp "${container}:${file}" "${temp_file}" 2>/dev/null || continue

            # Copy to secondary node
            # shellcheck disable=SC2086
            scp ${SSH_OPTS} "${temp_file}" "${SSH_USER}@${SECONDARY_IP}:/tmp/${filename}" 2>/dev/null

            # Copy into secondary container (variables expand on client intentionally)
            # shellcheck disable=SC2086,SC2029
            ssh ${SSH_OPTS} "${SSH_USER}@${SECONDARY_IP}" \
                "docker cp /tmp/${filename} ${container}:${file} && rm /tmp/${filename}" 2>/dev/null

            rm -f "${temp_file}"
        fi
    done
}

sync_gravity_db() {
    local container="pihole_unbound"
    local gravity_db="/etc/pihole/gravity.db"

    log_info "Syncing gravity database..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "  [DRY-RUN] Would sync gravity.db"
        return
    fi

    # Export gravity from primary
    docker exec "${container}" test -f "${gravity_db}" || return

    local temp_file="/tmp/pihole-sync-gravity.db"
    docker cp "${container}:${gravity_db}" "${temp_file}"

    # Copy to secondary
    # shellcheck disable=SC2086
    scp ${SSH_OPTS} "${temp_file}" "${SSH_USER}@${SECONDARY_IP}:/tmp/gravity.db"

    # Import on secondary (variables expand on client intentionally)
    # shellcheck disable=SC2086,SC2029
    ssh ${SSH_OPTS} "${SSH_USER}@${SECONDARY_IP}" \
        "docker cp /tmp/gravity.db ${container}:${gravity_db} && rm /tmp/gravity.db"

    rm -f "${temp_file}"
    log_info "  Gravity database synced."
}

restart_secondary_pihole() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would restart Pi-hole on secondary"
        return
    fi

    log_info "Restarting Pi-hole on secondary node..."
    # shellcheck disable=SC2086
    ssh ${SSH_OPTS} "${SSH_USER}@${SECONDARY_IP}" \
        "docker exec pihole_unbound pihole restartdns" 2>/dev/null || true
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo "========================================"
    echo "Pi-hole Sync: Primary → Secondary"
    echo "========================================"
    echo "Primary:   ${PRIMARY_IP}"
    echo "Secondary: ${SECONDARY_IP}"
    echo "Dry Run:   ${DRY_RUN}"
    echo "========================================"

    check_connectivity
    sync_pihole_config
    sync_gravity_db
    restart_secondary_pihole

    log_info "Sync complete!"
}

main "$@"
