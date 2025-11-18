# VPN Edition: Security Hardening Guide

This guide covers security best practices for the VPN Edition deployment.

## 🔒 Core Security Principles

1. **Minimize Attack Surface** - Expose only what's necessary
2. **Defense in Depth** - Multiple layers of security
3. **Principle of Least Privilege** - Grant minimum required access
4. **Secret Management** - Protect sensitive credentials
5. **Monitoring & Alerting** - Detect and respond to threats

---

## 🛡️ Firewall Configuration

### UFW (Uncomplicated Firewall) Setup

**Install UFW (if not installed):**
```bash
sudo apt update
sudo apt install ufw
```

**Basic Rules:**
```bash
# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (IMPORTANT: do this first!)
sudo ufw allow 22/tcp comment 'SSH'

# Allow WireGuard VPN
sudo ufw allow 51820/udp comment 'WireGuard VPN'

# Allow DNS (if serving to LAN)
sudo ufw allow from 192.168.8.0/24 to any port 53 comment 'DNS from LAN'

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

**Allow Admin UIs (LAN Only):**
```bash
# Pi-hole Web Interface
sudo ufw allow from 192.168.8.0/24 to any port 80 comment 'Pi-hole HTTP LAN'
sudo ufw allow from 192.168.8.0/24 to any port 443 comment 'Pi-hole HTTPS LAN'

# WireGuard-UI (LAN only)
sudo ufw allow from 192.168.8.0/24 to any port 5000 comment 'WireGuard-UI LAN'

# Portainer (if used)
sudo ufw allow from 192.168.8.0/24 to any port 9000 comment 'Portainer LAN'

# Grafana (if used)
sudo ufw allow from 192.168.8.0/24 to any port 3000 comment 'Grafana LAN'
```

**Allow VPN Clients to Access Services:**
```bash
# VPN subnet is typically 10.6.0.0/24
sudo ufw allow from 10.6.0.0/24 to any port 80 comment 'Pi-hole HTTP VPN'
sudo ufw allow from 10.6.0.0/24 to any port 53 comment 'DNS VPN'
```

### iptables Rules (Advanced)

For more granular control:

```bash
# Create a new chain for WireGuard
sudo iptables -N WIREGUARD

# Allow established connections
sudo iptables -A WIREGUARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow from VPN to LAN services
sudo iptables -A WIREGUARD -s 10.6.0.0/24 -d 192.168.8.0/24 -j ACCEPT

# Drop everything else
sudo iptables -A WIREGUARD -j DROP

# Apply to WireGuard interface
sudo iptables -I FORWARD -i wg0 -j WIREGUARD

# Save rules
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

---

## 🔐 Secrets Management

### Protect .env.vpn File

**Add to .gitignore:**
```bash
echo ".env.vpn" >> .gitignore
echo "**/. env.vpn" >> .gitignore
```

**Set Proper Permissions:**
```bash
chmod 600 .env.vpn
chown root:root .env.vpn
```

**Verify it's not committed:**
```bash
git status --ignored | grep .env.vpn
```

### Generate Strong Secrets

**Use the installation script:**
```bash
./scripts/install_vpn_edition.sh
```

**Or manually:**
```bash
# Session secret (32 characters)
openssl rand -base64 32 | tr -d "=+/" | cut -c1-32

# UI password (16 characters)
openssl rand -base64 16 | tr -d "=+/" | cut -c1-16

# Alternative: pwgen
sudo apt install pwgen
pwgen -s 32 1  # Session secret
pwgen -s 16 1  # Password
```

### Rotate Secrets Regularly

**Every 90 days:**
```bash
# Generate new secrets
NEW_SESSION=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
NEW_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)

# Update .env.vpn
sed -i "s/^WGUI_SESSION_SECRET=.*/WGUI_SESSION_SECRET=$NEW_SESSION/" .env.vpn
sed -i "s/^WGUI_PASSWORD=.*/WGUI_PASSWORD=$NEW_PASSWORD/" .env.vpn

# Restart services
docker compose -f docker-compose.vpn.yml --env-file .env.vpn restart
```

---

## 🌐 WireGuard-UI Security

### Bind to Localhost Only

**Edit docker-compose.vpn.yml:**
```yaml
wireguard-ui:
  # ... other config ...
  ports:
    - "127.0.0.1:5000:5000"  # Only accessible via SSH tunnel
```

### Access via SSH Tunnel

**From your laptop:**
```bash
ssh -L 5000:localhost:5000 pi@192.168.8.250
```

**Then open:** http://localhost:5000

### Enable HTTPS with Reverse Proxy

