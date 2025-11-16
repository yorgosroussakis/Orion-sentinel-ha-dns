# Alert Configuration Guide

## Overview

The RPi HA DNS Stack includes a **comprehensive alert system** that sends notifications to your Signal account. You have **full control** over which alerts you receive and how frequently.

## 🎛️ Alert Types

### Critical Alerts (Immediate attention required)

| Alert Type | Default | Description |
|------------|---------|-------------|
| `database_corruption` | ✅ Enabled | Pi-hole database integrity failure |
| `keepalived_failover` | ✅ Enabled | VIP failed over to backup node |

### High Priority Alerts

| Alert Type | Default | Description |
|------------|---------|-------------|
| `container_failure` | ✅ Enabled | Container crashed or stopped |
| `disk_space_critical` | ✅ Enabled | Disk usage >90% |
| `backup_failure` | ✅ Enabled | Backup creation failed |
| `network_failure` | ✅ Enabled | Network connectivity lost |

### Medium Priority Alerts

| Alert Type | Default | Description |
|------------|---------|-------------|
| `container_restart` | ✅ Enabled | Container auto-restarted |
| `disk_space_high` | ✅ Enabled | Disk usage >85% |
| `memory_leak` | ✅ Enabled | High memory usage detected |
| `update_failure` | ✅ Enabled | Blocklist update failed |
| `sync_failure` | ✅ Enabled | Configuration sync failed |
| `system_recovery` | ✅ Enabled | System auto-recovered from failure |

### Low Priority Alerts (Informational)

| Alert Type | Default | Description |
|------------|---------|-------------|
| `backup_success` | ❌ Disabled | Backup completed successfully |
| `update_success` | ❌ Disabled | Blocklist update succeeded |
| `health_check_pass` | ❌ Disabled | Health check passed |

## 🔔 Alert Frequencies

Choose how often you want to receive each alert type:

| Frequency | Description | Use Case |
|-----------|-------------|----------|
| **Immediate** | No rate limiting | Critical issues that need instant attention |
| **Every 5 minutes** | Max 1 alert per 5 min | Frequent but non-critical issues |
| **Every 15 minutes** | Max 1 alert per 15 min | Regular monitoring |
| **Hourly** | Max 1 alert per hour | Periodic status updates |
| **Every 4 hours** | Max 1 alert per 4 hours | Less urgent notifications |
| **Daily** | Max 1 alert per day | Summary notifications |
| **Weekly** | Max 1 alert per week | Long-term trends |
| **Never** | Alerts disabled | Use for alerts you don't want |

## 🚀 Quick Setup

### Step 1: Configure Signal

```bash
# Edit your .env file
nano .env

# Add your Signal credentials
SIGNAL_NUMBER=+1234567890         # Your registered Signal number
SIGNAL_RECIPIENTS=+1234567890     # Who receives alerts (can be multiple, comma-separated)
```

### Step 2: Configure Alert Preferences

```bash
# Run the interactive alert configuration
bash scripts/alert-manager.sh --configure
```

### Step 3: Test Your Configuration

```bash
# Send a test alert
bash scripts/alert-manager.sh --test
```

## 📱 Interactive Configuration

The alert manager provides an easy-to-use menu interface:

```
╔═══════════════════════════════════════════════════════════════╗
║                Alert Configuration Manager                    ║
╚═══════════════════════════════════════════════════════════════╝

Current Alert Configuration:

 1. backup_failure           ✓  high        immediate
 2. backup_success           ✗  low         daily
 3. container_failure        ✓  high        immediate
 4. container_restart        ✓  medium      immediate
 5. database_corruption      ✓  critical    immediate
 6. disk_space_critical      ✓  high        immediate
 7. disk_space_high          ✓  medium      hourly
 8. health_check_pass        ✗  info        never
 9. keepalived_failover      ✓  critical    immediate
10. memory_leak              ✓  medium      hourly
11. network_failure          ✓  high        immediate
12. sync_failure             ✓  medium      hourly
13. system_recovery          ✓  medium      immediate
14. update_failure           ✓  medium      immediate
15. update_success           ✗  low         daily

Options:
  1-15) Configure specific alert
  a) Enable all critical alerts
  b) Enable only critical/high alerts
  c) Custom frequency for all
  d) Disable all non-critical alerts
  s) Show current configuration
  t) Test alert system
  q) Save and quit
```

## 🎨 Configuration Examples

### Example 1: Minimal Alerts (Critical Only)

Only receive alerts for critical failures:

```bash
bash scripts/alert-manager.sh --configure
# Then select: b) Enable only critical/high alerts
```

This enables:
- database_corruption
- keepalived_failover
- container_failure
- disk_space_critical
- backup_failure
- network_failure

### Example 2: Business Hours Only

Receive immediate alerts during work hours, daily summaries otherwise:

1. Configure immediate alerts for working hours
2. Set non-critical alerts to "daily"
3. Configure your phone's Do Not Disturb for off-hours

### Example 3: Maximum Monitoring

Receive all alerts immediately:

```bash
bash scripts/alert-manager.sh --configure
# Select: a) Enable all critical alerts
# Then: c) Custom frequency for all → 1) Immediate
```

### Example 4: Weekend Warrior

Only critical alerts, but grouped:

```bash
bash scripts/alert-manager.sh --configure
# For each alert:
#   - Critical/High: immediate
#   - Medium: hourly
#   - Low: daily or disabled
```

## 🔧 Manual Configuration

You can also edit the configuration file directly:

```bash
# Edit configuration
nano /config/alert-config.json
```

Configuration format:

```json
{
  "container_failure": {
    "enabled": true,
    "severity": "high",
    "frequency": "immediate"
  },
  "backup_success": {
    "enabled": false,
    "severity": "low",
    "frequency": "daily"
  }
}
```

