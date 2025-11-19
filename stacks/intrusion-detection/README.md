# Intrusion Detection System (CrowdSec) 🛡️

## Overview

This stack adds **CrowdSec**, a modern, collaborative intrusion detection and prevention system to your RPi HA DNS Stack. CrowdSec protects your Pi-hole, SSH, web services, and entire network from malicious actors by:

- 🌍 **Crowdsourced Intelligence**: Automatically blocks IPs that have attacked other CrowdSec users worldwide
- 🚀 **Lightweight**: Written in Go, uses minimal resources on Raspberry Pi
- 🔍 **Multi-Service Protection**: Monitors Pi-hole, SSH, Docker containers, and web services
- ⚡ **Real-time Blocking**: Automatically updates firewall rules to ban attackers
- 📊 **Observable**: Prometheus metrics integration for monitoring
- 🎯 **Scenario-Based**: Pre-built detection scenarios for common attacks

## Why CrowdSec over Fail2Ban?

| Feature | CrowdSec | Fail2Ban |
|---------|----------|----------|
| Intelligence | Global crowdsourced | Local only |
| Performance | Excellent (Go) | Good (Python) |
| Pi-hole Support | Native scenarios | Custom filters required |
| Proactive Protection | ✅ Blocks known attackers before they hit you | ❌ Reactive only |
| Container Native | ✅ Designed for Docker | ⚠️ Requires additional config |
| Community Updates | ✅ Automatic scenario updates | ❌ Manual updates |
| Resource Usage | Low (~50-100MB RAM) | Moderate (~100-150MB RAM) |

**Verdict**: CrowdSec is the modern, more powerful choice for containerized environments and benefits from collaborative threat intelligence.

## Features

### 🛡️ Protection Layers

1. **SSH Protection**: Blocks brute-force SSH attacks
2. **Pi-hole Protection**: Detects DNS amplification and abuse
3. **Web Service Protection**: Guards Grafana, Nginx Proxy Manager, and other web UIs
4. **Docker Container Monitoring**: Analyzes logs from all containers
5. **System-wide Protection**: Monitors system logs for suspicious activity

### 📊 Observability

- **Prometheus Metrics**: Exposed on port 6060 for Grafana dashboards
- **Real-time Alerts**: See blocked IPs and active decisions
- **Detailed Logs**: Track all security events
- **CrowdSec Console**: Optional cloud dashboard for advanced analytics

### 🔧 Components

- **CrowdSec Agent**: Main service that analyzes logs and makes decisions
- **Firewall Bouncer**: Automatically updates iptables/nftables to block malicious IPs
- **Optional Nginx Bouncer**: Protects web services at the application layer

## Quick Start

### Prerequisites

- Raspberry Pi 5 with 64-bit OS (CrowdSec requires 64-bit)
- Docker and Docker Compose installed
- Existing RPi HA DNS Stack running

### Installation

1. **Navigate to the intrusion detection stack:**
   ```bash
   cd /path/to/rpi-ha-dns-stack/stacks/intrusion-detection
   ```

2. **Run the setup script:**
   ```bash
   bash setup-crowdsec.sh
   ```

   This script will:
   - Create `.env` file from template
   - Start CrowdSec
   - Generate bouncer API keys
   - Install protection scenarios
   - Configure firewall bouncer

3. **Verify installation:**
   ```bash
   # Check CrowdSec status
   docker exec crowdsec cscli metrics
   
   # View active decisions (blocked IPs)
   docker exec crowdsec cscli decisions list
   
   # Check bouncer connection
   docker exec crowdsec cscli bouncers list
   ```

### Manual Installation

If you prefer manual setup:

1. **Copy environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Start CrowdSec:**
   ```bash
   docker compose up -d crowdsec
   ```

3. **Generate bouncer keys:**
   ```bash
   # Wait for CrowdSec to initialize
   sleep 30
   
   # Generate firewall bouncer key
   docker exec crowdsec cscli bouncers add firewall-bouncer -o raw
   ```

4. **Update `.env` file:**
   - Add the generated key to `CROWDSEC_BOUNCER_KEY_FIREWALL`

5. **Start firewall bouncer:**
   ```bash
   docker compose up -d crowdsec-firewall-bouncer
   ```

## Configuration

### Log Sources

CrowdSec monitors these logs (configured in `acquis/acquis.yaml`):

- Pi-hole logs: `/var/log/pihole/*.log`
- SSH logs: `/var/log/auth.log`
- Docker container logs
- Nginx logs (if present)
- System logs: `/var/log/syslog`

