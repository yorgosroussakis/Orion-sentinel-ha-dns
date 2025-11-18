# VPN Quick Reference Guide

Quick reference for common VPN tasks and scenarios.

## Quick Commands

### Start VPN Stack
```bash
cd /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack
docker compose -f stacks/vpn/docker-compose.yml up -d
```

### Stop VPN Stack
```bash
docker compose -f stacks/vpn/docker-compose.yml down
```

### View Logs
```bash
docker logs wireguard
docker logs wireguard-ui
docker logs nginx-proxy-manager
```

### Restart Services
```bash
docker compose -f stacks/vpn/docker-compose.yml restart
```

### Update Containers
```bash
docker compose -f stacks/vpn/docker-compose.yml pull
docker compose -f stacks/vpn/docker-compose.yml up -d
```

## Common Scenarios

### Scenario 1: Access Media Server (Jellyfin/Plex)

**Setup**:
1. Connect to VPN
2. Add proxy host in NPM:
   - Domain: `media.home.local`
   - Forward to: `192.168.8.100:8096` (Jellyfin) or `:32400` (Plex)
3. Access: `http://media.home.local`

**Split Tunnel Config**:
```bash
WG_ALLOWED_IPS=192.168.8.0/24,10.13.13.0/24
```

### Scenario 2: Full Remote Work Setup

**Need**: Access all home resources, appear as if at home

**Config**:
```bash
WG_ALLOWED_IPS=0.0.0.0/0
WG_PEER_DNS=192.168.8.251
```

**Result**: All traffic routed through home, Pi-hole blocks ads everywhere

### Scenario 3: Mobile Ad-Blocking Only

**Need**: Block ads on mobile without routing all traffic

**Config**:
```bash
# In WireGuard-UI, when creating peer:
Allowed IPs: 192.168.8.251/32  # Only route DNS to Pi-hole
DNS: 192.168.8.251
```

**Result**: Mobile uses home Pi-hole for DNS, gets ad-blocking

### Scenario 4: Expose Multiple Services

**Services**:
- Jellyfin: `192.168.8.100:8096`
- Home Assistant: `192.168.8.101:8123`
- NAS: `192.168.8.102:5000`

**NPM Config**:
```
jellyfin.home.local → 192.168.8.100:8096
homeassistant.home.local → 192.168.8.101:8123
nas.home.local → 192.168.8.102:5000
```

**Access**: Connect VPN, navigate to `http://[service].home.local`

### Scenario 5: Working with Router VPN (Proton)

**Problem**: Router has Proton VPN, need to also access home services

**Solution A - Exclude Pi from Router VPN**:
1. In router, exclude 192.168.8.250 from VPN routing
2. Pi gets direct internet access
3. WireGuard works normally

**Solution B - Use DDNS**:
1. Set up DuckDNS or No-IP
2. Update `WG_SERVER_URL` with DDNS hostname
3. Even if IP changes, VPN stays connected

**Solution C - Port Forward Through Proton**:
1. Use Proton's port forwarding (paid feature)
2. Forward assigned port to 51820
3. Update `WG_SERVER_PORT` to Proton's assigned port

## Network Topology Reference

```
Internet
   |
   ├── Your Router (Proton VPN)
   |      |
   |      ├── Port Forward: UDP 51820 → 192.168.8.250
   |      |
   ├── Raspberry Pi (192.168.8.250)
          |
          ├── WireGuard VPN (10.13.13.0/24)
          |   └── Clients: .2, .3, .4, ...
          |
          ├── Pi-hole Primary (192.168.8.251)
          ├── Pi-hole Secondary (192.168.8.252)
          |
          └── Other Services
              ├── Media Server (192.168.8.100)
              ├── Home Assistant (192.168.8.101)
              └── NAS (192.168.8.102)
```

## Access URLs Reference

| Service | URL | Port | Purpose |
|---------|-----|------|---------|
| WireGuard-UI | http://192.168.8.250:5000 | 5000 | Manage VPN peers |
| Nginx Proxy Manager | http://192.168.8.250:81 | 81 | Configure reverse proxy |
| NPM HTTP | http://192.168.8.250:80 | 80 | HTTP traffic |
| NPM HTTPS | https://192.168.8.250:443 | 443 | HTTPS traffic |
| WireGuard VPN | udp://[public-ip]:51820 | 51820 | VPN connection |

## Configuration Snippets

### Full Tunnel (All Traffic Through VPN)
```bash
# In .env
WG_ALLOWED_IPS=0.0.0.0/0

# In WireGuard-UI peer config
AllowedIPs = 0.0.0.0/0, ::/0
```

