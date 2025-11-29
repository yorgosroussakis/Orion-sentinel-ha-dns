#!/bin/bash
# =============================================================================
# Keepalived Notification Script - FAULT State
# 2-Pi DNS HA Architecture - Production Ready
# =============================================================================
#
# This script is called when the node enters FAULT state.
# This indicates a critical issue with the node.
#
# =============================================================================

set -euo pipefail

# Arguments passed by keepalived
readonly VRRP_INSTANCE=${1:-VI_DNS}
readonly STATE=${2:-FAULT}
readonly PRIORITY=${3:-100}

# Node information
readonly HOSTNAME=$(hostname)
readonly TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
readonly NODE_IP=${NODE_IP:-$(hostname -I | awk '{print $1}')}
readonly VIP=${VIP_ADDRESS:-192.168.8.255}

# Logging
readonly LOG_TAG="keepalived-notify"

log() {
    logger -t "${LOG_TAG}" -p "daemon.err" "$*"
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
    "state": "FAULT",
    "severity": "critical",
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

# Send Signal notification if configured (always notify on faults)
send_signal_notification() {
    local signal_api="${SIGNAL_API_URL:-http://localhost:8080}"
    local signal_number="${SIGNAL_NUMBER:-}"
    local recipients="${SIGNAL_RECIPIENTS:-}"
    
    if [[ -z "$signal_number" ]] || [[ -z "$recipients" ]]; then
        return 0
    fi
    
    local message="🔴 CRITICAL: DNS HA FAULT on ${HOSTNAME}\nNode has entered FAULT state!\nVRRP Instance: ${VRRP_INSTANCE}\nTime: ${TIMESTAMP}\n\nImmediate attention required!"
    
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
keepalived_state{vrrp_instance="${VRRP_INSTANCE}",hostname="${HOSTNAME}"} -1
# HELP keepalived_priority Current VRRP priority
# TYPE keepalived_priority gauge
keepalived_priority{vrrp_instance="${VRRP_INSTANCE}",hostname="${HOSTNAME}"} ${PRIORITY}
# HELP keepalived_state_change_timestamp Timestamp of last state change
# TYPE keepalived_state_change_timestamp gauge
keepalived_state_change_timestamp{vrrp_instance="${VRRP_INSTANCE}",hostname="${HOSTNAME}"} $(date +%s)
# HELP keepalived_fault_total Total number of fault events
# TYPE keepalived_fault_total counter
keepalived_fault_total{vrrp_instance="${VRRP_INSTANCE}",hostname="${HOSTNAME}"} 1
EOF
}

# Create state file for external monitoring
create_state_file() {
    local state_dir="/tmp/keepalived"
    mkdir -p "$state_dir"
    
    cat > "${state_dir}/state" <<EOF
STATE=FAULT
VRRP_INSTANCE=${VRRP_INSTANCE}
PRIORITY=${PRIORITY}
HOSTNAME=${HOSTNAME}
NODE_IP=${NODE_IP}
VIP=${VIP}
TIMESTAMP=${TIMESTAMP}
EOF
    
    echo "${TIMESTAMP}" >> "${state_dir}/fault_history"
    echo "${TIMESTAMP}" > "${state_dir}/fault_since"
    rm -f "${state_dir}/master_since" "${state_dir}/backup_since" 2>/dev/null || true
}

# Main
main() {
    log "🔴 FAULT: ${HOSTNAME} entered FAULT state for ${VRRP_INSTANCE}"
    log "   CRITICAL: Node is not operational!"
    log "   Priority: ${PRIORITY}"
    
    # Create state file
    create_state_file
    
    # Always send notifications on faults (critical alerts)
    local message="CRITICAL: DNS HA node ${HOSTNAME} in FAULT state"
    local details="Node is not operational. Immediate attention required. Priority: ${PRIORITY}"
    
    send_webhook_alert "$message" "$details"
    send_signal_notification
    
    # Update Prometheus metrics
    update_prometheus_metrics
    
    log "❌ FAULT state recorded - immediate attention required!"
}

main "$@"
exit 0
