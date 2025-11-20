#!/usr/bin/env bash
# Alert Manager for Signal Notifications
# Allows users to configure alert types and frequencies

set -u

# Alert Configuration
ALERT_CONFIG_FILE="${ALERT_CONFIG_FILE:-/config/alert-config.json}"
ALERT_STATE_FILE="${ALERT_STATE_FILE:-/tmp/alert-state.json}"
SIGNAL_API_URL="${SIGNAL_API_URL:-http://signal-cli-rest-api:8080}"
SIGNAL_NUMBER="${SIGNAL_NUMBER:-}"
SIGNAL_RECIPIENTS="${SIGNAL_RECIPIENTS:-}"

# Alert types and their default settings
declare -A ALERT_TYPES=(
    ["container_failure"]="enabled:high:immediate"
    ["container_restart"]="enabled:medium:immediate"
    ["database_corruption"]="enabled:critical:immediate"
    ["disk_space_high"]="enabled:medium:hourly"
    ["disk_space_critical"]="enabled:high:immediate"
    ["memory_leak"]="enabled:medium:hourly"
    ["backup_success"]="disabled:low:daily"
    ["backup_failure"]="enabled:high:immediate"
    ["update_success"]="disabled:low:daily"
    ["update_failure"]="enabled:medium:immediate"
    ["sync_failure"]="enabled:medium:hourly"
    ["network_failure"]="enabled:high:immediate"
    ["keepalived_failover"]="enabled:critical:immediate"
    ["health_check_pass"]="disabled:info:never"
    ["system_recovery"]="enabled:medium:immediate"
)

# Alert frequency limits (in seconds)
declare -A FREQUENCY_LIMITS=(
    ["immediate"]=0
    ["every_5min"]=300
    ["every_15min"]=900
    ["hourly"]=3600
    ["every_4hours"]=14400
    ["daily"]=86400
    ["weekly"]=604800
    ["never"]=999999999
)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }
info() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }
err() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }

# Initialize alert configuration
init_alert_config() {
    if [ ! -f "$ALERT_CONFIG_FILE" ]; then
        log "Creating default alert configuration..."
        mkdir -p "$(dirname "$ALERT_CONFIG_FILE")"
        
        cat > "$ALERT_CONFIG_FILE" << 'EOF'
{
  "container_failure": {"enabled": true, "severity": "high", "frequency": "immediate"},
  "container_restart": {"enabled": true, "severity": "medium", "frequency": "immediate"},
  "database_corruption": {"enabled": true, "severity": "critical", "frequency": "immediate"},
  "disk_space_high": {"enabled": true, "severity": "medium", "frequency": "hourly"},
  "disk_space_critical": {"enabled": true, "severity": "high", "frequency": "immediate"},
  "memory_leak": {"enabled": true, "severity": "medium", "frequency": "hourly"},
  "backup_success": {"enabled": false, "severity": "low", "frequency": "daily"},
  "backup_failure": {"enabled": true, "severity": "high", "frequency": "immediate"},
  "update_success": {"enabled": false, "severity": "low", "frequency": "daily"},
  "update_failure": {"enabled": true, "severity": "medium", "frequency": "immediate"},
  "sync_failure": {"enabled": true, "severity": "medium", "frequency": "hourly"},
  "network_failure": {"enabled": true, "severity": "high", "frequency": "immediate"},
  "keepalived_failover": {"enabled": true, "severity": "critical", "frequency": "immediate"},
  "health_check_pass": {"enabled": false, "severity": "info", "frequency": "never"},
  "system_recovery": {"enabled": true, "severity": "medium", "frequency": "immediate"}
}
EOF
        log "✓ Default alert configuration created"
    fi
    
    # Initialize state file
    if [ ! -f "$ALERT_STATE_FILE" ]; then
        echo "{}" > "$ALERT_STATE_FILE"
    fi
}

