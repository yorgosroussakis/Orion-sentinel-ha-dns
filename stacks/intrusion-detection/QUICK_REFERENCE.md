# CrowdSec Quick Reference Card 🚀

## 🎯 Most Common Commands

### Status & Monitoring
```bash
# Check if CrowdSec is running
docker ps | grep crowdsec

# View overall metrics
docker exec crowdsec cscli metrics

# View active bans (blocked IPs)
docker exec crowdsec cscli decisions list

# View recent alerts (detected attacks)
docker exec crowdsec cscli alerts list

# Check bouncer connection
docker exec crowdsec cscli bouncers list
```

### Managing Decisions (Bans)

```bash
# List all blocked IPs
docker exec crowdsec cscli decisions list

# Get details about a specific IP
docker exec crowdsec cscli decisions list --ip 1.2.3.4

# Manually ban an IP for 4 hours
docker exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 4h --reason "Manual ban"

# Unban an IP
docker exec crowdsec cscli decisions delete --ip 1.2.3.4

# Whitelist an IP (never ban)
docker exec crowdsec cscli decisions add --ip 192.168.8.0/24 --type whitelist --reason "Local network"
```

### Scenarios & Collections

```bash
# List installed scenarios
docker exec crowdsec cscli scenarios list

# List available scenarios (not installed)
docker exec crowdsec cscli scenarios list -a

# Install a new scenario
docker exec crowdsec cscli scenarios install crowdsecurity/wordpress

# List installed collections
docker exec crowdsec cscli collections list

# Install a collection
docker exec crowdsec cscli collections install crowdsecurity/apache2

# Upgrade all scenarios and collections
docker exec crowdsec cscli hub update
docker exec crowdsec cscli hub upgrade
```

### Logs & Debugging

```bash
# View CrowdSec logs (last 50 lines)
docker logs crowdsec --tail 50

# Follow logs in real-time
docker logs -f crowdsec

# View firewall bouncer logs
docker logs crowdsec-firewall-bouncer --tail 50

# Check what logs are being parsed
docker exec crowdsec cscli metrics show acquisitions
```

### Service Management

```bash
# Start the stack
docker compose up -d

# Stop the stack
docker compose down

# Restart CrowdSec
docker compose restart crowdsec

# Restart firewall bouncer
docker compose restart crowdsec-firewall-bouncer

# View service status
docker compose ps
```

## 🔍 Useful One-Liners

```bash
# Count currently blocked IPs
docker exec crowdsec cscli decisions list -o json | jq '. | length'

# Show top 10 countries of blocked IPs
docker exec crowdsec cscli decisions list -o json | jq -r '.[].origin' | sort | uniq -c | sort -rn | head -10

# List bans from last hour
docker exec crowdsec cscli decisions list --since 1h

# Check if a specific IP is banned
docker exec crowdsec cscli decisions list --ip 1.2.3.4 || echo "Not banned"

# Get alert details
docker exec crowdsec cscli alerts inspect <alert_id>

# Export decisions to JSON
docker exec crowdsec cscli decisions list -o json > decisions_backup.json
```

## 🚨 Testing Protection

### Test SSH Protection
```bash
# From another machine, try wrong password 5+ times
ssh wronguser@your-pi-ip

# Then check if you got banned
docker exec crowdsec cscli decisions list --ip <your-test-ip>
```

### Simulate HTTP Attack
```bash
# Try suspicious URL patterns
curl "http://your-pi/admin?id=1' OR '1'='1"
curl "http://your-pi/../../../etc/passwd"

# Check alerts
docker exec crowdsec cscli alerts list
```

### View Firewall Rules
```bash
# Check iptables rules created by CrowdSec
sudo iptables -L -n -v | grep crowdsec

# Check nftables rules
sudo nft list ruleset | grep crowdsec
```

## 📊 Prometheus Metrics Endpoints

```bash
# CrowdSec metrics
curl http://localhost:6060/metrics

# View specific metrics
curl http://localhost:6060/metrics | grep cs_active_decisions
curl http://localhost:6060/metrics | grep cs_alerts
```

## 🔧 Configuration Files

### Important Files
```
stacks/intrusion-detection/
├── .env                          # API keys and settings
├── docker-compose.yml            # Service definitions
├── acquis/acquis.yaml           # Log sources to monitor
├── config/                      # CrowdSec configuration
└── setup-crowdsec.sh            # Setup script
```

### Edit Configuration
```bash
# Edit log sources
nano acquis/acquis.yaml

# Edit environment variables
nano .env

# Apply changes
docker compose restart crowdsec
```

## 🎯 Common Scenarios

### I Locked Myself Out
```bash
# Unban your IP
docker exec crowdsec cscli decisions delete --ip YOUR_IP

# Whitelist yourself permanently
docker exec crowdsec cscli decisions add --ip YOUR_IP --type whitelist --reason "My IP"
```

### Too Many False Positives
```bash
# Disable aggressive scenario
docker exec crowdsec cscli scenarios remove crowdsecurity/ssh-bf

# Or adjust thresholds in scenario config
```

### Want More Protection
```bash
# Install additional collections
docker exec crowdsec cscli collections install crowdsecurity/http-cve
docker exec crowdsec cscli collections install crowdsecurity/wordpress
docker exec crowdsec cscli collections install crowdsecurity/apache2

# Restart to apply
docker compose restart crowdsec
```

### Check Resource Usage
```bash
# Overall system resources
htop

# Docker container resources
docker stats crowdsec crowdsec-firewall-bouncer

# Memory usage
free -h

# CPU usage
top -bn1 | grep "Cpu(s)"
```

## 📈 Grafana Dashboard

### Import CrowdSec Dashboard
1. Go to Grafana: http://192.168.8.250:3000
2. Click "+" → Import
3. Enter Dashboard ID: **15174**
4. Select Prometheus data source
5. Click Import

### View Metrics
- Active Decisions (blocked IPs)
- Alert History
- Top Scenarios
- Parser Performance
- Bouncer Activity

## 🆘 Troubleshooting

### CrowdSec Not Starting
```bash
# Check logs for errors
docker logs crowdsec

# Verify volumes are accessible
ls -la /var/log/pihole
ls -la /var/log/auth.log

# Check configuration
docker exec crowdsec cscli config show
```

### No Logs Being Parsed
```bash
# Check acquisition metrics
docker exec crowdsec cscli metrics show acquisitions

# Verify log file permissions
docker exec crowdsec ls -la /var/log/pihole
docker exec crowdsec cat /etc/crowdsec/acquis.d/acquis.yaml
```

### Bouncer Not Blocking
```bash
# Check bouncer status
docker exec crowdsec cscli bouncers list

# Verify API key in .env matches bouncer registration
docker exec crowdsec cscli bouncers list
cat .env | grep CROWDSEC_BOUNCER_KEY_FIREWALL

# Check firewall rules
sudo iptables -L -n -v
```

## 🔗 Quick Links

- **CrowdSec Hub**: https://hub.crowdsec.net/
- **Documentation**: https://docs.crowdsec.net/
- **Console**: https://app.crowdsec.net/ (optional enrollment)
- **Community**: https://discord.gg/crowdsec

## 📝 Notes

- Default ban duration: 4 hours
- Decisions are local unless enrolled in CrowdSec Console
- Metrics updated every 10 seconds
- Logs rotated automatically
- Bouncer connects to CrowdSec via local API on port 8080

---

**Tip**: Bookmark this page for quick access to common commands!
