# Keepalived Container for Orion Sentinel HA DNS
# ===============================================
# Based on: https://github.com/acassen/keepalived
#
# Provides VRRP-based VIP management for two-node HA DNS
# VIP floats between primary (MASTER) and backup nodes

FROM alpine:3.19

LABEL maintainer="Orion Sentinel"
LABEL description="Keepalived for HA DNS VIP management"

# Install keepalived and required tools
# - keepalived: VRRP daemon
# - bash: For entrypoint and scripts
# - bind-tools: For dig (DNS health checks)
# - curl: For webhook notifications
# - iputils: For ping
# - gettext: For envsubst (not used - we use heredoc instead)
RUN apk add --no-cache \
    keepalived \
    bash \
    bind-tools \
    curl \
    iputils \
    && rm -rf /var/cache/apk/*

# Create keepalived directory and add nobody user for script_user
RUN mkdir -p /etc/keepalived \
    && adduser -D -H -s /sbin/nologin keepalived_script 2>/dev/null || true

# Copy scripts
COPY entrypoint.sh /entrypoint.sh
COPY check_dns.sh /etc/keepalived/check_dns.sh
COPY notify_master.sh /etc/keepalived/notify_master.sh
COPY notify_backup.sh /etc/keepalived/notify_backup.sh
COPY notify_fault.sh /etc/keepalived/notify_fault.sh

# Make scripts executable
RUN chmod +x /entrypoint.sh \
    /etc/keepalived/check_dns.sh \
    /etc/keepalived/notify_master.sh \
    /etc/keepalived/notify_backup.sh \
    /etc/keepalived/notify_fault.sh

ENTRYPOINT ["/entrypoint.sh"]