# Check if alert should be sent based on frequency limit
should_send_alert() {
    local alert_type="$1"
    local current_time=$(date +%s)
    
    # Get alert configuration
    local enabled=$(jq -r ".${alert_type}.enabled // true" "$ALERT_CONFIG_FILE" 2>/dev/null || echo "true")
    local frequency=$(jq -r ".${alert_type}.frequency // \"immediate\"" "$ALERT_CONFIG_FILE" 2>/dev/null || echo "immediate")
    
    # Check if alert is enabled
    if [ "$enabled" != "true" ]; then
        return 1
    fi
    
    # Get frequency limit
    local limit=${FREQUENCY_LIMITS[$frequency]:-0}
    
    # Immediate alerts always send
    if [ "$limit" -eq 0 ]; then
        return 0
    fi
    
    # Check last sent time
    local last_sent=$(jq -r ".${alert_type} // 0" "$ALERT_STATE_FILE" 2>/dev/null || echo "0")
    local time_since=$((current_time - last_sent))
    
    if [ "$time_since" -ge "$limit" ]; then
        # Update last sent time
        jq ". + {\"${alert_type}\": ${current_time}}" "$ALERT_STATE_FILE" > "${ALERT_STATE_FILE}.tmp"
        mv "${ALERT_STATE_FILE}.tmp" "$ALERT_STATE_FILE"
        return 0
    fi
    
    return 1
}

# Send alert via Signal
send_signal_alert() {
    local alert_type="$1"
    local message="$2"
    local severity="${3:-medium}"
    
    # Check if Signal is configured
    if [ -z "$SIGNAL_NUMBER" ] || [ -z "$SIGNAL_RECIPIENTS" ]; then
        return 0
    fi
    
    # Check if alert should be sent
    if ! should_send_alert "$alert_type"; then
        return 0
    fi
    
    # Get emoji for severity
    local icon
    case "$severity" in
        critical) icon="🚨" ;;
        high) icon="❌" ;;
        medium) icon="⚠️" ;;
        low) icon="ℹ️" ;;
        info) icon="✅" ;;
        *) icon="📢" ;;
    esac
    
    # Format message with timestamp
    local formatted_message="${icon} **RPi HA DNS Alert**

**Type:** ${alert_type}
**Severity:** ${severity}
**Time:** $(date '+%Y-%m-%d %H:%M:%S')

${message}

---
_Automated alert from RPi HA DNS Stack_"
    
    # Send to each recipient
    IFS=',' read -ra RECIPIENTS <<< "$SIGNAL_RECIPIENTS"
    for recipient in "${RECIPIENTS[@]}"; do
        recipient=$(echo "$recipient" | xargs) # trim whitespace
        
        curl -X POST "$SIGNAL_API_URL/v2/send" \
            -H "Content-Type: application/json" \
            -d "{
                \"message\": $(echo "$formatted_message" | jq -Rs .),
                \"number\": \"$SIGNAL_NUMBER\",
                \"recipients\": [\"$recipient\"]
            }" 2>/dev/null || true
    done
    
    log "✓ Alert sent: $alert_type ($severity)"
}

# Interactive configuration menu
configure_alerts() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                Alert Configuration Manager                    ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${BLUE}Current Alert Configuration:${NC}"
    echo ""
    
    # Display current config
    local counter=1
    for alert_type in "${!ALERT_TYPES[@]}"; do
        local enabled=$(jq -r ".${alert_type}.enabled // true" "$ALERT_CONFIG_FILE" 2>/dev/null || echo "true")
        local severity=$(jq -r ".${alert_type}.severity // \"medium\"" "$ALERT_CONFIG_FILE" 2>/dev/null || echo "medium")
        local frequency=$(jq -r ".${alert_type}.frequency // \"immediate\"" "$ALERT_CONFIG_FILE" 2>/dev/null || echo "immediate")
        
        local status_icon
        if [ "$enabled" = "true" ]; then
            status_icon="${GREEN}✓${NC}"
        else
            status_icon="${RED}✗${NC}"
        fi
        
        printf "%2d. %-25s %s  %-10s  %-15s\n" \
            "$counter" \
            "$alert_type" \
            "$status_icon" \
            "$severity" \
            "$frequency"
        
        counter=$((counter + 1))
    done | sort -k2
    
    echo ""
    echo -e "${CYAN}Options:${NC}"
    echo "  1-15) Configure specific alert"
    echo "  a) Enable all critical alerts"
    echo "  b) Enable only critical/high alerts"
    echo "  c) Custom frequency for all"
    echo "  d) Disable all non-critical alerts"
    echo "  s) Show current configuration"
    echo "  t) Test alert system"
    echo "  q) Save and quit"
    echo ""
    
    read -r -p "Select option: " choice
    
    case "$choice" in
        [1-9]|1[0-5])
            configure_single_alert "$choice"
            ;;
        a)
            enable_critical_alerts
            ;;
        b)
            enable_high_severity_only
            ;;
        c)
            set_global_frequency
            ;;
        d)
            disable_non_critical
            ;;
        s)
            show_full_configuration
            ;;
        t)
            test_alert_system
            ;;
        q)
            log "Configuration saved!"
            return 0
            ;;
        *)
            warn "Invalid option"
            sleep 2
            ;;
    esac
    
    configure_alerts
}

