#!/bin/bash
# CrowdSec Setup Script
# This script helps you set up CrowdSec intrusion detection system
# Standard IDS Profile for 8GB Pi 5 (Recommended)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "CrowdSec Intrusion Detection Setup"
echo "Standard IDS Profile (8GB Pi 5)"
echo "=========================================="
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
    echo "✅ Created .env file"
    echo ""
fi

echo "Step 1: Starting CrowdSec..."
docker compose up -d crowdsec
echo "⏳ Waiting for CrowdSec to initialize (30 seconds)..."
sleep 30

echo ""
echo "Step 2: Installing CrowdSec collections and scenarios..."
docker exec crowdsec cscli collections install crowdsecurity/linux || true
docker exec crowdsec cscli collections install crowdsecurity/sshd || true
docker exec crowdsec cscli collections install crowdsecurity/nginx || true
docker exec crowdsec cscli collections install crowdsecurity/http-cve || true

echo "✅ Collections installed"

echo ""
echo "Step 3: Restarting services with new configuration..."
docker compose restart crowdsec
sleep 10

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
echo "      - See PROMETHEUS_INTEGRATION.md for details"
echo ""
echo "   3. Test intrusion detection:"
echo "      - Try failed SSH logins: ssh baduser@localhost"
echo "      - Check decisions: docker exec crowdsec cscli decisions list"
echo ""
echo "ℹ️  Note: This configuration uses log-based detection only."
echo "   Detected threats are logged but not automatically blocked."
echo "   Review decisions regularly and add manual blocks as needed."
echo ""
