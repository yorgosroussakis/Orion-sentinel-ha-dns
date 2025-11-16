#!/bin/bash
# Multi-Node HA DNS Stack Deployment Script
# This script helps deploy the DNS stack across two Raspberry Pi nodes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DNS_STACK_DIR="${PROJECT_ROOT}/stacks/dns"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_warning "Running as root. This is okay but not required."
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    log_success "Docker is installed"
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    log_success "Docker Compose is installed"
    
    # Check if .env file exists
    if [ ! -f "${PROJECT_ROOT}/.env" ]; then
        log_error ".env file not found. Please create it from .env.multinode.example"
        exit 1
    fi
    log_success ".env file found"
    
    # Source environment variables
    source "${PROJECT_ROOT}/.env"
    
    # Check required environment variables
    if [ -z "$NODE_ROLE" ]; then
        log_error "NODE_ROLE not set in .env file"
        exit 1
    fi
    
    if [ -z "$VIP_ADDRESS" ]; then
        log_error "VIP_ADDRESS not set in .env file"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

detect_node_role() {
    source "${PROJECT_ROOT}/.env"
    
    log_info "Node role: ${NODE_ROLE}"
    log_info "Node IP: ${NODE_IP}"
    log_info "Peer IP: ${PEER_IP}"
    log_info "VIP: ${VIP_ADDRESS}"
    
    if [ "$NODE_ROLE" != "primary" ] && [ "$NODE_ROLE" != "secondary" ]; then
        log_error "Invalid NODE_ROLE. Must be 'primary' or 'secondary'"
        exit 1
    fi
}

setup_keepalived_config() {
    log_info "Setting up Keepalived configuration..."
    
    cd "${DNS_STACK_DIR}/keepalived"
    
    # Copy the appropriate keepalived config
    if [ "$NODE_ROLE" == "primary" ]; then
        if [ -f "keepalived-multinode-primary.conf" ]; then
            cp keepalived-multinode-primary.conf keepalived.conf
            log_success "Using primary node Keepalived configuration"
        else
            log_error "keepalived-multinode-primary.conf not found"
            exit 1
        fi
    else
        if [ -f "keepalived-multinode-secondary.conf" ]; then
            cp keepalived-multinode-secondary.conf keepalived.conf
            log_success "Using secondary node Keepalived configuration"
        else
            log_error "keepalived-multinode-secondary.conf not found"
            exit 1
        fi
    fi
    
    # Make scripts executable
    chmod +x check_dns.sh notify_master.sh notify_backup.sh notify_fault.sh 2>/dev/null || true
    
    log_success "Keepalived configuration ready"
}

create_docker_network() {
    log_info "Creating Docker macvlan network..."
    
    # Check if network already exists
    if docker network ls | grep -q dns_net; then
        log_warning "Network 'dns_net' already exists. Skipping creation."
        return 0
    fi
    
    # Create macvlan network
    docker network create \
        -d macvlan \
        --subnet=${SUBNET} \
        --gateway=${GATEWAY} \
        -o parent=${NETWORK_INTERFACE} \
        dns_net
    
    log_success "Docker network created"
}

deploy_services() {
    log_info "Deploying DNS services for ${NODE_ROLE} node..."
    
    cd "${DNS_STACK_DIR}"
    
    # Determine which services to deploy based on node role
    if [ "$NODE_ROLE" == "primary" ]; then
        log_info "Deploying primary services..."
        docker compose up -d pihole_primary unbound_primary keepalived
    else
        log_info "Deploying secondary services..."
        docker compose up -d pihole_secondary unbound_secondary keepalived
    fi
    
    log_success "Services deployed"
}

wait_for_services() {
    log_info "Waiting for services to be ready..."
    sleep 30
    log_success "Services should be ready"
}

check_service_health() {
    log_info "Checking service health..."
    
    cd "${DNS_STACK_DIR}"
    
    # Check container status
    if [ "$NODE_ROLE" == "primary" ]; then
        docker compose ps pihole_primary unbound_primary keepalived
    else
        docker compose ps pihole_secondary unbound_secondary keepalived
    fi
    
    log_info "Checking Keepalived logs..."
    docker logs keepalived --tail 20
}