### Split Tunnel (Local Network Only)
```bash
# In .env
WG_ALLOWED_IPS=192.168.8.0/24,10.13.13.0/24

# In WireGuard-UI peer config
AllowedIPs = 192.168.8.0/24, 10.13.13.0/24
```

### DNS-Only Tunnel (Pi-hole Ad-Blocking Only)
```bash
# In WireGuard-UI peer config
AllowedIPs = 192.168.8.251/32
DNS = 192.168.8.251
```

## Troubleshooting Flowchart

```
Can't connect to VPN?
├── Port 51820 open? → Test at yougetsignal.com
│   ├── No → Configure router port forwarding
│   └── Yes → Continue
├── Correct public IP in WG_SERVER_URL?
│   ├── No → Update .env and restart
│   └── Yes → Continue
├── Firewall blocking? → Check ufw/iptables
│   ├── Yes → Allow UDP 51820
│   └── No → Check WireGuard logs

Connected but can't access services?
├── Services work locally?
│   ├── No → Fix service first
│   └── Yes → Continue
├── Correct AllowedIPs?
│   ├── No → Include 192.168.8.0/24
│   └── Yes → Continue
├── DNS resolving? → Test: nslookup google.com
│   ├── No → Check WG_PEER_DNS
│   └── Yes → Check NPM config

Slow VPN performance?
├── Using full tunnel?
│   ├── Yes → Switch to split tunnel
│   └── No → Continue
├── Check MTU → Try lower values (1380, 1280)
├── Upload speed limit? → VPN limited by home upload
└── Router VPN conflict? → Exclude Pi from router VPN
```

## Default Credentials Reference

| Service | Username | Password | Location |
|---------|----------|----------|----------|
| WireGuard-UI | admin | (from .env WGUI_PASSWORD) | http://192.168.8.250:5000 |
| NPM | admin@example.com | changeme | http://192.168.8.250:81 |

**⚠️ IMPORTANT**: Change default credentials immediately after first login!

## Port Reference

| Port | Protocol | Service | External? |
|------|----------|---------|-----------|
| 51820 | UDP | WireGuard VPN | Yes - Forward from router |
| 5000 | TCP | WireGuard-UI | No - Internal only |
| 80 | TCP | NPM HTTP | No - Via VPN only |
| 443 | TCP | NPM HTTPS | No - Via VPN only |
| 81 | TCP | NPM Admin | No - Internal only |

## Security Checklist

- [ ] Changed WireGuard-UI password
- [ ] Changed NPM default credentials
- [ ] Used strong random WGUI_SESSION_SECRET
- [ ] Port forwarding limited to UDP 51820 only
- [ ] Regularly reviewed connected peers
- [ ] Enabled SSL in NPM (if using real domain)
- [ ] Configured firewall rules
- [ ] Set up automatic backups
- [ ] Documented all peer assignments
- [ ] Tested connection from external network

## Monitoring Commands

```bash
# Check VPN status
docker exec wireguard wg show

# Count active connections
docker exec wireguard wg show | grep -c "peer:"

# View recent logs
docker logs --tail 50 wireguard

# Check resource usage
docker stats wireguard wireguard-ui nginx-proxy-manager

# Test from VPN client
ping 192.168.8.250
nslookup google.com
curl http://192.168.8.251/admin
```

## Backup Commands

```bash
# Backup VPN configuration
tar -czf vpn-backup-$(date +%Y%m%d).tar.gz \
  stacks/vpn/wireguard/config \
  stacks/vpn/wireguard-ui/db \
  stacks/vpn/nginx-proxy-manager/data

# Restore configuration
tar -xzf vpn-backup-YYYYMMDD.tar.gz -C /path/to/restore/
```

## Quick Testing Script

```bash
#!/bin/bash
echo "=== VPN Stack Health Check ==="

# Check containers
echo "Checking containers..."
docker ps | grep -E "wireguard|nginx-proxy-manager"

# Check port
echo "Checking if port 51820 is listening..."
sudo netstat -tuln | grep 51820 || echo "❌ Port not listening"

# Check WireGuard interface
echo "Checking WireGuard interface..."
docker exec wireguard wg show || echo "❌ WireGuard not running"

# Check public IP
echo "Public IP: $(curl -s ifconfig.me)"

echo "=== Health Check Complete ==="
```

## Support Links

- [WireGuard Documentation](https://www.wireguard.com/quickstart/)
- [WireGuard-UI GitHub](https://github.com/ngoduykhanh/wireguard-ui)
- [Nginx Proxy Manager Docs](https://nginxproxymanager.com/guide/)
- [Stack Issues](https://github.com/yorgosroussakis/rpi-ha-dns-stack/issues)
