FROM alpine:3.19

LABEL maintainer="Orion Sentinel DNS HA"
LABEL description="Production-ready Keepalived for DNS HA VIP failover"

# Install keepalived and required utilities
RUN apk add --no-cache \
    keepalived \
    iputils \
    iproute2 \
    bash \
    bind-tools \
    curl \
    docker-cli \
    jq \
    && rm -rf /var/cache/apk/*

# Create keepalived directories
RUN mkdir -p /etc/keepalived /var/log/keepalived

# Copy notification scripts (will be mounted from host)
COPY check_dns.sh /etc/keepalived/check_dns.sh
COPY notify_master.sh /etc/keepalived/notify_master.sh
COPY notify_backup.sh /etc/keepalived/notify_backup.sh
COPY notify_fault.sh /etc/keepalived/notify_fault.sh

# Make scripts executable
RUN chmod +x /etc/keepalived/*.sh

# Expose VRRP protocol port
EXPOSE 112/udp

# Health check for keepalived process
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD pgrep -x keepalived || exit 1

# Run keepalived in foreground with detailed logging
CMD ["keepalived", "--dont-fork", "--log-console", "--log-detail", "--dump-conf"]
