#!/usr/bin/env bash
# Pi-hole Initial Configuration Script
# Sets up blocklists and whitelist for both Pi-hole instances

set -euo pipefail

PIHOLE_PRIMARY="pihole_primary"
PIHOLE_SECONDARY="pihole_secondary"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

configure_pihole() {
    local container="$1"
    log "Configuring $container..."
    
    # Add Hagezi Pro++ blocklist
    log "Adding Hagezi Pro++ blocklist..."
    docker exec "$container" bash -c "sqlite3 /etc/pihole/gravity.db \"INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.plus.txt', 1, 'Hagezi Pro++');\""
    
    # Add OISD Big blocklist
    log "Adding OISD Big blocklist..."
    docker exec "$container" bash -c "sqlite3 /etc/pihole/gravity.db \"INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('https://big.oisd.nl/domainswild', 1, 'OISD Big');\""
    
    # Whitelist disneyplus.com
    log "Whitelisting disneyplus.com..."
    docker exec "$container" pihole -w disneyplus.com
    docker exec "$container" pihole -w disney-plus.net
    docker exec "$container" pihole -w disneystreaming.com
    docker exec "$container" pihole -w bamgrid.com
    docker exec "$container" pihole -w dssott.com
    
    # Update gravity
    log "Updating gravity database..."
    docker exec "$container" pihole updateGravity
    
    log "$container configured successfully!"
}

# Wait for containers to be ready
wait_for_container() {
    local container="$1"
    local max_wait=60
    local count=0
    
    log "Waiting for $container to be ready..."
    while ! docker exec "$container" pihole status &>/dev/null; do
        sleep 2
        count=$((count + 2))
        if [ $count -ge $max_wait ]; then
            log "ERROR: $container failed to become ready"
            return 1
        fi
    done
    log "$container is ready!"
}

main() {
    log "Starting Pi-hole configuration..."
    
    # Check if containers are running
    if ! docker ps --format '{{.Names}}' | grep -q "$PIHOLE_PRIMARY"; then
        log "ERROR: $PIHOLE_PRIMARY container not running"
        exit 1
    fi
    
    if ! docker ps --format '{{.Names}}' | grep -q "$PIHOLE_SECONDARY"; then
        log "ERROR: $PIHOLE_SECONDARY container not running"
        exit 1
    fi
    
    # Wait for containers to be ready
    wait_for_container "$PIHOLE_PRIMARY"
    wait_for_container "$PIHOLE_SECONDARY"
    
    # Configure both Pi-hole instances
    configure_pihole "$PIHOLE_PRIMARY"
    configure_pihole "$PIHOLE_SECONDARY"
    
    log "Pi-hole configuration completed!"
    log ""
    log "Blocklists added:"
    log "  - Hagezi Pro++ (https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.plus.txt)"
    log "  - OISD Big (https://big.oisd.nl/domainswild)"
    log ""
    log "Whitelisted domains:"
    log "  - disneyplus.com"
    log "  - disney-plus.net"
    log "  - disneystreaming.com"
    log "  - bamgrid.com"
    log "  - dssott.com"
    log ""
    log "To keep configurations in sync, run: bash pihole-sync.sh"
}

main "$@"
