#!/usr/bin/env bash
# DNS Stack Deployment Script
# Ensures proper network setup and container deployment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DNS_STACK_DIR="$REPO_ROOT/stacks/dns"

# Load environment variables
if [[ -f "$REPO_ROOT/.env" ]]; then
    source "$REPO_ROOT/.env"
fi

NETWORK_NAME="dns_net"
NETWORK_INTERFACE="${NETWORK_INTERFACE:-eth0}"
SUBNET="${SUBNET:-192.168.8.0/24}"
GATEWAY="${GATEWAY:-192.168.8.1}"

log() { echo -e "\n[deploy-dns] $*"; }
err() { echo -e "\n[deploy-dns][ERROR] $*" >&2; }

# Function to check if network exists
network_exists() {
    docker network inspect "$1" >/dev/null 2>&1
}

# Function to create macvlan network
create_network() {
    log "Creating macvlan network '$NETWORK_NAME'"
    
    # Check if parent interface exists
    if ! ip link show "$NETWORK_INTERFACE" >/dev/null 2>&1; then
        err "Parent interface '$NETWORK_INTERFACE' does not exist!"
        exit 1
    fi
    
    docker network create \
        -d macvlan \
        --subnet="$SUBNET" \
        --gateway="$GATEWAY" \
        -o parent="$NETWORK_INTERFACE" \
        "$NETWORK_NAME" || {
            err "Failed to create macvlan network"
            exit 1
        }
    
    log "Network '$NETWORK_NAME' created successfully"
}

# Main deployment flow
main() {
    log "Starting DNS stack deployment"
    
    # Change to DNS stack directory
    cd "$DNS_STACK_DIR"
    
    # Stop existing containers
    log "Stopping existing containers..."
    docker compose down || true
    
    # Check/create network
    if network_exists "$NETWORK_NAME"; then
        log "Network '$NETWORK_NAME' already exists"
        
        # Verify it's macvlan
        driver=$(docker network inspect "$NETWORK_NAME" --format='{{.Driver}}')
        if [[ "$driver" != "macvlan" ]]; then
            log "WARNING: Network exists but is not macvlan (current: $driver)"
            read -p "Remove and recreate network? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log "Removing existing network..."
                docker network rm "$NETWORK_NAME" || true
                create_network
            fi
        fi
    else
        create_network
    fi
    
    # Build keepalived image
    log "Building keepalived image..."
    docker compose build keepalived
    
    # Start services
    log "Starting services..."
    docker compose up -d
    
    # Wait a moment for containers to initialize
    sleep 5
    
    # Show status
    log "Container status:"
    docker compose ps
    
    log "Deployment complete!"
    log ""
    log "To check logs:"
    log "  docker compose logs -f"
    log ""
    log "To test DNS (from another device on your network):"
    log "  dig google.com @192.168.8.255"
}

main "$@"
