#!/bin/bash
# Deployment script with optional VPN stack support
# Users can choose to deploy DNS stack with or without VPN

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  RPi HA DNS Stack - Deployment Script     ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check if .env exists
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${RED}❌ .env file not found!${NC}"
    echo "Please create .env from .env.example first"
    exit 1
fi

# Function to deploy a stack
deploy_stack() {
    local stack_name=$1
    local compose_file=$2
    
    echo -e "${BLUE}Deploying ${stack_name}...${NC}"
    if [ -f "$compose_file" ]; then
        docker compose -f "$compose_file" up -d
        echo -e "${GREEN}✓ ${stack_name} deployed${NC}"
    else
        echo -e "${YELLOW}⚠ ${stack_name} compose file not found: ${compose_file}${NC}"
    fi
}

# Core stacks (always deployed)
echo -e "${YELLOW}📦 Deploying Core Stacks${NC}"
echo ""

deploy_stack "DNS Stack" "$PROJECT_ROOT/stacks/dns/docker-compose.yml"
deploy_stack "Observability Stack" "$PROJECT_ROOT/stacks/observability/docker-compose.yml"
deploy_stack "AI Watchdog" "$PROJECT_ROOT/stacks/ai-watchdog/docker-compose.yml"

echo ""

# Optional stacks
echo -e "${YELLOW}📦 Optional Stacks${NC}"
echo ""

# Check if VPN should be deployed
if [ -f "$PROJECT_ROOT/stacks/vpn/docker-compose.yml" ]; then
    # Check if VPN is configured
    source "$PROJECT_ROOT/.env" 2>/dev/null || true
    
    if [ -n "${DEPLOY_VPN:-}" ] && [ "${DEPLOY_VPN}" = "true" ]; then
        echo -e "${BLUE}VPN stack deployment enabled${NC}"
        deploy_stack "VPN Stack" "$PROJECT_ROOT/stacks/vpn/docker-compose.yml"
    else
        echo -e "${CYAN}ℹ VPN stack deployment disabled${NC}"
        echo -e "${CYAN}  To enable: Set DEPLOY_VPN=true in .env and run: bash stacks/vpn/deploy-vpn.sh${NC}"
    fi
else
    echo -e "${CYAN}ℹ VPN stack not available${NC}"
fi

echo ""

# Show deployment status
echo -e "${YELLOW}📊 Deployment Status${NC}"
echo ""
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "pihole|unbound|wireguard|nginx-proxy" || docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      Deployment Complete! 🎉               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Show access URLs
echo -e "${YELLOW}📍 Service Access URLs:${NC}"
echo ""
echo -e "DNS Services:"
echo -e "  • Pi-hole Primary:   http://192.168.8.251/admin"
echo -e "  • Pi-hole Secondary: http://192.168.8.252/admin"
echo ""
echo -e "Monitoring:"
echo -e "  • Grafana:     http://192.168.8.250:3000"
echo -e "  • Prometheus:  http://192.168.8.250:9090"
echo ""

# Show VPN URLs if deployed
if [ -n "${DEPLOY_VPN:-}" ] && [ "${DEPLOY_VPN}" = "true" ]; then
    echo -e "VPN & Remote Access:"
    echo -e "  • WireGuard-UI:         http://192.168.8.250:5000"
    echo -e "  • Nginx Proxy Manager:  http://192.168.8.250:81"
    echo ""
fi

echo -e "${CYAN}💡 Tip: To add VPN later, run: bash stacks/vpn/deploy-vpn.sh${NC}"
echo ""
