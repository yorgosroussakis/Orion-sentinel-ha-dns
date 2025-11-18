# Integration Guide: VPN Stack with Main DNS Stack

This guide explains how the VPN stack integrates with the existing DNS stack and how to deploy them together.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet                                  │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     │ Port 51820/udp (WireGuard)
                     │
┌────────────────────▼────────────────────────────────────────────┐
│                    Router (with optional VPN)                    │
│              Port Forwarding: 51820 → 192.168.8.250             │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     │ Home Network (192.168.8.0/24)
                     │
┌────────────────────▼────────────────────────────────────────────┐
│              Raspberry Pi (192.168.8.250)                        │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              DNS Stack (existing)                        │   │
│  │  • Pi-hole Primary (192.168.8.251)                      │   │
│  │  • Pi-hole Secondary (192.168.8.252)                    │   │
│  │  • Unbound Primary (192.168.8.253)                      │   │
│  │  • Unbound Secondary (192.168.8.254)                    │   │
│  │  • Keepalived VIP (192.168.8.255)                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │         VPN Stack (new - this PR)                        │   │
│  │  • WireGuard Server (10.13.13.0/24)                     │   │
│  │  • WireGuard-UI (:5000)                                 │   │
│  │  • Nginx Proxy Manager (:80, :443, :81)                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │      Observability Stack (existing)                      │   │
│  │  • Prometheus (:9090)                                   │   │
│  │  • Grafana (:3000)                                       │   │
│  │  • Alertmanager (:9093)                                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
└───────────────────────────────────────────────────────────────┘
                     │
                     │ VPN Tunnel (10.13.13.0/24)
                     │
┌────────────────────▼────────────────────────────────────────────┐
│                  VPN Clients                                     │
│  • Mobile (10.13.13.2)                                           │
│  • Laptop (10.13.13.3)                                           │
│  • Tablet (10.13.13.4)                                           │
└──────────────────────────────────────────────────────────────────┘
```

## Key Integration Points

### 1. DNS Integration
- VPN clients automatically use Pi-hole (192.168.8.251) for DNS
- Ad-blocking works for all VPN-connected devices
- DNS queries go through existing Unbound recursive DNS
- Full DNS HA benefits apply to VPN clients

### 2. Network Isolation
- VPN stack uses separate docker networks (vpn_net, proxy_net)
- DNS stack uses existing dns_net network
- No network conflicts between stacks
- Clear separation of concerns

### 3. Monitoring Integration (Optional)
- WireGuard can be monitored via Prometheus exporters
- Nginx Proxy Manager has metrics endpoints
- Grafana dashboards can display VPN metrics

### 4. Service Access
- VPN clients can access all services on 192.168.8.0/24
- Pi-hole admin interfaces accessible via VPN
- Grafana/Prometheus accessible via VPN
- New services exposed via Nginx Proxy Manager

## Deployment Scenarios

### Scenario 1: Complete Stack (DNS + VPN + Monitoring)

Deploy everything:
```bash
cd /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack

# Deploy DNS stack
docker compose -f stacks/dns/docker-compose.yml up -d

# Deploy observability stack
docker compose -f stacks/observability/docker-compose.yml up -d

# Deploy VPN stack
docker compose -f stacks/vpn/docker-compose.yml up -d

# Or use the deployment script
bash stacks/vpn/deploy-vpn.sh
```

### Scenario 2: Add VPN to Existing Installation

If you already have DNS + monitoring:
```bash
cd /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack

# Just add VPN stack
bash stacks/vpn/deploy-vpn.sh
```

### Scenario 3: VPN-Only (Minimal)

Just want VPN without DNS stack:
```bash
cd /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack

# Deploy only VPN
docker compose -f stacks/vpn/docker-compose.yml up -d

# Note: Update WG_PEER_DNS to use external DNS (1.1.1.1 or 8.8.8.8)
```

## Configuration Coordination

### Environment Variables
All configuration in `.env` file:
```bash
# DNS Stack variables (existing)
HOST_IP=192.168.8.250
PRIMARY_DNS_IP=192.168.8.251
SECONDARY_DNS_IP=192.168.8.252
# ...

# VPN Stack variables (new)
WG_SERVER_URL=home.example.com
WG_PEER_DNS=192.168.8.251  # Points to DNS stack
# ...
```

### Port Allocation
Clear port separation:
```
DNS Stack:
- 192.168.8.251:53 (Pi-hole primary)
- 192.168.8.252:53 (Pi-hole secondary)

Monitoring:
- :3000 (Grafana)
- :9090 (Prometheus)
- :9093 (Alertmanager)

VPN Stack:
- :51820/udp (WireGuard)
- :5000 (WireGuard-UI)
- :80, :443, :81 (Nginx Proxy Manager)
```

## Data Persistence

### Volume Management
Each stack manages its own volumes:
```bash
# DNS stack volumes
./stacks/dns/pihole1/
./stacks/dns/pihole2/
./stacks/dns/unbound/

# VPN stack volumes
./stacks/vpn/wireguard/config/
./stacks/vpn/wireguard-ui/db/
./stacks/vpn/nginx-proxy-manager/data/
```

### Backup Strategy
```bash
#!/bin/bash
# Backup script for integrated stacks

BACKUP_DIR="$HOME/stack-backups/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup DNS stack
tar -czf "$BACKUP_DIR/dns-stack.tar.gz" stacks/dns/pihole1 stacks/dns/pihole2 stacks/dns/unbound

