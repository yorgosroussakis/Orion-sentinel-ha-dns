# Blocky DNS Gateway - Dockerfile
# Adds custom entrypoint for environment variable substitution
#
# Features:
# - DoH/DoT termination for encrypted DNS
# - Environment variable substitution for config
# - Docker HEALTHCHECK for container monitoring

FROM spx01/blocky:latest

USER root

# Install envsubst for template processing, curl for healthcheck, and netcat for port checks
RUN apk add --no-cache gettext bash curl netcat-openbsd

# Copy config template
COPY config.yml.template /app/config.yml.template

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy healthcheck script
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

USER blocky

# Docker HEALTHCHECK: Performs DoH query check via API
# Checks if the Blocky API is responding correctly
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD ["/healthcheck.sh"]

ENTRYPOINT ["/entrypoint.sh"]