**Using Nginx:**
```nginx
server {
    listen 443 ssl;
    server_name vpn-admin.home.local;

    ssl_certificate /etc/ssl/certs/vpn-admin.crt;
    ssl_certificate_key /etc/ssl/private/vpn-admin.key;

    # Strong SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Client certificate authentication (optional)
    # ssl_client_certificate /etc/ssl/certs/ca.crt;
    # ssl_verify_client on;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        
        # IP whitelist
        allow 192.168.8.0/24;
        allow 10.6.0.0/24;
        deny all;
    }
}
```

### Force Strong Authentication

**In docker-compose.vpn.yml:**
```yaml
environment:
  - WGUI_USERNAME=admin
  - WGUI_PASSWORD=${WGUI_PASSWORD}
  - WGUI_SESSION_SECRET=${WGUI_SESSION_SECRET}
  - WGUI_SESSION_TIMEOUT=3600  # 1 hour timeout
```

---

## 🔍 Monitoring & Logging

### Enable WireGuard Logging

**Check logs:**
```bash
# Container logs
docker logs wireguard

# Follow logs
docker logs -f wireguard

# Last 100 lines
docker logs --tail 100 wireguard
```

### WireGuard Metrics Export

**Create metrics exporter script:**

`/opt/rpi-ha-dns-stack/scripts/wireguard_exporter.sh`:
```bash
#!/bin/bash
# Export WireGuard metrics for Prometheus

METRICS_PORT=9586
METRICS_FILE="/tmp/wireguard_metrics.prom"

while true; do
    # Get wg show output
    WG_STATS=$(docker exec wireguard wg show all dump)
    
    # Parse and export metrics
    {
        echo "# HELP wireguard_peer_connected Peer connection status (1=connected, 0=disconnected)"
        echo "# TYPE wireguard_peer_connected gauge"
        
        echo "# HELP wireguard_peer_rx_bytes Received bytes from peer"
        echo "# TYPE wireguard_peer_rx_bytes counter"
        
        echo "# HELP wireguard_peer_tx_bytes Transmitted bytes to peer"
        echo "# TYPE wireguard_peer_tx_bytes counter"
        
        echo "# HELP wireguard_peer_last_handshake_seconds Seconds since last handshake"
        echo "# TYPE wireguard_peer_last_handshake_seconds gauge"
        
        while IFS=$'\t' read -r interface peer_public_key preshared_key endpoint allowed_ips latest_handshake rx_bytes tx_bytes persistent_keepalive; do
            if [ "$interface" != "private-key" ] && [ -n "$peer_public_key" ]; then
                # Extract peer name from config
                peer_name=$(echo "$peer_public_key" | cut -c1-8)
                
                # Connected if handshake within last 3 minutes
                now=$(date +%s)
                if [ "$latest_handshake" != "0" ]; then
                    handshake_age=$((now - latest_handshake))
                    if [ $handshake_age -lt 180 ]; then
                        connected=1
                    else
                        connected=0
                    fi
                else
                    connected=0
                    handshake_age=0
                fi
                
                echo "wireguard_peer_connected{peer=\"$peer_name\"} $connected"
                echo "wireguard_peer_rx_bytes{peer=\"$peer_name\"} $rx_bytes"
                echo "wireguard_peer_tx_bytes{peer=\"$peer_name\"} $tx_bytes"
                echo "wireguard_peer_last_handshake_seconds{peer=\"$peer_name\"} $handshake_age"
            fi
        done <<< "$WG_STATS"
    } > "$METRICS_FILE"
    
    sleep 30
done
```

**Make executable:**
```bash
chmod +x /opt/rpi-ha-dns-stack/scripts/wireguard_exporter.sh
```

**Run as systemd service:**

`/etc/systemd/system/wireguard-exporter.service`:
```ini
[Unit]
Description=WireGuard Prometheus Exporter
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/opt/rpi-ha-dns-stack/scripts/wireguard_exporter.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Enable and start:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable wireguard-exporter
sudo systemctl start wireguard-exporter
```

### Prometheus Configuration

**Add to prometheus.yml:**
```yaml
scrape_configs:
  - job_name: 'wireguard'
    static_configs:
      - targets: ['localhost:9586']
```

### Grafana Dashboard

**Metrics to monitor:**
- Active peer count
- Bytes transferred per peer
- Last handshake age
- Connection duration
- Failed connection attempts

**Alert conditions:**
- No peers connected for > 24 hours
- Peer offline for > 1 hour
- Excessive bandwidth usage
- Failed authentication attempts

---

## 🚨 Alerting with Alertmanager

### Configure Alerts