# Configure single alert
configure_single_alert() {
    local index="$1"
    local alert_type=$(echo "${!ALERT_TYPES[@]}" | tr ' ' '\n' | sort | sed -n "${index}p")
    
    if [ -z "$alert_type" ]; then
        err "Invalid selection"
        sleep 2
        return
    fi
    
    clear
    echo -e "${CYAN}Configuring: $alert_type${NC}"
    echo ""
    
    # Enable/Disable
    echo "Enable this alert?"
    echo "  1) Yes"
    echo "  2) No"
    read -r -p "Choice: " enable_choice
    
    local enabled="true"
    if [ "$enable_choice" = "2" ]; then
        enabled="false"
    fi
    
    # Severity
    echo ""
    echo "Alert severity:"
    echo "  1) Critical"
    echo "  2) High"
    echo "  3) Medium"
    echo "  4) Low"
    echo "  5) Info"
    read -r -p "Choice (1-5): " sev_choice
    
    local severity="medium"
    case "$sev_choice" in
        1) severity="critical" ;;
        2) severity="high" ;;
        3) severity="medium" ;;
        4) severity="low" ;;
        5) severity="info" ;;
    esac
    
    # Frequency
    echo ""
    echo "Alert frequency:"
    echo "  1) Immediate (no limit)"
    echo "  2) Every 5 minutes"
    echo "  3) Every 15 minutes"
    echo "  4) Hourly"
    echo "  5) Every 4 hours"
    echo "  6) Daily"
    echo "  7) Weekly"
    echo "  8) Never"
    read -r -p "Choice (1-8): " freq_choice
    
    local frequency="immediate"
    case "$freq_choice" in
        1) frequency="immediate" ;;
        2) frequency="every_5min" ;;
        3) frequency="every_15min" ;;
        4) frequency="hourly" ;;
        5) frequency="every_4hours" ;;
        6) frequency="daily" ;;
        7) frequency="weekly" ;;
        8) frequency="never" ;;
    esac
    
    # Update configuration
    jq ". + {\"${alert_type}\": {\"enabled\": $enabled, \"severity\": \"$severity\", \"frequency\": \"$frequency\"}}" \
        "$ALERT_CONFIG_FILE" > "${ALERT_CONFIG_FILE}.tmp"
    mv "${ALERT_CONFIG_FILE}.tmp" "$ALERT_CONFIG_FILE"
    
    log "✓ Alert configured: $alert_type"
    sleep 2
}

# Enable only critical alerts
enable_critical_alerts() {
    log "Enabling all critical alerts..."
    
    for alert_type in "database_corruption" "keepalived_failover" "network_failure"; do
        jq ".${alert_type}.enabled = true" "$ALERT_CONFIG_FILE" > "${ALERT_CONFIG_FILE}.tmp"
        mv "${ALERT_CONFIG_FILE}.tmp" "$ALERT_CONFIG_FILE"
    done
    
    log "✓ Critical alerts enabled"
    sleep 2
}

