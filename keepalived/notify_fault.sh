#!/bin/bash
# =============================================================================
# Keepalived FAULT State Notification
# =============================================================================
# Called when keepalived detects a fault condition
# This is a critical event that should be investigated
# =============================================================================

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
VIP="${VIP_ADDRESS:-unknown}"
NODE="${NODE_ROLE:-unknown}"

echo "[${TIMESTAMP}] ✗ FAULT STATE - VIP ${VIP} - Investigate immediately!"

# Log to syslog with error priority
logger -t keepalived -p daemon.err "FAULT state detected - VIP: ${VIP}" 2>/dev/null || true

# Optional: Send critical webhook notification
# if [[ -n "${ALERT_WEBHOOK:-}" ]]; then
#     curl -s -X POST -H "Content-Type: application/json" \
#         -d "{\"event\":\"fault\",\"vip\":\"${VIP}\",\"timestamp\":\"${TIMESTAMP}\",\"severity\":\"critical\"}" \
#         "${ALERT_WEBHOOK}" >/dev/null 2>&1 || true
# fi

exit 0
