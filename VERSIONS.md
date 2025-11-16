# RPi HA DNS Stack - Version History

This document tracks all changes, improvements, and bug fixes for the RPi HA DNS Stack project.

---

## Version 2.1.0 (2024-11-16) - Installation System Overhaul

### 🎯 Overview
Major overhaul of the installation system with critical bug fixes, ARM64 compatibility improvements, and three distinct installation methods.

### 🐛 Critical Bugs Fixed

#### 1. Fixed Syntax Error in scripts/install.sh Line 12
**Problem:** Invalid REPO_ROOT variable definition causing script to fail
```bash
# Before (BROKEN):
REPO_ROOT="$(cd "");/.." && pwd)"

# After (FIXED):
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
```

#### 2. Fixed ARM64 Compatibility for Unbound
**Problem:** Using `mvance/unbound-rpi:latest` which only supports ARMv7 (32-bit ARM)
**Solution:** Switched to `klutchell/unbound:latest` for multi-architecture support

**Supported Architectures:**
- ✅ ARM64 (aarch64) - Raspberry Pi 5, Pi 4 with 64-bit OS
- ✅ ARMv7 (32-bit ARM) - Raspberry Pi 3/4 with 32-bit OS
- ✅ x86_64 (AMD64) - Standard PCs and servers

**Files Modified:**
- `stacks/dns/docker-compose.yml`

#### 3. Added Validation Before Calling launch-setup-ui.sh
**Enhancement:** Root install.sh now checks if launch-setup-ui.sh exists before calling
```bash
if [[ ! -f "scripts/launch-setup-ui.sh" ]]; then
    err "scripts/launch-setup-ui.sh not found!"
    exit 1
fi
```

#### 4. Added Docker Runtime Verification
**Enhancement:** scripts/install.sh now verifies Docker is:
- Installed and available
- Running (daemon active)
- Accessible by current user
- Properly configured

**Automatic Fixes:**
- Attempts to start Docker daemon if stopped
- Adds user to docker group if needed
- Provides clear error messages with solutions

#### 5. Added Comprehensive Prerequisite Checks
**New Function:** `check_prerequisites()` in scripts/install.sh validates:
- Operating System (Linux only)
- Architecture (ARM64, ARMv7, x86_64)
- Disk Space (minimum 5GB, recommended 10GB)
- Memory/RAM (minimum 1GB, recommended 2GB)
- Network Connectivity

### ✨ New Features

#### Three Installation Methods

**Method 1: Terminal Setup**
```bash
bash scripts/setup.sh
# or
bash scripts/interactive-setup.sh
```
- Keyboard-driven interface
- Works over SSH
- No GUI required
- Ideal for headless systems

**Method 2: Web UI Setup**
```bash
bash scripts/launch-setup-ui.sh
# Opens on http://localhost:5555
```
- Visual, user-friendly interface
- Access from any browser
- Real-time validation
- Perfect for beginners

**Method 3: Desktop GUI Setup**
```bash
bash scripts/install-gui.sh
```
- Native desktop dialogs (zenity/kdialog)
- Step-by-step wizard
- Automatic browser launch
- Best for desktop Linux users

#### New Scripts Created

**1. scripts/install-check.sh (320 lines)**
Pre-installation validation and system readiness checker

**Features:**
- OS compatibility check (Raspberry Pi OS, Debian, Ubuntu)
- Architecture verification (ARM64, ARMv7, x86_64)
- Disk space analysis (5GB min, 10GB recommended)
- Memory check (1GB min, 2GB recommended)
- Network connectivity test (DNS resolution, internet access)
- Docker availability and status
- Port availability check (53, 80, 3000, 5555, 9090)
- Permission verification (sudo, docker group)
- Detailed summary report with recommendations

**Usage:**
```bash
bash scripts/install-check.sh
```

**2. scripts/install-gui.sh (362 lines)**
Desktop Linux GUI installer with native dialogs

**Features:**
- Auto-detects desktop environment (GNOME, KDE, XFCE)
- Installs zenity (GNOME) or kdialog (KDE) automatically
- Graphical progress dialogs
- Pre-installation checks with GUI feedback
- Installation mode selection:
  - Web UI (opens browser automatically)
  - Terminal (launches terminal setup)
  - Automated (runs headless install)
- Error handling with graphical dialogs
- Cross-platform dialog support

**Requirements:**
- Desktop environment with X11 or Wayland
- Debian/Ubuntu-based system

**Usage:**
```bash
bash scripts/install-gui.sh
```

**3. scripts/test-installation.sh (376 lines)**
Comprehensive test suite for installation validation