check_vip_assignment() {
    log_info "Checking VIP assignment..."
    
    if ip addr show ${NETWORK_INTERFACE} | grep -q "${VIP_ADDRESS}"; then
        log_success "VIP ${VIP_ADDRESS} is assigned to this node!"
        log_info "This node is MASTER"
    else
        log_info "VIP ${VIP_ADDRESS} is NOT assigned to this node"
        log_info "This node is BACKUP (or waiting for failover)"
    fi
}

test_dns_resolution() {
    log_info "Testing DNS resolution..."
    
    # Determine which local IP to test
    if [ "$NODE_ROLE" == "primary" ]; then
        LOCAL_DNS="${PRIMARY_DNS_IP}"
    else
        LOCAL_DNS="${SECONDARY_DNS_IP}"
    fi
    
    log_info "Testing DNS query to ${LOCAL_DNS}..."
    
    # Test from within the container
    if [ "$NODE_ROLE" == "primary" ]; then
        if docker exec pihole_primary dig @127.0.0.1 google.com +short > /dev/null 2>&1; then
            log_success "DNS resolution working"
        else
            log_warning "DNS resolution test failed (this is normal if testing from the host due to macvlan)"
        fi
    else
        if docker exec pihole_secondary dig @127.0.0.1 google.com +short > /dev/null 2>&1; then
            log_success "DNS resolution working"
        else
            log_warning "DNS resolution test failed (this is normal if testing from the host due to macvlan)"
        fi
    fi
}

print_next_steps() {
    echo ""
    log_success "=== Deployment Complete ==="
    echo ""
    log_info "Next steps:"
    echo ""
    
    if [ "$NODE_ROLE" == "primary" ]; then
        echo "1. Deploy the secondary node (if not already done)"
        echo "2. Set up Gravity Sync for Pi-hole synchronization:"
        echo "   curl -sSL https://raw.githubusercontent.com/vmstan/gravity-sync/master/gs-install.sh | bash"
        echo "   sudo gravity-sync config"
        echo "   sudo gravity-sync push"
        echo "   sudo gravity-sync auto"
        echo ""
        echo "3. Access Pi-hole admin interface:"
        echo "   http://${PRIMARY_DNS_IP}/admin"
    else
        echo "1. Verify the primary node is running"
        echo "2. Wait for Gravity Sync from primary (if configured)"
        echo ""
        echo "3. Access Pi-hole admin interface:"
        echo "   http://${SECONDARY_DNS_IP}/admin"
    fi
    
    echo ""
    echo "4. Test from another device on your network:"
    echo "   dig google.com @${VIP_ADDRESS}"
    echo "   ping ${VIP_ADDRESS}"
    echo ""
    echo "5. Configure your router to use DNS servers:"
    echo "   Primary DNS: ${VIP_ADDRESS}"
    echo "   Secondary DNS: ${PRIMARY_DNS_IP} or ${SECONDARY_DNS_IP}"
    echo ""
    
    if [ "$NODE_ROLE" == "primary" ]; then
        echo "6. Test failover by stopping keepalived:"
        echo "   docker stop keepalived"
        echo "   (VIP should move to secondary node within 10 seconds)"
        echo "   docker start keepalived"
    fi
    
    echo ""
    log_warning "Note: Due to macvlan networking, you cannot access container IPs directly from the Pi itself."
    log_warning "Always test from another device on your network."
    echo ""
}

# Main script execution
main() {
    log_info "=== Multi-Node HA DNS Stack Deployment ==="
    echo ""
    
    check_prerequisites
    detect_node_role
    setup_keepalived_config
    create_docker_network
    deploy_services
    wait_for_services
    check_service_health
    check_vip_assignment
    test_dns_resolution
    print_next_steps
}

# Run main function
main "$@"
