# Unbound DNS Resolver with Smart Prefetch Configuration Support
# Based on klutchell/unbound with custom entrypoint for environment-based config
#
# Features:
# - Conditional smart prefetch configuration via UNBOUND_SMART_PREFETCH env var
# - NextDNS DoT forwarding (default) or full recursive resolution
# - DNSSEC validation and privacy hardening
# - Docker HEALTHCHECK with DNSSEC validation test

FROM klutchell/unbound:latest

# Install bash for entrypoint script and drill for healthcheck
USER root
RUN apk add --no-cache bash drill

# Copy configuration files
COPY unbound.conf /opt/unbound/etc/unbound/unbound.conf.base
COPY 30-performance-and-privacy.conf /opt/unbound/etc/unbound/30-performance-and-privacy.conf

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy healthcheck script
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

USER unbound

# Docker HEALTHCHECK: Performs DNSSEC-validating query
# Uses drill with +dnssec to verify resolver is working and validating
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD ["/healthcheck.sh"]

ENTRYPOINT ["/entrypoint.sh"]