**Test Categories:**
1. Script syntax validation (bash -n)
2. Shellcheck validation
3. Docker configuration validation
4. ARM64 compatibility check
5. Required files existence check
6. Documentation completeness
7. Environment file validation
8. Unbound configuration check
9. Script permissions check
10. Critical bugs verification

**Usage:**
```bash
bash scripts/test-installation.sh
```

### 🔧 Enhanced Existing Scripts

#### scripts/install.sh
**New Features:**
- `check_prerequisites()` function for system validation
- Rollback capability on errors
- Comprehensive logging to `install.log`
- Error trap for automatic cleanup
- Network creation tracking for rollback
- Better Docker daemon verification
- User group management

**Rollback Features:**
- Stops any started containers
- Removes created Docker networks
- Preserves user data and configurations
- Clear error messages and instructions

#### scripts/launch-setup-ui.sh
**New Validations:**
- Python 3 availability check
- Port 5555 availability check
- Setup UI files validation (docker-compose.yml, app.py)
- Docker daemon status check
- Service readiness verification with retries (10 attempts)
- Improved error messages with solutions
- Fallback instructions if web UI fails

#### install.sh (root level)
**Improvements:**
- Validation before calling launch-setup-ui.sh
- Error handling for setup UI failures
- Fallback to manual installation instructions
- Better error recovery guidance

### 📚 Documentation Updates

#### scripts/README.md
**Added Sections:**
- Overview of three installation methods
- Detailed documentation for install-check.sh
- Detailed documentation for install-gui.sh
- Detailed documentation for launch-setup-ui.sh
- Clear usage examples for each method
- When to use each installation method
- Requirements and prerequisites

### 🛡️ Error Handling & Recovery

#### Rollback System
When installation fails:
1. Captures exit code and context
2. Offers rollback option (interactive)
3. Stops started containers automatically
4. Removes created networks (tracked)
5. Preserves .env and user configurations
6. Provides clear next steps

#### Logging System
All installation activities logged to:
- Location: `install.log` in repo root
- Includes: Timestamps, errors, warnings, info
- Format: Human-readable with ANSI colors
- Purpose: Troubleshooting and debugging

### 🏗️ Compatibility Matrix

| Architecture | OS | Status | Notes |
|---|---|---|---|
| ARM64 (aarch64) | Raspberry Pi OS 64-bit | ✅ Fully Supported | Tested on Pi 5 |
| ARM64 (aarch64) | Ubuntu 22.04/24.04 | ✅ Fully Supported | Server & Desktop |
| ARMv7 (32-bit) | Raspberry Pi OS 32-bit | ✅ Fully Supported | Pi 3/4 legacy |
| x86_64 (AMD64) | Debian 11/12 | ✅ Fully Supported | Development/Testing |
| x86_64 (AMD64) | Ubuntu 22.04/24.04 | ✅ Fully Supported | Production ready |

### 📊 Statistics

- **Files Modified:** 5
  - install.sh
  - scripts/install.sh
  - scripts/launch-setup-ui.sh
  - stacks/dns/docker-compose.yml
  - scripts/README.md

- **Files Created:** 4
  - scripts/install-check.sh (320 lines)
  - scripts/install-gui.sh (362 lines)
  - scripts/test-installation.sh (376 lines)
  - VERSIONS.md (this file)

- **Total Lines Added:** 1,397+
- **Test Coverage:** 10 test categories
- **Installation Methods:** 3 (terminal, web, desktop)

### 🔍 Testing & Validation

**All Components Tested:**
- ✅ Bash syntax validation (bash -n)
- ✅ Shellcheck linting (warnings acceptable)
- ✅ ARM64 compatibility verified
- ✅ Docker configurations validated
- ✅ Required files presence confirmed
- ✅ Critical bugs verification passed

**Test Results:**
- Script syntax: PASS
- ARM64 images: PASS (klutchell/unbound)
- Docker configs: PASS (all compose files valid)
- Prerequisites: PASS (all checks implemented)
- Rollback: PASS (cleanup works correctly)

### 🔒 Security Considerations

- All scripts use `set -euo pipefail` for safe execution
- Sensitive operations require sudo with validation
- Passwords are never logged or displayed
- Rollback prevents partial/broken installations
- Validation before destructive operations
- Docker group membership managed safely

### 📝 Migration Guide

**No migration needed** - These are enhancements and bug fixes. Existing installations continue to work.

**For new installations:**
1. Clone the repository
2. Run pre-installation check: `bash scripts/install-check.sh`
3. Choose installation method:
   - Desktop: `bash scripts/install-gui.sh`
   - Remote/SSH: `bash scripts/launch-setup-ui.sh`
   - Terminal: `bash scripts/setup.sh`

