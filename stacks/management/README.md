# Management Stack - Optional Services

Complete management, monitoring, and security suite for the RPi HA DNS Stack.

## 📦 Included Services

### 🔒 Security & Scanning
- **Trivy** (Port 8080) - Container vulnerability scanner
  - Scans Docker images for CVEs
  - Automated security reports
  - Integration with CI/CD

### 📊 Monitoring & Metrics
- **Netdata** (Port 19999) - Real-time system monitoring
  - Live CPU, RAM, disk, network metrics
  - Per-process monitoring
  - Docker container insights
  
- **Uptime Kuma** (Port 3001) - Service uptime monitoring
  - HTTP/HTTPS/TCP/Ping monitoring
  - Status pages
  - Multi-channel notifications

### 🎛️ Management & Control
- **Homepage** (Port 3002) - Unified dashboard
  - Single pane of glass for all services
  - Clickable service buttons
  - Real-time status indicators
  - Customizable widgets

- **Portainer** (Port 9000/9443) - Docker GUI management
  - Container management
  - Stack deployment
  - Resource monitoring
  - User access control

- **Watchtower** - Automatic container updates
  - Scheduled updates (4 AM daily)
  - Cleanup old images
  - Notification support

## 🚀 Quick Start

### 1. Deploy Management Stack

```bash
cd stacks/management
docker compose up -d
```

### 2. Configure Environment Variables

Add to your `.env` file:

```bash
# Netdata Cloud (optional)
NETDATA_CLAIM_TOKEN=your-token-here

# Watchtower Notifications (optional)
WATCHTOWER_NOTIFICATION_URL=discord://webhook_id/webhook_token

# Homepage Dashboard Variables
HOMEPAGE_VAR_HOST_IP=192.168.8.250
HOMEPAGE_VAR_PIHOLE_PRIMARY_IP=192.168.8.251
HOMEPAGE_VAR_PIHOLE_SECONDARY_IP=192.168.8.252
HOMEPAGE_VAR_PIHOLE_API_KEY=your-pihole-api-key
HOMEPAGE_VAR_GRAFANA_USER=admin
HOMEPAGE_VAR_GRAFANA_PASSWORD=your-grafana-password
HOMEPAGE_VAR_KUMA_SLUG=your-kuma-slug
HOMEPAGE_VAR_PORTAINER_KEY=your-portainer-api-key
```

### 3. Access Services

| Service | URL | Description |
|---------|-----|-------------|
| Homepage | http://HOST_IP:3002 | Main dashboard |
| Netdata | http://HOST_IP:19999 | System metrics |
| Uptime Kuma | http://HOST_IP:3001 | Uptime monitoring |
| Portainer | http://HOST_IP:9000 | Docker management |
| Trivy | http://HOST_IP:8080 | Security scanner |

## 📖 Initial Setup Guides

### Homepage Dashboard

The Homepage dashboard auto-discovers services. No additional setup needed!

Features:
- **Clickable Service Buttons** - Direct access to all services
- **Real-time Status** - Docker container health
- **Widgets** - Resources, weather, search
- **Bookmarks** - Quick links to documentation

### Netdata

1. Access http://HOST_IP:19999
2. Optional: Sign up for Netdata Cloud
3. Claim node: `docker exec netdata netdata-claim.sh -token=YOUR_TOKEN -rooms=YOUR_ROOM -url=https://app.netdata.cloud`

### Uptime Kuma

1. Access http://HOST_IP:3001
2. Create admin account on first run
3. Add monitors for:
   - Pi-hole Primary: http://PIHOLE_PRIMARY_IP/admin
   - Pi-hole Secondary: http://PIHOLE_SECONDARY_IP/admin
   - Grafana: http://HOST_IP:3000
   - Prometheus: http://HOST_IP:9090

### Portainer

1. Access http://HOST_IP:9000
2. Create admin password on first run
3. Select "Docker" environment
4. Connect to local Docker socket

### Trivy Security Scanner

Scan containers for vulnerabilities:

```bash
# Scan a specific image
docker exec trivy-server trivy image pihole/pihole:latest

# Scan all running containers
docker ps --format '{{.Image}}' | xargs -I {} docker exec trivy-server trivy image {}

# Generate HTML report
docker exec trivy-server trivy image --format template --template '@contrib/html.tpl' -o /tmp/report.html pihole/pihole:latest
```

## 🎨 Customizing Homepage Dashboard

Edit configuration files in `stacks/management/homepage/`:

- `settings.yaml` - General settings, theme, layout
- `services.yaml` - Service definitions and widgets
- `widgets.yaml` - Dashboard widgets
- `bookmarks.yaml` - Quick links
- `docker.yaml` - Docker integration

