#!/bin/bash
# =============================================================================
# Keepalived Container Entrypoint
# =============================================================================
# Generates /etc/keepalived/keepalived.conf from environment variables
# using a HEREDOC to ensure the final config has no shell syntax or \n literals
# =============================================================================

set -euo pipefail

CONFIG_FILE="/etc/keepalived/keepalived.conf"

# =============================================================================
# Environment Variables with Defaults
# =============================================================================
NODE_ROLE="${NODE_ROLE:-MASTER}"
KEEPALIVED_PRIORITY="${KEEPALIVED_PRIORITY:-200}"
VIP_ADDRESS="${VIP_ADDRESS:?VIP_ADDRESS environment variable is required}"
VIP_NETMASK="${VIP_NETMASK:-24}"
NETWORK_INTERFACE="${NETWORK_INTERFACE:-eth1}"
VIRTUAL_ROUTER_ID="${VIRTUAL_ROUTER_ID:-51}"
VRRP_PASSWORD="${VRRP_PASSWORD:?VRRP_PASSWORD environment variable is required}"
PEER_IP="${PEER_IP:-}"
USE_UNICAST_VRRP="${USE_UNICAST_VRRP:-true}"

# Generate router_id from role
ROUTER_ID="orion-dns-${NODE_ROLE}"

# =============================================================================
# Log configuration
# =============================================================================
echo "========================================"
echo "Keepalived Configuration Generator"
echo "========================================"
echo "Node Role:        ${NODE_ROLE}"
echo "Priority:         ${KEEPALIVED_PRIORITY}"
echo "VIP:              ${VIP_ADDRESS}/${VIP_NETMASK}"
echo "Interface:        ${NETWORK_INTERFACE}"
echo "Router ID:        ${VIRTUAL_ROUTER_ID}"
echo "Unicast Mode:     ${USE_UNICAST_VRRP}"
if [[ -n "${PEER_IP}" ]]; then
    echo "Peer IP:          ${PEER_IP}"
fi
echo "========================================"

# =============================================================================
# Generate keepalived.conf using HEREDOC
# This ensures no raw ${VAR} or literal \n sequences in the output
# =============================================================================

# Build unicast_peer section if enabled
UNICAST_SECTION=""
if [[ "${USE_UNICAST_VRRP}" == "true" ]] && [[ -n "${PEER_IP}" ]]; then
    UNICAST_SECTION="    unicast_peer {
        ${PEER_IP}
    }"
fi

# Write the configuration file
cat > "${CONFIG_FILE}" << KEEPALIVED_CONFIG
# =============================================================================
# Keepalived Configuration - Auto-generated
# =============================================================================
# Generated at: $(date -Iseconds)
# Node Role: ${NODE_ROLE}
# DO NOT EDIT - Regenerated on container start
# =============================================================================

global_defs {
    router_id ${ROUTER_ID}
    enable_script_security
    script_user root
}

# Health check script for DNS services
vrrp_script check_dns {
    script "/etc/keepalived/check_dns.sh"
    interval 5
    timeout 3
    weight -20
    fall 2
    rise 2
}

# VRRP instance for VIP management
vrrp_instance VI_1 {
    state ${NODE_ROLE}
    interface ${NETWORK_INTERFACE}
    virtual_router_id ${VIRTUAL_ROUTER_ID}
    priority ${KEEPALIVED_PRIORITY}
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass ${VRRP_PASSWORD}
    }

${UNICAST_SECTION}

    virtual_ipaddress {
        ${VIP_ADDRESS}/${VIP_NETMASK}
    }

    track_script {
        check_dns
    }

    notify_master "/etc/keepalived/notify_master.sh"
    notify_backup "/etc/keepalived/notify_backup.sh"
    notify_fault "/etc/keepalived/notify_fault.sh"
}
KEEPALIVED_CONFIG

echo "Configuration written to ${CONFIG_FILE}"
echo ""

# =============================================================================
# Validate configuration syntax
# =============================================================================
echo "Validating keepalived configuration..."
if keepalived --config-test="${CONFIG_FILE}" 2>/dev/null; then
    echo "✓ Configuration syntax is valid"
else
    echo "⚠ Warning: Configuration validation returned non-zero (may be ok)"
fi
echo ""

# =============================================================================
# Start keepalived
# =============================================================================
echo "Starting keepalived..."
exec keepalived --dont-fork --log-console --log-detail --vrrp