# Backup VPN stack
tar -czf "$BACKUP_DIR/vpn-stack.tar.gz" stacks/vpn/wireguard stacks/vpn/wireguard-ui stacks/vpn/nginx-proxy-manager

# Backup configuration
cp .env "$BACKUP_DIR/.env"

echo "Backup complete: $BACKUP_DIR"
```

## Upgrade Procedures

### Update All Stacks
```bash
#!/bin/bash
cd /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack

echo "Pulling latest images..."
docker compose -f stacks/dns/docker-compose.yml pull
docker compose -f stacks/observability/docker-compose.yml pull
docker compose -f stacks/vpn/docker-compose.yml pull

echo "Restarting services..."
docker compose -f stacks/dns/docker-compose.yml up -d
docker compose -f stacks/observability/docker-compose.yml up -d
docker compose -f stacks/vpn/docker-compose.yml up -d

echo "Update complete!"
```

### Selective Updates
```bash
# Update only VPN stack
docker compose -f stacks/vpn/docker-compose.yml pull
docker compose -f stacks/vpn/docker-compose.yml up -d
```

## Health Monitoring

### Quick Health Check
```bash
#!/bin/bash
echo "=== Stack Health Check ==="

echo -e "\nDNS Stack:"
docker ps | grep -E "pihole|unbound|keepalived" | awk '{print $1, $2, $NF}'

echo -e "\nVPN Stack:"
docker ps | grep -E "wireguard|nginx-proxy" | awk '{print $1, $2, $NF}'

echo -e "\nObservability:"
docker ps | grep -E "prometheus|grafana|alertmanager" | awk '{print $1, $2, $NF}'
```

### Access URLs
After full deployment:
```
DNS:
- Pi-hole Primary: http://192.168.8.251/admin
- Pi-hole Secondary: http://192.168.8.252/admin

Monitoring:
- Grafana: http://192.168.8.250:3000
- Prometheus: http://192.168.8.250:9090

VPN:
- WireGuard-UI: http://192.168.8.250:5000
- Nginx Proxy Manager: http://192.168.8.250:81
```

## Common Integration Patterns

### Pattern 1: VPN → Pi-hole → Internet
```
VPN Client → WireGuard → Pi-hole → Unbound → Internet
```
Benefit: Ad-blocking for VPN users

### Pattern 2: VPN → Local Services
```
VPN Client → WireGuard → Nginx Proxy Manager → Home Services
```
Benefit: Secure access to media servers, NAS, etc.

### Pattern 3: Full Integration
```
VPN Client → WireGuard → Pi-hole (DNS + Ad-blocking)
                      → NPM → Home Services
                      → Grafana (Monitoring)
```
Benefit: Complete home network access

## Troubleshooting Integration Issues

### VPN Clients Can't Resolve DNS
```bash
# Check Pi-hole is accessible
docker exec wireguard ping -c 2 192.168.8.251

# Verify DNS configuration
echo $WG_PEER_DNS

# Test from VPN client
nslookup google.com
# Should show 192.168.8.251 as server
```

### Services Not Accessible Through VPN
```bash
# Check routing
docker exec wireguard ip route

# Verify AllowedIPs includes local network
cat stacks/vpn/wireguard/config/wg_confs/wg0.conf

# Test from client
ping 192.168.8.250
```

### Port Conflicts
```bash
# Check what's using ports
sudo netstat -tuln | grep -E "51820|5000|80|443|81"

# Adjust ports in .env if needed
WG_SERVER_PORT=51821  # Change if 51820 conflicts
```

## Performance Tuning

### For High-Traffic Scenarios
```bash
# In .env
# Increase resource limits in docker-compose.yml

# Example:
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 1024M
```

### For Low-Resource Systems
```bash
# Use split tunnel to reduce load
WG_ALLOWED_IPS=192.168.8.0/24,10.13.13.0/24

# Limit number of peers
WG_PEERS=2

# Reduce monitoring frequency
WATCHDOG_CHECK_INTERVAL=60
```

## Security Considerations

### Firewall Rules
```bash
# Allow WireGuard from internet
sudo ufw allow 51820/udp

# Restrict other services to local network only
sudo ufw allow from 192.168.8.0/24 to any port 5000
sudo ufw allow from 192.168.8.0/24 to any port 81
```

### Access Control
- Pi-hole: Password protected
- Grafana: Password protected
- WireGuard-UI: Password protected
- NPM: Password protected (change default!)

## Future Enhancements

Potential additions:
- [ ] WireGuard Prometheus exporter for metrics
- [ ] Grafana dashboard for VPN connections
- [ ] Alertmanager rules for VPN disconnections
- [ ] Automated backup to remote location
- [ ] 2FA for sensitive services
- [ ] Fail2ban for brute force protection

## Support

For integration issues:
1. Check logs: `docker compose -f stacks/vpn/docker-compose.yml logs`
2. Review documentation in this guide
3. Check individual stack READMEs
4. Open issue on GitHub with details

## Summary

The VPN stack integrates seamlessly with the existing DNS infrastructure:
- ✅ Shares network resources efficiently
- ✅ Uses existing DNS infrastructure (Pi-hole)
- ✅ Maintains clear separation of concerns
- ✅ Easy to deploy, maintain, and upgrade
- ✅ Secure by default
- ✅ Well documented

Deploy with confidence! 🚀