**For existing installations:**
- Update with: `git pull`
- Benefit from bug fixes immediately
- ARM64 support requires image update: `docker compose pull`

### 🎯 Known Limitations

1. Desktop GUI requires X11/Wayland display server
2. Web UI requires port 5555 to be available
3. ARM64 support requires appropriate base OS (64-bit)
4. Minimum 5GB disk space required
5. Internet connectivity required for Docker image pulls
6. Some Linux distributions may need manual zenity/kdialog install

### 🚀 Next Steps for Users

1. **Run Pre-Installation Check:**
   ```bash
   bash scripts/install-check.sh
   ```

2. **Choose Installation Method:**
   - Desktop users: `bash scripts/install-gui.sh`
   - Remote/SSH: `bash scripts/launch-setup-ui.sh`
   - Terminal only: `bash scripts/setup.sh`

3. **Verify Installation:**
   ```bash
   bash scripts/test-installation.sh
   ```

4. **Access Services:**
   - Pi-hole: `http://<host-ip>/admin`
   - Grafana: `http://<host-ip>:3000`
   - Prometheus: `http://<host-ip>:9090`

---

## Version 2.0.0 (Previous) - Complete Installation Fix

### Overview
Complete fix of all installation issues including Docker networking, environment configuration, and Signal integration.

### Problems Fixed

#### 1. Timezone Configuration
- **Before**: `TZ=America/New_York`
- **After**: `TZ=Europe/Amsterdam` ✅

#### 2. Keepalived Image Not Found
- **Before**: `osinankur/keepalived:latest` (doesn't exist)
- **After**: `osixia/keepalived:2.0.20` ✅

#### 3. DNS Network Configuration Error
- **Error**: Invalid config for network - user specified IP requires subnet
- **Before**: Local bridge network without subnet
- **After**: External macvlan network `dns_net` created by install.sh ✅

#### 4. Network Name Mismatch
- **Before**: `monitoring-network` vs `observability_net`
- **After**: Consistent `observability_net` everywhere ✅

#### 5. Docker Compose Version Warnings
- **Before**: `version: '3.x'` (obsolete syntax)
- **After**: Removed from all compose files ✅

#### 6. .env File Not Found
- **Problem**: docker-compose looks for .env in same directory
- **Solution**: Symlinks created automatically by install.sh
  ```
  /repo-root/.env ✅
  /repo-root/stacks/dns/.env -> ../../.env ✅
  /repo-root/stacks/observability/.env -> ../../.env ✅
  /repo-root/stacks/ai-watchdog/.env -> ../../.env ✅
  ```

#### 7. CallMeBot Dependency
- **Before**: Required third-party CallMeBot with API keys
- **After**: Self-hosted signal-cli-rest-api ✅

### Migration: CallMeBot → signal-cli-rest-api

**New Setup:**
1. Signal setup (one-time, 5 minutes):
   ```bash
   docker exec -it signal-api signal-cli link -n "RPi-DNS-Monitor"
   ```
2. Scan QR code with Signal mobile app
3. Done! Self-hosted, no external dependencies

**Configuration:**
- Signal number in .env: `SIGNAL_SENDER`
- Recipients in .env: `SIGNAL_RECIPIENTS`
- No API keys needed

---

## Version 1.x (Initial Release)

- Initial multi-node HA DNS stack
- Pi-hole + Unbound recursive DNS
- Keepalived for VIP failover
- Prometheus + Grafana monitoring
- Basic installation scripts

---

## Upgrade Instructions

### From 2.0.x to 2.1.0

1. **Pull latest changes:**
   ```bash
   cd ~/rpi-ha-dns-stack
   git pull
   ```

2. **Update Unbound for ARM64:**
   ```bash
   docker compose -f stacks/dns/docker-compose.yml pull
   docker compose -f stacks/dns/docker-compose.yml up -d
   ```

3. **Test new features:**
   ```bash
   bash scripts/install-check.sh
   bash scripts/test-installation.sh
   ```

### From 1.x to 2.1.0

Follow full migration guide in documentation. Backup data before upgrading.

---

## Contributing

When adding new features or fixes, please update this VERSIONS.md file with:
- Version number (semantic versioning)
- Date
- Clear description of changes
- Migration/upgrade instructions if needed
- Breaking changes prominently marked

---

## Support

For issues or questions:
- GitHub Issues: https://github.com/yorgosroussakis/rpi-ha-dns-stack/issues
- Documentation: README.md and scripts/README.md
- Test suite: `bash scripts/test-installation.sh`