### Installed Scenarios

Default protection scenarios:

- `crowdsecurity/linux` - Linux system attacks
- `crowdsecurity/sshd` - SSH brute-force
- `crowdsecurity/nginx` - Web server attacks
- `crowdsecurity/http-cve` - HTTP exploit attempts
- `crowdsecurity/base-http-scenarios` - Common HTTP attacks
- `crowdsecurity/whitelist-good-actors` - Don't block legitimate services

### Adding More Scenarios

Browse available scenarios:
```bash
docker exec crowdsec cscli scenarios list -a
```

Install additional scenarios:
```bash
docker exec crowdsec cscli scenarios install crowdsecurity/wordpress
docker exec crowdsec cscli scenarios install crowdsecurity/ssh-bf
```

## Usage

### View Metrics

```bash
# Overall metrics
docker exec crowdsec cscli metrics

# Detailed metrics by component
docker exec crowdsec cscli metrics show acquisitions
docker exec crowdsec cscli metrics show scenarios
docker exec crowdsec cscli metrics show parsers
```

### Manage Blocked IPs

```bash
# List all active decisions (blocked IPs)
docker exec crowdsec cscli decisions list

# Get details about a specific IP
docker exec crowdsec cscli decisions list --ip 1.2.3.4

# Manually ban an IP
docker exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 4h --reason "Manual ban"

# Unban an IP
docker exec crowdsec cscli decisions delete --ip 1.2.3.4
```

### View Alerts

```bash
# List recent alerts (detected attacks)
docker exec crowdsec cscli alerts list

# Show detailed alert information
docker exec crowdsec cscli alerts inspect <alert_id>
```

### Test Protection

Simulate an SSH brute-force attack:
```bash
# From another machine, try multiple failed SSH logins
ssh baduser@your-pi-ip
ssh baduser@your-pi-ip
ssh baduser@your-pi-ip
# ... (try 5-10 times)

# Check if the attacker was banned
docker exec crowdsec cscli decisions list
```

## Integration with Observability Stack

### Prometheus Metrics

CrowdSec exposes Prometheus metrics on port 6060. Add this to your Prometheus configuration:

```yaml
# Add to stacks/observability/prometheus/prometheus.yml
scrape_configs:
  - job_name: 'crowdsec'
    static_configs:
      - targets: ['crowdsec:6060']
```

Available metrics:
- `cs_bucket_*` - Scenario bucket metrics
- `cs_parser_*` - Log parser metrics
- `cs_lapi_*` - Local API metrics
- `cs_decisions_*` - Active decision metrics

### Grafana Dashboards

Import CrowdSec community dashboards:

1. Go to Grafana: http://192.168.8.250:3000
2. Dashboards → Import
3. Enter dashboard ID: `15174` (CrowdSec Overview)
4. Select Prometheus data source

## Advanced Configuration

### CrowdSec Console Enrollment

Get access to advanced features:

1. **Sign up** at https://app.crowdsec.net/
2. **Get enrollment key** from the console
3. **Add to `.env`**:
   ```bash
   CROWDSEC_ENROLL_KEY=your_enrollment_key_here
   ```
4. **Restart**:
   ```bash
   docker compose restart crowdsec
   ```

Benefits:
- 🎯 Premium blocklists (reduces false positives)
- 📊 Cloud dashboard with analytics
- 🌍 Better threat intelligence
- 📈 Historical attack data

### Whitelisting IPs

Never block trusted IPs:

```bash
# Whitelist your local network
docker exec crowdsec cscli decisions add \
  --ip 192.168.8.0/24 \
  --type whitelist \
  --reason "Local network"

# Whitelist a specific IP
docker exec crowdsec cscli decisions add \
  --ip 8.8.8.8 \
  --type whitelist \
  --reason "Trusted DNS"
```

Or create a whitelist parser in `config/parsers/s02-enrich/whitelist.yaml`:

```yaml
name: crowdsecurity/whitelists
description: "Whitelist local and trusted IPs"
whitelist:
  reason: "Private IP ranges and trusted services"
  ip:
    - 192.168.8.0/24
    - 10.0.0.0/8
    - 172.16.0.0/12
  cidr:
    - 192.168.0.0/16
```

### Custom Scenarios

Create custom detection scenarios in `config/scenarios/`:

```yaml
# config/scenarios/my-custom-scenario.yaml
type: leaky
name: myorg/custom-bruteforce
description: "Detect custom brute-force patterns"
filter: "evt.Meta.log_type == 'my_app'"
leakspeed: "10s"
capacity: 5
blackhole: 1m
labels:
  service: my-app
  type: bruteforce
```

## Monitoring & Alerts

### Health Checks

```bash
# Check if CrowdSec is running
docker ps | grep crowdsec

# Check logs
docker logs crowdsec --tail 50
docker logs crowdsec-firewall-bouncer --tail 50

# Verify bouncer connection
docker exec crowdsec cscli bouncers list
```

### Set Up Alerting

Configure alerts in Alertmanager for critical events:

```yaml
# Add to stacks/observability/alertmanager/alertmanager.yml
- alert: CrowdSecHighDecisions
  expr: cs_decisions_count > 100
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High number of blocked IPs"
    description: "CrowdSec has blocked {{ $value }} IPs in the last 5 minutes"
```

## Troubleshooting

### CrowdSec Won't Start

```bash
# Check logs
docker logs crowdsec

# Verify volume permissions
ls -la /var/log/pihole
ls -la /var/log/auth.log

# Ensure log files are readable
sudo chmod +r /var/log/auth.log
```

### Bouncer Not Blocking

```bash
# Check bouncer status
docker exec crowdsec cscli bouncers list

# Verify bouncer logs
docker logs crowdsec-firewall-bouncer

# Check if decisions exist
docker exec crowdsec cscli decisions list

# Verify iptables rules
sudo iptables -L -n | grep -A 5 crowdsec
```

### No Logs Being Parsed

```bash
# Check acquisition metrics
docker exec crowdsec cscli metrics show acquisitions

# Verify log sources
docker exec crowdsec cat /etc/crowdsec/acquis.d/acquis.yaml

# Check if logs are accessible
docker exec crowdsec ls -la /var/log/pihole
```

### False Positives

```bash
# Whitelist the IP
docker exec crowdsec cscli decisions delete --ip <ip_address>
docker exec crowdsec cscli decisions add --ip <ip_address> --type whitelist

# Or adjust scenario sensitivity in config
```

## Security Considerations

### Best Practices

1. **Regular Updates**: Keep CrowdSec updated
   ```bash
   docker compose pull crowdsec
   docker compose up -d crowdsec
   ```

2. **Monitor Metrics**: Set up Grafana dashboards
3. **Review Decisions**: Regularly check blocked IPs
4. **Whitelist Trusted IPs**: Prevent blocking legitimate traffic
5. **Test Protection**: Simulate attacks to verify it works
6. **Backup Configuration**: Keep `.env` and `config/` backed up

### Limitations

- **Requires 64-bit OS**: Won't work on 32-bit Raspberry Pi OS
- **Resource Usage**: Uses 50-100MB RAM (minimal but not zero)
- **Learning Period**: Takes time to build up local decision database
- **False Positives**: Rare, but can happen with aggressive scenarios

## Performance Impact

On Raspberry Pi 5:
- **CPU Usage**: < 5% average, spikes during log parsing
- **Memory**: 50-100MB for CrowdSec, 20-30MB for bouncer
- **Disk I/O**: Minimal, mostly log reading
- **Network**: Negligible overhead for firewall rules

## Resources

- **CrowdSec Documentation**: https://docs.crowdsec.net/
- **CrowdSec Hub**: https://hub.crowdsec.net/ (browse scenarios)
- **CrowdSec Console**: https://app.crowdsec.net/ (optional enrollment)
- **Community Discord**: https://discord.gg/crowdsec
- **GitHub**: https://github.com/crowdsecurity/crowdsec

## FAQ

**Q: Will this slow down my network?**
A: No. Firewall rules are efficient and add negligible latency (<1ms).

**Q: Do I need to enroll in CrowdSec Console?**
A: No, it's optional. Basic protection works without enrollment.

**Q: Can I use this with Fail2Ban?**
A: Yes, but it's redundant. CrowdSec provides better coverage.

**Q: Will it block me if I fail SSH login?**
A: Only after multiple failures. You can whitelist your IP to prevent this.

**Q: How do I know if it's working?**
A: Check metrics with `docker exec crowdsec cscli metrics` and simulate an attack.

**Q: Can I customize detection rules?**
A: Yes! Create custom scenarios or modify existing ones.

## Contributing

Found a useful scenario or configuration? Share it!

1. Test your configuration
2. Document it clearly
3. Submit a PR to the main repository

## License

This stack uses CrowdSec, which is licensed under MIT License.
