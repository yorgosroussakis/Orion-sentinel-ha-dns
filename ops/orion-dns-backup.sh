#!/usr/bin/env bash
# =============================================================================
# Orion DNS Backup Script
# =============================================================================
# Daily backup of Pi-hole configuration and data with retention policy.
#
# Usage:
#   ./ops/orion-dns-backup.sh              # Create backup
#   ./ops/orion-dns-backup.sh --list       # List backups
#   ./ops/orion-dns-backup.sh --restore <file>  # Restore from backup
#
# Install as systemd timer for daily backups (see systemd/orion-dns-backup.timer)
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
BACKUP_DIR="${REPO_DIR}/backups"
LOG_DIR="${REPO_DIR}/logs"

# Retention policy
RETENTION_DAYS="${RETENTION_DAYS:-7}"
MAX_BACKUPS="${MAX_BACKUPS:-10}"

# Container name
CONTAINER="pihole_unbound"

# Create directories
mkdir -p "${BACKUP_DIR}" "${LOG_DIR}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    local msg
    msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "${LOG_DIR}/backup.log"
    echo -e "$msg"
}

log_info() { log "${GREEN}[INFO]${NC} $*"; }
log_warn() { log "${YELLOW}[WARN]${NC} $*"; }
log_error() { log "${RED}[ERROR]${NC} $*"; }

# =============================================================================
# Backup Functions
# =============================================================================

create_backup() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="orion-dns-backup-${timestamp}"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    local backup_archive="${backup_path}.tar.gz"

    log_info "Creating backup: ${backup_name}"

    # Create temp directory
    mkdir -p "${backup_path}"

    # Backup Pi-hole configuration
    log_info "  Backing up Pi-hole configuration..."
    local pihole_files=(
        "/etc/pihole/adlists.list"
        "/etc/pihole/custom.list"
        "/etc/pihole/whitelist.txt"
        "/etc/pihole/blacklist.txt"
        "/etc/pihole/regex.list"
        "/etc/pihole/pihole-FTL.conf"
        "/etc/pihole/setupVars.conf"
        "/etc/pihole/gravity.db"
    )

    mkdir -p "${backup_path}/pihole"
    for file in "${pihole_files[@]}"; do
        local filename
        filename=$(basename "$file")
        if docker exec "${CONTAINER}" test -f "$file" 2>/dev/null; then
            docker cp "${CONTAINER}:${file}" "${backup_path}/pihole/${filename}" 2>/dev/null || true
        fi
    done

    # Backup dnsmasq configuration
    log_info "  Backing up dnsmasq configuration..."
    mkdir -p "${backup_path}/dnsmasq.d"
    docker cp "${CONTAINER}:/etc/dnsmasq.d/." "${backup_path}/dnsmasq.d/" 2>/dev/null || true

    # Backup .env file
    log_info "  Backing up environment configuration..."
    if [[ -f "${REPO_DIR}/.env" ]]; then
        cp "${REPO_DIR}/.env" "${backup_path}/env.backup"
    fi

    # Create metadata
    cat > "${backup_path}/metadata.json" << EOF
{
    "timestamp": "${timestamp}",
    "hostname": "$(hostname)",
    "date": "$(date -Iseconds)",
    "container": "${CONTAINER}",
    "pihole_version": "$(docker exec ${CONTAINER} pihole -v 2>/dev/null | head -1 || echo 'unknown')"
}
EOF

    # Create archive
    log_info "  Creating archive..."
    tar -czf "${backup_archive}" -C "${BACKUP_DIR}" "${backup_name}"

    # Remove temp directory
    rm -rf "${backup_path}"

    # Calculate size
    local size
    size=$(du -h "${backup_archive}" | cut -f1)
    log_info "Backup created: ${backup_archive} (${size})"

    # Apply retention policy
    apply_retention

    echo "${backup_archive}"
}

