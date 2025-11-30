# Blocky DNS Gateway - Dockerfile
# Adds custom entrypoint for environment variable substitution

FROM spx01/blocky:latest

USER root

# Install envsubst for template processing
RUN apk add --no-cache gettext bash

# Copy config template
COPY config.yml.template /app/config.yml.template

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER blocky

ENTRYPOINT ["/entrypoint.sh"]
