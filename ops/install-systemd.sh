#!/usr/bin/env bash
# =============================================================================
# Install Orion DNS HA Systemd Services
# =============================================================================
# Installs systemd services and timers for autostart, auto-healing, and backups.
#
# Usage:
#   sudo ./ops/install-systemd.sh primary    # On primary node
#   sudo ./ops/install-systemd.sh backup     # On backup node
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
SYSTEMD_DIR="/etc/systemd/system"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (sudo)"
    exit 1
fi

# Check arguments
NODE_TYPE="${1:-}"
if [[ "$NODE_TYPE" != "primary" && "$NODE_TYPE" != "backup" ]]; then
    echo "Usage: $0 <primary|backup>"
    exit 1
fi

log_info "Installing Orion DNS HA systemd services for ${NODE_TYPE} node..."

# Create symlink for repo if not at /opt/orion-dns-ha
if [[ "${REPO_DIR}" != "/opt/orion-dns-ha" ]]; then
    log_info "Creating symlink: /opt/orion-dns-ha -> ${REPO_DIR}"
    ln -sfn "${REPO_DIR}" /opt/orion-dns-ha
fi

# Make scripts executable
chmod +x "${REPO_DIR}/ops/"*.sh

# Install main service
if [[ "$NODE_TYPE" == "primary" ]]; then
    log_info "Installing primary service..."
    cp "${REPO_DIR}/systemd/orion-dns-ha-primary.service" "${SYSTEMD_DIR}/"
    systemctl daemon-reload
    systemctl enable orion-dns-ha-primary.service
else
    log_info "Installing backup service..."
    cp "${REPO_DIR}/systemd/orion-dns-ha-backup.service" "${SYSTEMD_DIR}/"
    systemctl daemon-reload
    systemctl enable orion-dns-ha-backup.service
fi

# Install health check timer
log_info "Installing health check timer..."
cp "${REPO_DIR}/systemd/orion-dns-health.service" "${SYSTEMD_DIR}/"
cp "${REPO_DIR}/systemd/orion-dns-health.timer" "${SYSTEMD_DIR}/"
systemctl daemon-reload
systemctl enable orion-dns-health.timer
systemctl start orion-dns-health.timer

# Install backup timer
log_info "Installing backup timer..."
cp "${REPO_DIR}/systemd/orion-dns-backup.service" "${SYSTEMD_DIR}/"
cp "${REPO_DIR}/systemd/orion-dns-backup.timer" "${SYSTEMD_DIR}/"
systemctl daemon-reload
systemctl enable orion-dns-backup.timer
systemctl start orion-dns-backup.timer

# Install sync timer (primary only)
if [[ "$NODE_TYPE" == "primary" ]]; then
    log_info "Installing Pi-hole sync timer..."
    cp "${REPO_DIR}/systemd/orion-dns-sync.service" "${SYSTEMD_DIR}/"
    cp "${REPO_DIR}/systemd/orion-dns-sync.timer" "${SYSTEMD_DIR}/"
    systemctl daemon-reload
    systemctl enable orion-dns-sync.timer
    systemctl start orion-dns-sync.timer
fi

log_info "Installation complete!"
echo ""
echo "Installed services:"
systemctl list-timers --all | grep orion-dns || true
echo ""
echo "To start the DNS stack now:"
if [[ "$NODE_TYPE" == "primary" ]]; then
    echo "  sudo systemctl start orion-dns-ha-primary"
else
    echo "  sudo systemctl start orion-dns-ha-backup"
fi