apply_retention() {
    log_info "Applying retention policy (${RETENTION_DAYS} days, max ${MAX_BACKUPS} backups)..."

    # Remove backups older than retention days
    find "${BACKUP_DIR}" -name "orion-dns-backup-*.tar.gz" -mtime "+${RETENTION_DAYS}" -delete 2>/dev/null || true

    # Keep only MAX_BACKUPS most recent
    local count
    count=$(find "${BACKUP_DIR}" -name "orion-dns-backup-*.tar.gz" | wc -l)
    if [[ $count -gt ${MAX_BACKUPS} ]]; then
        local to_remove=$((count - MAX_BACKUPS))
        find "${BACKUP_DIR}" -name "orion-dns-backup-*.tar.gz" -printf '%T@ %p\n' | \
            sort -n | head -n "${to_remove}" | cut -d' ' -f2- | xargs rm -f
        log_info "  Removed ${to_remove} old backup(s)"
    fi
}

list_backups() {
    log_info "Available backups:"
    echo ""
    
    if [[ ! -d "${BACKUP_DIR}" ]] || [[ -z "$(ls -A "${BACKUP_DIR}"/*.tar.gz 2>/dev/null)" ]]; then
        echo "  No backups found."
        return
    fi

    printf "%-45s %10s %s\n" "Filename" "Size" "Date"
    printf "%s\n" "$(printf '=%.0s' {1..70})"
    
    for backup in "${BACKUP_DIR}"/orion-dns-backup-*.tar.gz; do
        [[ -f "$backup" ]] || continue
        local filename
        filename=$(basename "$backup")
        local size
        size=$(du -h "$backup" | cut -f1)
        local bkp_date
        bkp_date=$(stat -c %y "$backup" 2>/dev/null | cut -d'.' -f1 || echo "unknown")
        printf "%-45s %10s %s\n" "$filename" "$size" "$bkp_date"
    done
}

restore_backup() {
    local backup_file="$1"

    if [[ ! -f "${backup_file}" ]]; then
        # Try relative to backup dir
        backup_file="${BACKUP_DIR}/${backup_file}"
    fi

    if [[ ! -f "${backup_file}" ]]; then
        log_error "Backup file not found: ${backup_file}"
        exit 1
    fi

    log_info "Restoring from: ${backup_file}"

    # Create temp directory
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "${temp_dir}"' EXIT

    # Extract archive
    tar -xzf "${backup_file}" -C "${temp_dir}"
    local backup_name
    backup_name=$(ls "${temp_dir}")
    local backup_path="${temp_dir}/${backup_name}"

    # Stop services
    log_info "Stopping services..."
    cd "${REPO_DIR}"
    docker compose down 2>/dev/null || true

    # Restore Pi-hole files
    log_info "Restoring Pi-hole configuration..."
    if [[ -d "${backup_path}/pihole" ]]; then
        # Start container briefly to restore
        docker compose --profile single-node up -d
        sleep 10

        for file in "${backup_path}"/pihole/*; do
            [[ -f "$file" ]] || continue
            local filename
            filename=$(basename "$file")
            docker cp "$file" "${CONTAINER}:/etc/pihole/${filename}" 2>/dev/null || true
        done

        # Restore dnsmasq
        if [[ -d "${backup_path}/dnsmasq.d" ]]; then
            for file in "${backup_path}"/dnsmasq.d/*; do
                [[ -f "$file" ]] || continue
                local dnsmasq_filename
                dnsmasq_filename=$(basename "$file")
                docker cp "$file" "${CONTAINER}:/etc/dnsmasq.d/${dnsmasq_filename}" 2>/dev/null || true
            done
        fi

        # Rebuild gravity
        log_info "Rebuilding gravity database..."
        docker exec "${CONTAINER}" pihole -g 2>/dev/null || true

        docker compose down
    fi

    # Restore .env if present
    if [[ -f "${backup_path}/env.backup" ]]; then
        log_warn "Environment file found in backup. Review ${backup_path}/env.backup manually."
    fi

    log_info "Restore complete. Start services with: make primary (or make secondary)"
}

# =============================================================================
# Main
# =============================================================================

main() {
    case "${1:-}" in
        --list)
            list_backups
            ;;
        --restore)
            if [[ -z "${2:-}" ]]; then
                log_error "Usage: $0 --restore <backup_file>"
                exit 1
            fi
            restore_backup "$2"
            ;;
        *)
            create_backup
            ;;
    esac
}

main "$@"