# Enable only high/critical severity alerts
enable_high_severity_only() {
    log "Enabling only high and critical severity alerts..."
    
    for alert_type in "${!ALERT_TYPES[@]}"; do
        local severity=$(jq -r ".${alert_type}.severity // \"medium\"" "$ALERT_CONFIG_FILE")
        if [ "$severity" = "critical" ] || [ "$severity" = "high" ]; then
            jq ".${alert_type}.enabled = true" "$ALERT_CONFIG_FILE" > "${ALERT_CONFIG_FILE}.tmp"
            mv "${ALERT_CONFIG_FILE}.tmp" "$ALERT_CONFIG_FILE"
        else
            jq ".${alert_type}.enabled = false" "$ALERT_CONFIG_FILE" > "${ALERT_CONFIG_FILE}.tmp"
            mv "${ALERT_CONFIG_FILE}.tmp" "$ALERT_CONFIG_FILE"
        fi
    done
    
    log "✓ Only high/critical alerts enabled"
    sleep 2
}

# Set global frequency
set_global_frequency() {
    echo ""
    echo "Set frequency for all enabled alerts:"
    echo "  1) Immediate"
    echo "  2) Every 5 minutes"
    echo "  3) Hourly"
    echo "  4) Daily"
    read -r -p "Choice: " choice
    
    local frequency="immediate"
    case "$choice" in
        1) frequency="immediate" ;;
        2) frequency="every_5min" ;;
        3) frequency="hourly" ;;
        4) frequency="daily" ;;
    esac
    
    for alert_type in "${!ALERT_TYPES[@]}"; do
        jq ".${alert_type}.frequency = \"$frequency\"" "$ALERT_CONFIG_FILE" > "${ALERT_CONFIG_FILE}.tmp"
        mv "${ALERT_CONFIG_FILE}.tmp" "$ALERT_CONFIG_FILE"
    done
    
    log "✓ Global frequency set to: $frequency"
    sleep 2
}

# Disable non-critical alerts
disable_non_critical() {
    log "Disabling non-critical alerts..."
    
    for alert_type in "${!ALERT_TYPES[@]}"; do
        local severity=$(jq -r ".${alert_type}.severity // \"medium\"" "$ALERT_CONFIG_FILE")
        if [ "$severity" != "critical" ] && [ "$severity" != "high" ]; then
            jq ".${alert_type}.enabled = false" "$ALERT_CONFIG_FILE" > "${ALERT_CONFIG_FILE}.tmp"
            mv "${ALERT_CONFIG_FILE}.tmp" "$ALERT_CONFIG_FILE"
        fi
    done
    
    log "✓ Non-critical alerts disabled"
    sleep 2
}

# Show full configuration
show_full_configuration() {
    clear
    echo -e "${CYAN}Complete Alert Configuration:${NC}"
    echo ""
    jq . "$ALERT_CONFIG_FILE"
    echo ""
    read -r -p "Press Enter to continue..."
}

# Test alert system
test_alert_system() {
    log "Testing alert system..."
    
    if [ -z "$SIGNAL_NUMBER" ] || [ -z "$SIGNAL_RECIPIENTS" ]; then
        err "Signal not configured!"
        err "Set SIGNAL_NUMBER and SIGNAL_RECIPIENTS environment variables"
        read -r -p "Press Enter to continue..."
        return
    fi
    
    # Send test alert
    send_signal_alert "test_alert" "This is a test alert from your RPi HA DNS Stack. If you received this, your alert system is working correctly!" "info"
    
    log "✓ Test alert sent!"
    log "Check your Signal app for the message"
    read -r -p "Press Enter to continue..."
}

# Main menu
main() {
    init_alert_config
    
    if [ "${1:-}" = "--configure" ]; then
        configure_alerts
    elif [ "${1:-}" = "--send" ]; then
        # Send alert from command line
        local alert_type="${2:-test_alert}"
        local message="${3:-Test alert}"
        local severity="${4:-medium}"
        send_signal_alert "$alert_type" "$message" "$severity"
    elif [ "${1:-}" = "--test" ]; then
        test_alert_system
    else
        echo "Usage:"
        echo "  $0 --configure          Interactive configuration"
        echo "  $0 --send TYPE MSG SEV  Send an alert"
        echo "  $0 --test               Test alert system"
        echo ""
        echo "Environment variables:"
        echo "  ALERT_CONFIG_FILE       Path to config file"
        echo "  SIGNAL_NUMBER           Your Signal phone number"
        echo "  SIGNAL_RECIPIENTS       Comma-separated recipients"
        echo "  SIGNAL_API_URL          Signal API endpoint"
    fi
}

main "$@"
