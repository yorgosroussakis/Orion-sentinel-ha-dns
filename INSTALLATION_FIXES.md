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

**Fix**: Created a local Dockerfile to build keepalived from Alpine Linux
- **New file**: `stacks/dns/keepalived/Dockerfile`
- **Modified**: `stacks/dns/docker-compose.yml` to build instead of pull

The Dockerfile uses official Alpine Linux packages:
```dockerfile
FROM alpine:latest
RUN apk add --no-cache keepalived iputils iproute2 bash
CMD ["keepalived", "--dont-fork", "--log-console", "--log-detail"]
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

1. `.env.example` - Updated timezone
2. `stacks/dns/docker-compose.yml` - Removed version, changed keepalived to build locally
3. `stacks/dns/keepalived/Dockerfile` - NEW: Dockerfile for keepalived
4. `stacks/observability/docker-compose.yml` - Removed version, fixed network name
5. `stacks/ai-watchdog/docker-compose.yml` - Removed version, fixed network name
