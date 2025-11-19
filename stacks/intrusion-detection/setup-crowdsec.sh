#!/bin/bash
# CrowdSec Setup Script
# This script helps you set up CrowdSec intrusion detection system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "CrowdSec Intrusion Detection Setup"
echo "=========================================="
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
    echo "✅ Created .env file"
    echo ""
fi

# Function to generate a random API key
generate_api_key() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

echo "Step 1: Starting CrowdSec (initial setup)..."
docker compose up -d crowdsec
echo "⏳ Waiting for CrowdSec to initialize (30 seconds)..."
sleep 30

echo ""
echo "Step 2: Generating bouncer API keys..."

# Generate firewall bouncer key
echo "Generating firewall bouncer key..."
FIREWALL_KEY=$(docker exec crowdsec cscli bouncers add firewall-bouncer -o raw 2>/dev/null || echo "")

if [ -z "$FIREWALL_KEY" ]; then
    echo "⚠️  Failed to generate firewall bouncer key. It may already exist."
    echo "To regenerate: docker exec crowdsec cscli bouncers delete firewall-bouncer"
    echo "              docker exec crowdsec cscli bouncers add firewall-bouncer -o raw"
else
    echo "✅ Firewall bouncer key generated"
    # Update .env file
    if grep -q "^CROWDSEC_BOUNCER_KEY_FIREWALL=" .env; then
        sed -i "s/^CROWDSEC_BOUNCER_KEY_FIREWALL=.*/CROWDSEC_BOUNCER_KEY_FIREWALL=$FIREWALL_KEY/" .env
    else
        echo "CROWDSEC_BOUNCER_KEY_FIREWALL=$FIREWALL_KEY" >> .env
    fi
fi

echo ""
echo "Step 3: Installing CrowdSec collections and scenarios..."
docker exec crowdsec cscli collections install crowdsecurity/linux || true
docker exec crowdsec cscli collections install crowdsecurity/sshd || true
docker exec crowdsec cscli collections install crowdsecurity/nginx || true
docker exec crowdsec cscli collections install crowdsecurity/http-cve || true
docker exec crowdsec cscli collections install crowdsecurity/whitelist-good-actors || true
docker exec crowdsec cscli collections install crowdsecurity/base-http-scenarios || true

echo "✅ Collections installed"

echo ""
echo "Step 4: Restarting services with new configuration..."
docker compose restart crowdsec
sleep 10
docker compose up -d crowdsec-firewall-bouncer

echo ""
echo "=========================================="
echo "✅ CrowdSec Setup Complete!"
echo "=========================================="
echo ""
echo "📊 Check status:"
echo "   docker exec crowdsec cscli metrics"
echo "   docker exec crowdsec cscli decisions list"
echo "   docker exec crowdsec cscli alerts list"
echo ""
echo "🔍 View logs:"
echo "   docker logs -f crowdsec"
echo "   docker logs -f crowdsec-firewall-bouncer"
echo ""
echo "📈 Prometheus metrics available at:"
echo "   http://localhost:6060/metrics"
echo ""
echo "🎯 Next Steps (Optional):"
echo "   1. Enroll in CrowdSec Console for premium features:"
echo "      - Sign up at https://app.crowdsec.net/"
echo "      - Get your enrollment key"
echo "      - Add to .env: CROWDSEC_ENROLL_KEY=your_key"
echo "      - Restart: docker compose restart crowdsec"
echo ""
echo "   2. Add Prometheus monitoring:"
echo "      - Add CrowdSec metrics to Prometheus config"
echo "      - See README.md for details"
echo ""
echo "   3. Test intrusion detection:"
echo "      - Try failed SSH logins: ssh baduser@localhost"
echo "      - Check decisions: docker exec crowdsec cscli decisions list"
echo ""
