#!/bin/bash
# VPN Stack Deployment Script
# Deploys WireGuard VPN and Nginx Proxy Manager for remote service access

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  WireGuard VPN Stack Deployment Script    ║${NC}"
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ Please do not run this script as root${NC}"
    exit 1
fi

# Check if .env file exists
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${RED}❌ .env file not found!${NC}"
    echo "Please create a .env file from .env.example first:"
    echo "  cp .env.example .env"
    echo "  nano .env"
    exit 1
fi

# Source environment variables
source "$PROJECT_ROOT/.env"

echo -e "${YELLOW}📋 Pre-deployment Checks${NC}"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo "Please install Docker first: https://docs.docker.com/engine/install/"
    exit 1
fi
echo -e "${GREEN}✓ Docker is installed${NC}"

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not available${NC}"
    echo "Please install Docker Compose"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose is available${NC}"

# Check required environment variables
REQUIRED_VARS=(
    "WG_SERVER_URL"
    "WGUI_PASSWORD"
    "WGUI_SESSION_SECRET"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ] || [ "${!var}" = "CHANGE_ME_REQUIRED" ] || [ "${!var}" = "auto" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    echo -e "${RED}❌ Missing or invalid required environment variables:${NC}"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "Please update these in your .env file:"
    echo "  WG_SERVER_URL: Your public IP or DDNS hostname (find it: curl ifconfig.me)"
    echo "  WGUI_PASSWORD: Generate with: openssl rand -base64 32"
    echo "  WGUI_SESSION_SECRET: Generate with: openssl rand -base64 32"
    exit 1
fi
echo -e "${GREEN}✓ Required environment variables are set${NC}"

# Get public IP for verification
PUBLIC_IP=$(curl -s ifconfig.me || echo "unknown")
echo ""
echo -e "${YELLOW}📡 Network Information${NC}"
echo "  Public IP: $PUBLIC_IP"
echo "  WG_SERVER_URL: ${WG_SERVER_URL}"
echo "  WG_SERVER_PORT: ${WG_SERVER_PORT:-51820}"
echo ""

# Warn if WG_SERVER_URL doesn't match public IP (unless using DDNS)
if [ "$PUBLIC_IP" != "unknown" ] && [ "$WG_SERVER_URL" != "$PUBLIC_IP" ]; then
    if [[ "$WG_SERVER_URL" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${YELLOW}⚠️  Warning: WG_SERVER_URL ($WG_SERVER_URL) doesn't match current public IP ($PUBLIC_IP)${NC}"
        echo "This may cause connection issues unless you're using DDNS"
        echo ""
    fi
fi

# Check if port forwarding is set up
echo -e "${YELLOW}📋 Port Forwarding Check${NC}"
echo ""
echo "⚠️  IMPORTANT: Ensure you have configured port forwarding on your router:"
echo "  External Port: ${WG_SERVER_PORT:-51820} UDP"
echo "  Internal IP: ${HOST_IP:-192.168.8.250}"
echo "  Internal Port: ${WG_SERVER_PORT:-51820}"
echo ""
read -p "Have you configured port forwarding? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Please configure port forwarding before continuing${NC}"
    echo "See: stacks/vpn/DEPLOYMENT_GUIDE.md for detailed instructions"
    exit 1
fi
echo -e "${GREEN}✓ Port forwarding confirmed${NC}"
echo ""

# Create necessary directories
echo -e "${YELLOW}📁 Creating directories...${NC}"
mkdir -p "$PROJECT_ROOT/stacks/vpn/wireguard/config"
mkdir -p "$PROJECT_ROOT/stacks/vpn/wireguard-ui/db"
mkdir -p "$PROJECT_ROOT/stacks/vpn/nginx-proxy-manager/data"
mkdir -p "$PROJECT_ROOT/stacks/vpn/nginx-proxy-manager/letsencrypt"
echo -e "${GREEN}✓ Directories created${NC}"
echo ""

# Display deployment plan
echo -e "${YELLOW}📦 Deployment Plan${NC}"
echo "The following services will be deployed:"
echo "  • WireGuard VPN Server (port ${WG_SERVER_PORT:-51820}/udp)"
echo "  • WireGuard-UI Management Interface (port 5000)"
echo "  • Nginx Proxy Manager (ports 80, 443, 81)"
echo ""
echo "After deployment, you can access:"
echo "  • WireGuard-UI: http://${HOST_IP:-192.168.8.250}:5000"
echo "  • Nginx Proxy Manager: http://${HOST_IP:-192.168.8.250}:81"
echo ""

read -p "Proceed with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""
echo -e "${YELLOW}🚀 Deploying VPN Stack...${NC}"
cd "$PROJECT_ROOT"

# Pull latest images
echo "Pulling Docker images..."
docker compose -f stacks/vpn/docker-compose.yml pull

# Start the stack
echo "Starting VPN stack..."
docker compose -f stacks/vpn/docker-compose.yml up -d

# Wait for services to be healthy
echo ""
echo -e "${YELLOW}⏳ Waiting for services to start...${NC}"
sleep 10

# Check service status
echo ""
echo -e "${YELLOW}📊 Service Status${NC}"
docker compose -f stacks/vpn/docker-compose.yml ps

# Get container status
WIREGUARD_STATUS=$(docker inspect -f '{{.State.Status}}' wireguard 2>/dev/null || echo "not found")
NPM_STATUS=$(docker inspect -f '{{.State.Status}}' nginx-proxy-manager 2>/dev/null || echo "not found")

echo ""
if [ "$WIREGUARD_STATUS" = "running" ] && [ "$NPM_STATUS" = "running" ]; then
    echo -e "${GREEN}✅ VPN Stack deployed successfully!${NC}"
else
    echo -e "${YELLOW}⚠️  Some services may not be running properly${NC}"
    echo "Check logs with: docker logs wireguard"
    echo "                 docker logs nginx-proxy-manager"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Deployment Complete! 🎉           ║${NC}"
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Access WireGuard-UI:"
echo "   URL: http://${HOST_IP:-192.168.8.250}:5000"
echo "   Username: ${WGUI_USERNAME:-admin}"
echo "   Password: (from your .env file)"
echo ""
echo "2. Create your first VPN client:"
echo "   - Click 'New Client' in WireGuard-UI"
echo "   - Scan the QR code with WireGuard mobile app"
echo "   - Or download the config file for desktop"
echo ""
echo "3. Configure Nginx Proxy Manager:"
echo "   URL: http://${HOST_IP:-192.168.8.250}:81"
echo "   Default email: admin@example.com"
echo "   Default password: changeme"
echo "   ⚠️  CHANGE THESE IMMEDIATELY!"
echo ""
echo "4. Test your VPN connection:"
echo "   - Connect to the VPN from your device"
echo "   - Access Pi-hole: http://192.168.8.251/admin"
echo "   - Test DNS: nslookup google.com"
echo ""
echo -e "${YELLOW}📚 Documentation:${NC}"
echo "   Full guide: stacks/vpn/DEPLOYMENT_GUIDE.md"
echo "   Quick reference: stacks/vpn/QUICK_REFERENCE.md"
echo "   README: stacks/vpn/README.md"
echo ""
echo -e "${YELLOW}🔍 Useful Commands:${NC}"
echo "   View logs: docker logs wireguard"
echo "   Restart: docker compose -f stacks/vpn/docker-compose.yml restart"
echo "   Stop: docker compose -f stacks/vpn/docker-compose.yml down"
echo ""
echo -e "${GREEN}Happy remote accessing! 🌐${NC}"