## 🔧 Advanced Configuration

### Enable Watchtower Notifications

For Discord:
```bash
WATCHTOWER_NOTIFICATION_URL=discord://webhook_id/webhook_token
```

For Slack:
```bash
WATCHTOWER_NOTIFICATION_URL=slack://botname@token-a/token-b/token-c
```

For Email:
```bash
WATCHTOWER_NOTIFICATION_URL=smtp://username:password@host:port/?from=sender@example.com&to=recipient@example.com
```

### Trivy Scheduled Scans

Add to cron or systemd timer:

```bash
#!/bin/bash
# Scan all running containers daily
docker ps --format '{{.Image}}' | while read image; do
    echo "Scanning $image..."
    docker exec trivy-server trivy image "$image"
done > /var/log/trivy-scan.log 2>&1
```

### Netdata Custom Alarms

Edit `stacks/management/netdata-config/health.d/custom.conf`:

```yaml
alarm: high_cpu_usage
   on: system.cpu
lookup: average -3m unaligned of user,system,nice,iowait,irq,softirq
 units: %
 every: 10s
  warn: $this > 80
  crit: $this > 95
  info: system CPU usage is extremely high
```

## 📊 Resource Requirements

Estimated resource usage:

| Service | CPU | Memory | Disk |
|---------|-----|--------|------|
| Trivy | 0.1-0.5 | 128-512 MB | 2 GB (cache) |
| Netdata | 0.25-1.0 | 128-512 MB | 100 MB |
| Uptime Kuma | 0.1-0.5 | 64-256 MB | 50 MB |
| Homepage | 0.1-0.5 | 64-256 MB | 10 MB |
| Portainer | 0.1-0.5 | 64-256 MB | 50 MB |
| Watchtower | 0.05-0.25 | 32-128 MB | Minimal |
| **Total** | **0.7-3.2** | **460-2176 MB** | **~2.5 GB** |

### Recommendations

- **2GB Pi**: Deploy Homepage + Uptime Kuma only
- **4GB Pi**: Deploy all except Portainer
- **8GB Pi**: Deploy full stack

## 🔍 Troubleshooting

### Homepage not showing service status

1. Check Docker socket permissions:
   ```bash
   sudo chmod 666 /var/run/docker.sock
   ```

2. Verify container can access socket:
   ```bash
   docker exec homepage ls -la /var/run/docker.sock
   ```

### Netdata can't access host metrics

Ensure volumes are mounted:
```bash
docker inspect netdata | grep -A 20 "Mounts"
```

### Trivy can't pull images

Check Docker socket access:
```bash
docker exec trivy-server docker ps
```

### Watchtower not updating containers

Check logs:
```bash
docker logs watchtower
```

## 🔗 Integration with Main Stack

### Connect to Grafana

Netdata metrics automatically available in Grafana via Prometheus endpoint:
```
http://netdata:19999/api/v1/allmetrics?format=prometheus
```

### Connect to Prometheus

Add Netdata scrape config to `stacks/observability/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'netdata'
    metrics_path: '/api/v1/allmetrics'
    params:
      format: ['prometheus']
    static_configs:
      - targets: ['netdata:19999']
```

### Security Scan Integration

Trigger Trivy scans from AI Watchdog or alerting rules.

## 📚 Additional Resources

- [Homepage Documentation](https://gethomepage.dev/)
- [Netdata Documentation](https://learn.netdata.cloud/)
- [Uptime Kuma Documentation](https://github.com/louislam/uptime-kuma/wiki)
- [Portainer Documentation](https://docs.portainer.io/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Watchtower Documentation](https://containrrr.dev/watchtower/)

## 🎯 Best Practices

1. **Regular Security Scans**: Run Trivy daily
2. **Monitor Uptime**: Set up Uptime Kuma monitors for all critical services
3. **Dashboard Customization**: Tailor Homepage to your needs
4. **Resource Monitoring**: Use Netdata alerts
5. **Backup Configuration**: Save Homepage configs, Uptime Kuma settings
6. **Update Strategy**: Let Watchtower handle updates or disable for manual control

## 🔒 Security Considerations

- **Portainer**: Set strong admin password, enable HTTPS
- **Homepage**: No authentication by default - use reverse proxy
- **Trivy**: Scan images before deployment
- **Network Isolation**: Management stack on separate network
- **API Keys**: Rotate regularly, store securely

## 🚫 Stopping/Removing Stack

```bash
# Stop all services
cd stacks/management
docker compose down

# Remove volumes (careful - deletes data!)
docker compose down -v
```

## ✅ Health Checks

All services include health checks. Monitor with:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

Healthy services show "(healthy)" in status column.