## 📊 Alert Format

Alerts sent to Signal include:

```
🚨 **RPi HA DNS Alert**

**Type:** database_corruption
**Severity:** critical
**Time:** 2024-11-16 14:30:45

Database corruption detected in pihole_primary!
Automatically restoring from latest backup...

---
_Automated alert from RPi HA DNS Stack_
```

## 🎯 Recommended Configurations

### For Home Users

**Goal:** Know about problems, but not overwhelmed

```
Critical/High:  immediate
Medium:         hourly
Low:            disabled
Success:        disabled
```

### For IT Professionals

**Goal:** Full visibility, manageable frequency

```
Critical:       immediate
High:           immediate
Medium:         every_15min
Low:            hourly
Success:        daily
```

### For Business/Production

**Goal:** Maximum reliability, minimal disruption

```
Critical:       immediate
High:           immediate
Medium:         hourly
Low:            daily
Success:        weekly
```

### For Testing/Development

**Goal:** See everything

```
All:            immediate
```

## 📱 Multiple Recipients

Send alerts to multiple people:

```bash
# In .env
SIGNAL_RECIPIENTS=+1234567890,+0987654321,+1122334455
```

Each recipient receives the same alerts based on your configuration.

## 🔇 Quiet Hours

While the alert system doesn't have built-in quiet hours, you can:

1. **Use Signal's Do Not Disturb**
   - Configure in Signal app
   - Allows exceptions for critical contacts

2. **Use Frequency Limits**
   - Set non-critical alerts to "daily"
   - They'll arrive at next check, not immediately

3. **Disable Temporarily**
   ```bash
   # Disable in .env
   SIGNAL_RECIPIENTS=
   ```

## 🧪 Testing

### Test Single Alert

```bash
# Send test alert
bash scripts/alert-manager.sh --test
```

### Test Specific Alert Type

```bash
# Send specific alert
bash scripts/alert-manager.sh --send "container_failure" "Test container failure alert" "high"
```

### Test Frequency Limiting

```bash
# Send same alert twice quickly
bash scripts/alert-manager.sh --send "test_alert" "First test" "medium"
sleep 5
bash scripts/alert-manager.sh --send "test_alert" "Second test" "medium"

# If frequency is not "immediate", second alert won't send
```

## 📋 Configuration File Location

**Default:** `/config/alert-config.json`

**Custom location:**
```bash
# In .env or docker-compose.yml
ALERT_CONFIG_FILE=/path/to/custom/alert-config.json
```

## 🔍 Troubleshooting

### Not Receiving Alerts

1. **Check Signal Configuration**
   ```bash
   echo $SIGNAL_NUMBER
   echo $SIGNAL_RECIPIENTS
   ```

2. **Test Signal API**
   ```bash
   bash scripts/alert-manager.sh --test
   ```

3. **Check Alert Configuration**
   ```bash
   cat /config/alert-config.json
   ```

4. **Verify Alert is Enabled**
   ```bash
   jq '.container_failure.enabled' /config/alert-config.json
   ```

### Too Many Alerts

1. **Increase Frequency Limits**
   - Change "immediate" to "hourly" for medium-priority alerts

2. **Disable Low-Priority Alerts**
   ```bash
   bash scripts/alert-manager.sh --configure
   # Select: d) Disable all non-critical alerts
   ```

3. **Review Configuration**
   ```bash
   bash scripts/alert-manager.sh --configure
   # Select: s) Show current configuration
   ```

### Alert Sent But Not Received

1. **Check Signal App**
   - Is the app running?
   - Is the number registered?

2. **Check Signal API Container**
   ```bash
   docker logs signal-cli-rest-api
   ```

3. **Verify Network**
   ```bash
   curl -X GET http://signal-cli-rest-api:8080/v1/about
   ```

## 💡 Pro Tips

### Tip 1: Start Conservative

Begin with only critical/high alerts enabled. Add more as you learn what's useful.

### Tip 2: Use Frequency Wisely

Set critical alerts to "immediate", but use "hourly" for things that happen frequently (like disk space warnings).

### Tip 3: Group Similar Alerts

If multiple alerts trigger together (e.g., disk space high → cleanup → success), the frequency limit prevents spam.

### Tip 4: Test Your Configuration

After any changes, send a test alert to verify it works.

### Tip 5: Document Your Choices

Keep notes on why you configured alerts a certain way. Future you will thank you!

## 📚 Advanced Usage

### Custom Alert Scripts

Create custom alerts for your own monitoring:

```bash
#!/bin/bash
# custom-monitor.sh

if some_condition; then
    bash /scripts/alert-manager.sh --send \
        "custom_alert" \
        "Custom condition detected!" \
        "medium"
fi
```

### Integration with Other Services

The alert manager can be called from any script:

```bash
# From cron job
bash /path/to/alert-manager.sh --send "backup" "Backup completed" "low"

# From monitoring script
bash /path/to/alert-manager.sh --send "service_check" "Service down" "high"
```

### Alert Analytics

Track alert frequency:

```bash
# Count alerts by type
jq 'keys[] as $k | "\($k): \(.[$k])"' /tmp/alert-state.json
```

## 🎉 Summary

**Alert system features:**
- ✅ 15 alert types
- ✅ 8 frequency options
- ✅ Interactive configuration
- ✅ Signal integration
- ✅ Rate limiting
- ✅ Multiple recipients
- ✅ Custom severity levels
- ✅ Easy testing

**You control:**
- Which alerts you receive
- How often you receive them
- Who receives them
- When they're sent

**Start with defaults, customize as needed!**

---

**Configuration Tool:** `scripts/alert-manager.sh`  
**Configuration File:** `/config/alert-config.json`  
**Documentation:** This guide

**Happy alerting!** 📱
