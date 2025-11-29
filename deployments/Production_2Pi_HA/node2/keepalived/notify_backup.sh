#!/bin/bash
# =============================================================================
# Keepalived Notification Script - BACKUP State
# 2-Pi DNS HA Architecture - Production Ready
# =============================================================================
#
# This script is called when the node transitions to BACKUP state.
# The VIP is now on another node.
#
# =============================================================================

set -euo pipefail

# Arguments passed by keepalived
readonly VRRP_INSTANCE=${1:-VI_DNS}
readonly STATE=${2:-BACKUP}
readonly PRIORITY=${3:-100}

# Node information
readonly HOSTNAME=$(hostname)
readonly TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
readonly NODE_IP=${NODE_IP:-$(hostname -I | awk '{print $1}')}
readonly VIP=${VIP_ADDRESS:-192.168.8.255}

# Logging
readonly LOG_TAG="keepalived-notify"

log() {
    logger -t "${LOG_TAG}" "$*"
    echo "[${TIMESTAMP}] $*"
}

# Send alert via webhook if configured
send_webhook_alert() {
    local webhook_url="${ALERT_WEBHOOK:-}"
    local message="$1"
    local details="$2"
    
    if [[ -z "$webhook_url" ]]; then
        return 0
    fi
    
    local payload
    payload=$(cat <<EOF
{
    "event": "keepalived_state_change",
    "state": "BACKUP",
    "hostname": "${HOSTNAME}",
    "node_ip": "${NODE_IP}",
    "vip": "${VIP}",
    "vrrp_instance": "${VRRP_INSTANCE}",
    "priority": "${PRIORITY}",
    "timestamp": "${TIMESTAMP}",
    "message": "${message}",
    "details": "${details}"
}
EOF
)
    
    curl -s -X POST "$webhook_url" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --connect-timeout 5 \
        --max-time 10 \
        2>/dev/null || log "WARNING: Failed to send webhook alert"
}

# Send Signal notification if configured
send_signal_notification() {
    local signal_api="${SIGNAL_API_URL:-http://localhost:8080}"
    local signal_number="${SIGNAL_NUMBER:-}"
    local recipients="${SIGNAL_RECIPIENTS:-}"
    
    if [[ -z "$signal_number" ]] || [[ -z "$recipients" ]]; then
        return 0
    fi
    
    local message="🟡 DNS HA: ${HOSTNAME} is now BACKUP\nVIP ${VIP} moved to peer node\nTime: ${TIMESTAMP}"
    
    curl -s -X POST "${signal_api}/v2/send" \
        -H "Content-Type: application/json" \
        -d "{\"number\": \"${signal_number}\", \"recipients\": [\"${recipients}\"], \"message\": \"${message}\"}" \
        --connect-timeout 5 \
        --max-time 10 \
        2>/dev/null || log "WARNING: Failed to send Signal notification"
}

# Update Prometheus metrics via pushgateway if available
update_prometheus_metrics() {
    local pushgateway="${PROMETHEUS_PUSHGATEWAY:-http://localhost:9091}"
    
    cat <<EOF | curl -s --data-binary @- "${pushgateway}/metrics/job/keepalived/instance/${HOSTNAME}" 2>/dev/null || true
# HELP keepalived_state Current state of keepalived (1=MASTER, 0=BACKUP, -1=FAULT)
# TYPE keepalived_state gauge
keepalived_state{vrrp_instance="${VRRP_INSTANCE}",hostname="${HOSTNAME}"} 0
# HELP keepalived_priority Current VRRP priority
# TYPE keepalived_priority gauge
keepalived_priority{vrrp_instance="${VRRP_INSTANCE}",hostname="${HOSTNAME}"} ${PRIORITY}
# HELP keepalived_state_change_timestamp Timestamp of last state change
# TYPE keepalived_state_change_timestamp gauge
keepalived_state_change_timestamp{vrrp_instance="${VRRP_INSTANCE}",hostname="${HOSTNAME}"} $(date +%s)
EOF
}

# Create state file for external monitoring
create_state_file() {
    local state_dir="/tmp/keepalived"
    mkdir -p "$state_dir"
    
    cat > "${state_dir}/state" <<EOF
STATE=BACKUP
VRRP_INSTANCE=${VRRP_INSTANCE}
PRIORITY=${PRIORITY}
HOSTNAME=${HOSTNAME}
NODE_IP=${NODE_IP}
VIP=${VIP}
TIMESTAMP=${TIMESTAMP}
EOF
    
    echo "${TIMESTAMP}" > "${state_dir}/backup_since"
    rm -f "${state_dir}/master_since" "${state_dir}/fault_since" 2>/dev/null || true
}

# Main
main() {
    log "🟡 BACKUP: ${HOSTNAME} entered BACKUP state for ${VRRP_INSTANCE}"
    log "   VIP ${VIP} is on peer node"
    log "   Priority: ${PRIORITY}"
    
    # Create state file
    create_state_file
    
    # Send notifications if enabled
    if [[ "${NOTIFY_ON_FAILBACK:-true}" == "true" ]]; then
        local message="DNS HA: ${HOSTNAME} is now BACKUP"
        local details="VIP ${VIP} moved to peer. Priority: ${PRIORITY}"
        
        send_webhook_alert "$message" "$details"
        send_signal_notification
    fi
    
    # Update Prometheus metrics
    update_prometheus_metrics
    
    log "✅ BACKUP transition complete"
}

main "$@"
exit 0
