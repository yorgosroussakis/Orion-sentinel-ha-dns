#!/usr/bin/env bash
# Security and Vulnerability Scanner for RPi HA DNS Stack
# Uses Trivy to scan all Docker images and generate reports

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
info() { echo -e "${BLUE}[i]${NC} $*"; }
section() { echo -e "\n${CYAN}${BOLD}═══ $* ═══${NC}\n"; }

show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    RPi HA DNS Stack - Security & Vulnerability Scanner       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_trivy() {
    if ! command -v trivy &> /dev/null; then
        if ! docker ps --filter "name=trivy-server" --format "{{.Names}}" | grep -q trivy-server; then
            err "Trivy not found. Please install or run: docker compose -f stacks/management/docker-compose.yml up -d trivy-server"
            exit 1
        fi
        TRIVY_CMD="docker exec trivy-server trivy"
    else
        TRIVY_CMD="trivy"
    fi
    log "Using Trivy: $TRIVY_CMD"
}

scan_image() {
    local image=$1
    local severity=${2:-HIGH,CRITICAL}
    
    info "Scanning: $image"
    
    $TRIVY_CMD image \
        --severity "$severity" \
        --format table \
        "$image" || warn "Scan failed for $image"
}

scan_all_running() {
    section "Scanning All Running Containers"
    
    local images
    images=$(docker ps --format '{{.Image}}' | sort -u)
    
    if [[ -z "$images" ]]; then
        warn "No running containers found"
        return
    fi
    
    local count=0
    while IFS= read -r image; do
        ((count++))
        scan_image "$image" "HIGH,CRITICAL"
        echo ""
    done <<< "$images"
    
    log "Scanned $count unique images"
}

scan_stack_images() {
    section "Scanning Stack Images"
    
    local stack_images=(
        "pihole/pihole:latest"
        "klutchell/unbound:latest"
        "osixia/keepalived:2.0.20"
        "prom/prometheus:latest"
        "grafana/grafana:latest"
        "aquasec/trivy:latest"
        "netdata/netdata:latest"
        "louislam/uptime-kuma:latest"
        "portainer/portainer-ce:latest"
        "ghcr.io/gethomepage/homepage:latest"
    )
    
    for image in "${stack_images[@]}"; do
        scan_image "$image" "HIGH,CRITICAL"
        echo ""
    done
}

generate_report() {
    section "Generating HTML Security Report"
    
    local report_dir="$REPO_ROOT/security-reports"
    local report_file="$report_dir/security-report-$(date +%Y%m%d-%H%M%S).html"
    
    mkdir -p "$report_dir"
    
    info "Generating comprehensive report..."
    
    {
        echo "<html><head><title>RPi HA DNS Stack Security Report</title>"
        echo "<style>body{font-family:Arial;margin:20px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ddd;padding:8px;text-align:left}th{background:#4CAF50;color:white}.critical{background:#f44336;color:white}.high{background:#ff9800;color:white}.medium{background:#ffeb3b}.low{background:#8bc34a}</style>"
        echo "</head><body>"
        echo "<h1>RPi HA DNS Stack - Security Report</h1>"
        echo "<p>Generated: $(date)</p>"
        echo "<hr>"
    } > "$report_file"
    
    local images
    images=$(docker ps --format '{{.Image}}' | sort -u)
    
    while IFS= read -r image; do
        echo "<h2>Image: $image</h2>" >> "$report_file"
        $TRIVY_CMD image \
            --format template \
            --template '@contrib/html.tpl' \
            "$image" >> "$report_file" 2>/dev/null || echo "<p>Scan failed</p>" >> "$report_file"
        echo "<hr>" >> "$report_file"
    done <<< "$images"
    
    echo "</body></html>" >> "$report_file"
    
    log "Report generated: $report_file"
}

scan_filesystem() {
    section "Scanning Filesystem for Secrets"
    
    info "Scanning repository for exposed secrets..."
    
    $TRIVY_CMD fs \
        --severity HIGH,CRITICAL \
        --scanners secret \
        "$REPO_ROOT" || warn "Filesystem scan completed with findings"
}

scan_config_files() {
    section "Scanning Configuration Files"
    
    info "Scanning for misconfigurations..."
    
    $TRIVY_CMD config \
        --severity HIGH,CRITICAL \
        "$REPO_ROOT/stacks" || warn "Configuration scan completed with findings"
}

show_summary() {
    section "Security Scan Summary"
    
    echo -e "${BOLD}Scan Complete${NC}"
    echo ""
    echo "Actions recommended:"
    echo "1. Review all CRITICAL and HIGH severity vulnerabilities"
    echo "2. Update images with: docker compose pull && docker compose up -d"
    echo "3. Check for exposed secrets in configuration files"
    echo "4. Review security best practices: $REPO_ROOT/VERSIONS.md"
    echo ""
    info "Schedule regular scans (weekly recommended)"
    echo ""
}

main() {
    show_banner
    
    local scan_type=${1:-all}
    
    check_trivy
    
    case "$scan_type" in
        running)
            scan_all_running
            ;;
        stack)
            scan_stack_images
            ;;
        report)
            generate_report
            ;;
        secrets)
            scan_filesystem
            ;;
        config)
            scan_config_files
            ;;
        full)
            scan_all_running
            scan_stack_images
            scan_filesystem
            scan_config_files
            generate_report
            ;;
        all|*)
            scan_all_running
            generate_report
            ;;
    esac
    
    show_summary
}

# Show usage if --help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [scan_type]"
    echo ""
    echo "Scan types:"
    echo "  running  - Scan all currently running containers (default)"
    echo "  stack    - Scan predefined stack images"
    echo "  report   - Generate HTML report for running containers"
    echo "  secrets  - Scan filesystem for exposed secrets"
    echo "  config   - Scan configuration files for misconfigurations"
    echo "  full     - Run all scans"
    echo "  all      - Scan running + generate report (default)"
    echo ""
    echo "Examples:"
    echo "  $0                # Scan running containers"
    echo "  $0 full           # Complete security audit"
    echo "  $0 report         # Generate HTML report only"
    exit 0
fi

main "$@"
