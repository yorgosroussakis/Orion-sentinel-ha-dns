# Installation Issues - Fixed

## Summary of Changes

This document summarizes all the fixes applied to resolve the installation issues reported.

## Issues Fixed

### 1. Timezone Configuration ✅
**Issue**: `.env.example` had timezone set to `America/New_York`
**Fix**: Changed to `Europe/Amsterdam` as requested
**File**: `.env.example` (line 11)

```diff
- TZ=America/New_York
+ TZ=Europe/Amsterdam
```

### 2. Keepalived Image Not Found ✅
**Issue**: Docker image `osinankur/keepalived:latest` doesn't exist or requires authentication
**Error**: `pull access denied for osinankur/keepalived, repository does not exist or may require 'docker login'`

**Fix**: Changed to use publicly available `osixia/keepalived:2.0.20` image
- **Modified**: `stacks/dns/docker-compose.yml` to use `osixia/keepalived:2.0.20`

```diff
- image: osinankur/keepalived:latest
+ image: osixia/keepalived:2.0.20
```

### 3. Network Name Mismatch ✅
**Issue**: Docker networks had inconsistent names
- `install.sh` creates: `observability_net`
- Docker compose files expected: `monitoring-network`
**Error**: `network monitoring-network declared as external, but could not be found`

**Fix**: Updated all docker-compose files to use `observability_net`
- `stacks/observability/docker-compose.yml`
- `stacks/ai-watchdog/docker-compose.yml`

### 4. Obsolete Docker Compose Version Attribute ✅
**Issue**: Docker Compose shows warning about obsolete `version` attribute
**Warning**: `the attribute 'version' is obsolete, it will be ignored, please remove it to avoid potential confusion`

**Fix**: Removed `version: '3.x'` line from all docker-compose files:
- `stacks/dns/docker-compose.yml`
- `stacks/observability/docker-compose.yml`
- `stacks/ai-watchdog/docker-compose.yml`

### 5. DNS Network Configuration Error ✅
**Issue**: DNS stack fails to start with network configuration error
**Error**: `invalid config for network dns_pihole_net: invalid endpoint settings: user specified IP address is supported only when connecting to networks with user configured subnets`

**Fix**: Changed DNS docker-compose.yml to use external network created by install.sh
- The network is created as a macvlan network by `scripts/install.sh`
- Docker-compose now references it as an external network named `dns_net`

```diff
networks:
  pihole_net:
-   driver: bridge
+   external: true
+   name: dns_net
```

### 6. Signal Integration Migration (CallMeBot → signal-cli-rest-api) ✅
**Issue**: Dependency on third-party CallMeBot service for Signal notifications
**Previous**: Used CallMeBot API which requires API keys and has rate limits

**Fix**: Migrated to self-hosted signal-cli-rest-api solution
- **Added service**: `signal-cli-rest-api` container
- **Updated**: signal-webhook-bridge to use signal-cli-rest-api
- **Changed environment variables**:
  - Removed: `SIGNAL_WEBHOOK_URL`, `SIGNAL_API_KEY`, `SIGNAL_PHONE_NUMBER`
  - Added: `SIGNAL_NUMBER`, `SIGNAL_RECIPIENTS`
- **Benefits**:
  - ✅ Self-hosted - no third-party dependencies
  - ✅ More reliable - direct Signal protocol
  - ✅ No rate limits
  - ✅ Support for groups and attachments
  - ✅ End-to-end encryption maintained

See [SIGNAL_INTEGRATION_GUIDE.md](SIGNAL_INTEGRATION_GUIDE.md) for setup instructions.

## Environment Variable Warnings (Expected)

The following warnings are **expected** and not errors:
```
WARN[0000] The "PIHOLE_PASSWORD" variable is not set. Defaulting to a blank string.
WARN[0000] The "GRAFANA_ADMIN_PASSWORD" variable is not set. Defaulting to a blank string.
WARN[0000] The "SIGNAL_PHONE_NUMBER" variable is not set. Defaulting to a blank string.
WARN[0000] The "SIGNAL_API_KEY" variable is not set. Defaulting to a blank string.
```

These warnings appear because environment variables are configured by the user in the `.env` file. The install script prompts users to configure these before deployment.

## How to Install Now

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
   cd rpi-ha-dns-stack
   ```

2. **Copy and configure environment file**:
   ```bash
   cp .env.example .env
   nano .env  # Edit with your settings
   ```
   
   Make sure to set at least:
   - `TZ=Europe/Amsterdam` (now the default)
   - `PIHOLE_PASSWORD` (change from default)
   - `GRAFANA_ADMIN_PASSWORD` (change from default)
   - `VRRP_PASSWORD` (change from default)

3. **Run the installation**:
   ```bash
   sudo bash scripts/install.sh
   ```

The installation will now:
- Create the correct `observability_net` network
- Build the keepalived image locally
- Deploy all services without version warnings
- Use Europe/Amsterdam timezone

## Testing

All docker-compose files have been validated:
```bash
cd stacks/dns && docker compose config --quiet ✅
cd stacks/observability && docker compose config --quiet ✅
cd stacks/ai-watchdog && docker compose config --quiet ✅
```

## Files Changed

1. `.env.example` - Updated timezone, replaced CallMeBot with signal-cli-rest-api variables
2. `stacks/dns/docker-compose.yml` - Removed version, changed keepalived image, fixed network configuration
3. `stacks/dns/keepalived/Dockerfile` - REMOVED: No longer needed with osixia/keepalived image
4. `stacks/observability/docker-compose.yml` - Removed version, fixed network name, added signal-cli-rest-api service, updated signal-webhook-bridge
5. `stacks/observability/signal-webhook-bridge/app.py` - Complete rewrite to use signal-cli-rest-api instead of CallMeBot
6. `stacks/observability/signal-cli-config/` - NEW: Directory for Signal registration data
7. `stacks/ai-watchdog/docker-compose.yml` - Removed version, fixed network name
8. `SIGNAL_INTEGRATION_GUIDE.md` - Complete rewrite with signal-cli-rest-api instructions
9. `README.md` - Updated Signal setup instructions
10. `.gitignore` - Added signal-cli-config exclusion
11. `INSTALLATION_FIXES.md` - This document
