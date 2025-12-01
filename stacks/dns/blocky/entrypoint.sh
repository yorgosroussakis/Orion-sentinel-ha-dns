#!/bin/bash
# Blocky entrypoint script
# Processes config template with environment variables and starts Blocky

set -e

# Set defaults for environment variables
DNS_VIP="${DNS_VIP:-192.168.8.249}"

echo "=========================================="
echo "Blocky DNS Gateway Configuration"
echo "=========================================="
echo "DNS_VIP (Upstream): ${DNS_VIP}"
echo "=========================================="

# Generate config from template using envsubst
envsubst < /app/config.yml.template > /app/config.yml

echo "Configuration generated at /app/config.yml"
echo "Starting Blocky DNS Gateway..."

# Execute blocky with the generated config
exec /app/blocky --config /app/config.yml
