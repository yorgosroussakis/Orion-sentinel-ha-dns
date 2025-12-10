#!/bin/bash
# =============================================================================
# Keepalived BACKUP State Notification
# =============================================================================
# Called when this node becomes BACKUP and releases the VIP
# =============================================================================

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
VIP="${VIP_ADDRESS:-unknown}"

echo "[${TIMESTAMP}] → Transition to BACKUP - VIP ${VIP} released"

# Log to syslog if available
logger -t keepalived "Transition to BACKUP state - VIP: ${VIP}" 2>/dev/null || true

# Optional: Send webhook notification
# if [[ -n "${ALERT_WEBHOOK:-}" ]]; then
#     curl -s -X POST -H "Content-Type: application/json" \
#         -d "{\"event\":\"backup\",\"vip\":\"${VIP}\",\"timestamp\":\"${TIMESTAMP}\"}" \
#         "${ALERT_WEBHOOK}" >/dev/null 2>&1 || true
# fi

exit 0
