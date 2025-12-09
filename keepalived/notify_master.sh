#!/bin/bash
# =============================================================================
# Keepalived MASTER State Notification
# =============================================================================
# Called when this node becomes MASTER and takes over the VIP
# =============================================================================

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
VIP="${VIP_ADDRESS:-unknown}"
NODE="${NODE_ROLE:-MASTER}"

echo "[${TIMESTAMP}] ✓ Transition to MASTER - VIP ${VIP} is now active on this node"

# Log to syslog if available
logger -t keepalived "Transition to MASTER state - VIP: ${VIP}" 2>/dev/null || true

# Optional: Send webhook notification
# Uncomment and configure ALERT_WEBHOOK in environment if needed
# if [[ -n "${ALERT_WEBHOOK:-}" ]]; then
#     curl -s -X POST -H "Content-Type: application/json" \
#         -d "{\"event\":\"master\",\"vip\":\"${VIP}\",\"timestamp\":\"${TIMESTAMP}\"}" \
#         "${ALERT_WEBHOOK}" >/dev/null 2>&1 || true
# fi

exit 0