**prometheus_alerts.yml:**
```yaml
groups:
  - name: wireguard
    interval: 1m
    rules:
      - alert: WireGuardPeerDown
        expr: wireguard_peer_connected == 0
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "WireGuard peer {{ $labels.peer }} disconnected"
          description: "Peer {{ $labels.peer }} has been offline for over 1 hour"
      
      - alert: WireGuardNoPeers
        expr: sum(wireguard_peer_connected) == 0
        for: 24h
        labels:
          severity: info
        annotations:
          summary: "No VPN clients connected"
          description: "No WireGuard peers have connected in 24 hours"
      
      - alert: WireGuardHandshakeOld
        expr: wireguard_peer_last_handshake_seconds > 600
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "WireGuard peer {{ $labels.peer }} handshake stale"
          description: "Last handshake was {{ $value }} seconds ago"
```

### Signal Integration

**Send alerts via Signal (if configured):**
```yaml
# In alertmanager.yml
receivers:
  - name: 'signal'
    webhook_configs:
      - url: 'http://signal-cli-rest-api:8080/v2/send'
        send_resolved: true
```

---

## 🔄 Automatic Updates

### Watchtower for Docker Images

**Add to docker-compose.vpn.yml:**
```yaml
services:
  watchtower:
    image: containrrr/watchtower
    container_name: watchtower-vpn
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 0 4 * * *  # 4 AM daily
      - WATCHTOWER_INCLUDE_STOPPED=true
      - WATCHTOWER_REVIVE_STOPPED=false
    command: wireguard wireguard-ui
```

### Manual Updates

**Check for updates:**
```bash
docker compose -f docker-compose.vpn.yml pull
docker compose -f docker-compose.vpn.yml up -d
docker image prune -f
```

---

## 🔐 Peer Management Best Practices

### Naming Convention

Use descriptive names:
```
john-iphone
john-laptop
mary-android
guest-tablet-01
```

### Regular Audits

**Monthly review:**
```bash
# List all peers
docker exec wireguard wg show

# Check last handshake for each
docker exec wireguard wg show all latest-handshakes
```

**Remove inactive peers:**
- No handshake in 90+ days
- Lost/stolen devices
- Former users

### Device Loss Response

**If a device is lost/stolen:**
1. Immediately remove peer from WireGuard-UI
2. Regenerate server keys if compromised
3. Notify all users to update configs
4. Review access logs for suspicious activity

---

## 📋 Security Checklist

### Initial Setup
- [ ] UFW firewall configured
- [ ] WireGuard-UI accessible only from LAN/VPN
- [ ] Strong SESSION_SECRET generated (32+ chars)
- [ ] Strong WGUI_PASSWORD generated (16+ chars)
- [ ] .env.vpn added to .gitignore
- [ ] .env.vpn permissions set to 600
- [ ] Router port forwarding configured (only 51820/UDP)

### Regular Maintenance (Monthly)
- [ ] Review active peers
- [ ] Remove inactive/old peers
- [ ] Check firewall logs for suspicious activity
- [ ] Update Docker images
- [ ] Review Grafana metrics
- [ ] Test fail over (if HA setup)

### Quarterly
- [ ] Rotate SESSION_SECRET
- [ ] Rotate WGUI_PASSWORD
- [ ] Audit peer list
- [ ] Review and update firewall rules
- [ ] Test backup and restore

### Annually
- [ ] Regenerate all peer configs
- [ ] Review and update security policies
- [ ] Penetration testing (optional)
- [ ] Update documentation

---

## 🚦 Incident Response

### Suspected Breach

**Immediate actions:**
1. **Isolate:** Stop WireGuard container
   ```bash
   docker compose -f docker-compose.vpn.yml stop wireguard
   ```

2. **Investigate:** Check logs
   ```bash
   docker logs wireguard > /tmp/wireguard-breach-logs.txt
   ```

3. **Revoke:** Remove all peers
   ```bash
   # Via WireGuard-UI or
   docker exec wireguard wg set wg0 peer <public-key> remove
   ```

4. **Rotate:** Change all secrets
5. **Notify:** Inform all users
6. **Regenerate:** Create new configs
7. **Monitor:** Watch for suspicious activity

### Recovery Procedure

1. Review logs to identify breach vector
2. Patch vulnerability
3. Regenerate server keys
4. Create new peer configs
5. Distribute new configs securely
6. Enable enhanced monitoring
7. Document incident for future reference

---

## 📚 Additional Resources

- **WireGuard Security:** https://www.wireguard.com/papers/wireguard.pdf
- **Docker Security:** https://docs.docker.com/engine/security/
- **UFW Guide:** https://help.ubuntu.com/community/UFW
- **Prometheus Security:** https://prometheus.io/docs/operating/security/

---

## 🆘 Security Support

**If you discover a security vulnerability:**
1. Do NOT open a public issue
2. Contact repository maintainers privately
3. Provide detailed information
4. Allow time for patch before disclosure

---

*Last updated: 2025-11-18*
*Security Version: 1.0*
