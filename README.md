# Orion Sentinel HA DNS

**High-availability DNS with Pi-hole and Unbound (fully local recursive resolver) for Raspberry Pi homelab.**

[![Docker](https://img.shields.io/badge/docker-compose-blue)](https://docs.docker.com/compose/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## Features

| Feature | Description |
|---------|-------------|
| 🛡️ **Ad Blocking** | Network-wide ad/tracker blocking via Pi-hole |
| 🔒 **Fully Local DNS** | Unbound recursive resolver - no third-party DNS providers |
| 🔐 **Optional DoT** | DNS over TLS to NextDNS if needed |
| ⚡ **Redis Caching** | Sub-millisecond DNS responses |
| 🔒 **DNSSEC** | Cryptographic validation of DNS responses |
| 🏠 **Two-Node HA** | Automatic failover with VRRP/keepalived |
| 🔄 **Pi-hole Sync** | Automatic sync of blocklists between nodes |
| 🏥 **Auto-Healing** | Automatic restart on repeated failures |
| 💾 **Auto-Backup** | Daily backups with retention policy |
| 🌐 **Cross-Platform** | ARM32/ARM64/AMD64 support |
| 📊 **Monitoring Ready** | Prometheus exporters for CoreServices integration |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Network Devices                      │
│              (phones, laptops, IoT, etc.)                    │
└─────────────────────────────┬───────────────────────────────┘
                              │ DNS queries to VIP
                              ▼
                    ┌─────────────────────┐
                    │  VIP: 192.168.8.250 │
                    │  (Floating IP)      │
                    └─────────┬───────────┘
                              │ VRRP
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│   Node A (PRIMARY)       │    │   Node B (SECONDARY)     │
│   192.168.8.249          │    │   192.168.8.243          │
│                          │    │                          │
│   ┌──────────────────┐   │    │   ┌──────────────────┐   │
│   │ Pi-hole+Unbound  │   │    │   │ Pi-hole+Unbound  │   │
│   │ + Redis          │   │    │   │ + Redis          │   │
│   └──────────────────┘   │    │   └──────────────────┘   │
│                          │    │                          │
│   ┌──────────────────┐   │    │   ┌──────────────────┐   │
│   │ Keepalived       │   │    │   │ Keepalived       │   │
│   │ Priority: 200    │   │    │   │ Priority: 150    │   │
│   │ State: MASTER    │   │    │   │ State: BACKUP    │   │
│   └──────────────────┘   │    │   └──────────────────┘   │
└──────────────────────────┘    └──────────────────────────┘
```

## Quick Start

### Prerequisites

- Raspberry Pi 4/5 (or any ARM64/AMD64 system)
- Docker and Docker Compose installed
- Static IP configured on your network interface

### Single Node (No HA)

```bash
# Clone the repository
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns

# Configure environment
cp .env.example .env
nano .env  # Set PIHOLE_PASSWORD

# Deploy
make single

# Test
dig @127.0.0.1 google.com
```

### Two-Node HA Setup

#### On Node A (Primary - 192.168.8.249)

```bash
# Configure
cp .env.primary.example .env
nano .env  # Set passwords (PIHOLE_PASSWORD, VRRP_PASSWORD)

# Deploy
make primary

# Verify VIP is assigned
ip addr show eth1 | grep 192.168.8.250
```

#### On Node B (Secondary - 192.168.8.243)

```bash
# Configure (use SAME passwords as Node A)
cp .env.secondary.example .env
nano .env  # Set SAME passwords as primary

# Deploy
make secondary

# Verify BACKUP state
docker logs keepalived | grep BACKUP
```

#### Test Failover

```bash
# From any device on the network
dig @192.168.8.250 google.com  # Should work

# On Node A, stop the DNS service
docker stop pihole_unbound

# VIP should move to Node B within ~10 seconds
dig @192.168.8.250 google.com  # Should still work!

# Restart Node A
docker start pihole_unbound

# VIP returns to Node A (higher priority)
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PIHOLE_PASSWORD` | (required) | Pi-hole web interface password |
| `VRRP_PASSWORD` | (required) | Keepalived VRRP authentication |
| `VIP_ADDRESS` | `192.168.8.250` | Virtual IP for DNS |
| `VIP_NETMASK` | `24` | VIP subnet mask |
| `NETWORK_INTERFACE` | `eth1` | Interface for VIP |
| `NODE_ROLE` | `MASTER` | `MASTER` or `BACKUP` |
| `KEEPALIVED_PRIORITY` | `200` | Higher = preferred MASTER |
| `PEER_IP` | (empty) | Other node's IP for unicast VRRP |
| `DOT_ENABLED` | `false` | Enable DNS over TLS (to NextDNS) |
| `DOT_UPSTREAM` | (empty) | DoT upstream (e.g., NextDNS config) |
| `REDIS_ENABLED` | `true` | Enable Redis caching |
| `DNSSEC` | `true` | Enable DNSSEC validation |

### Profiles

| Profile | Description | Command |
|---------|-------------|---------|
| `single-node` | Pi-hole+Unbound only | `make single` |
| `two-node-ha-primary` | HA Primary (MASTER) | `make primary` |
| `two-node-ha-backup` | HA Secondary (BACKUP) | `make secondary` |
| `exporters` | Prometheus metrics | Add `--profile exporters` |

## Monitoring Integration

### CoreServices / Prometheus

Enable exporters for Prometheus scraping:

```bash
# Deploy with exporters
make primary-full  # or make secondary-full

# Metrics endpoints:
# - Node metrics: http://<node-ip>:9100/metrics
# - Pi-hole metrics: http://<node-ip>:9617/metrics
```

Add to your Prometheus config:

```yaml
scrape_configs:
  - job_name: 'orion-dns'
    static_configs:
      - targets:
        - '192.168.8.249:9100'  # Node A
        - '192.168.8.249:9617'
        - '192.168.8.243:9100'  # Node B
        - '192.168.8.243:9617'
```

### Log Shipping (SPoG/Loki)

Configure `LOKI_URL` in `.env` to ship Pi-hole logs:

```bash
LOKI_URL=http://192.168.8.100:3100/loki/api/v1/push
```

## Operations

### Pi-hole Sync (Primary → Secondary)

Sync blocklists, whitelists, and configuration from primary to secondary:

```bash
# Run on PRIMARY node only
make sync

# Or manually
./ops/pihole-sync.sh

# Dry run (show what would be synced)
./ops/pihole-sync.sh --dry-run
```

**Requirements:** SSH key-based authentication from primary to secondary node.

### Backup & Restore

```bash
# Create backup
make backup

# List backups
make backup-list

# Restore from backup
./ops/orion-dns-backup.sh --restore <backup_file>
```

Backups include:
- Pi-hole configuration (blocklists, whitelist, blacklist, regex)
- Gravity database
- dnsmasq configuration
- Environment file

### Auto-Healing

The health check script monitors DNS services and restarts containers on repeated failures:

```bash
# Manual health check
make health

# Or with verbose output
./ops/orion-dns-health.sh --verbose
```

### Install Systemd Services

For autostart on boot, auto-healing timer, and scheduled backups:

```bash
# On PRIMARY node
sudo make install-systemd-primary

# On BACKUP node
sudo make install-systemd-backup
```

This installs:
- **Autostart service** - Starts containers on boot
- **Health timer** - Runs health check every 2 minutes
- **Backup timer** - Daily backups at 2 AM
- **Sync timer** - Pi-hole sync every 6 hours (primary only)

## Troubleshooting

### No response on port 53

```bash
# Check if Pi-hole is running
docker ps | grep pihole

# Check Pi-hole logs
docker logs pihole_unbound

# Test locally
dig @127.0.0.1 google.com +short
```

### VIP not assigned

```bash
# Check keepalived status
docker logs keepalived

# Verify interface exists
ip link show eth1

# Check if VIP is on this node
ip addr show | grep 192.168.8.250

# On BACKUP node, VIP should NOT be present (expected)
```

### Keepalived in restart loop

```bash
# Check generated config
docker exec keepalived cat /etc/keepalived/keepalived.conf

# Verify no ${VAR} or \n literals in config
docker exec keepalived grep -E '\$\{|\\n' /etc/keepalived/keepalived.conf

# Common causes:
# - Wrong NETWORK_INTERFACE (interface doesn't exist)
# - VRRP_PASSWORD mismatch between nodes
# - Firewall blocking VRRP (protocol 112)
```

### Failover not working

```bash
# Check VRRP communication
docker exec keepalived tcpdump -i eth1 vrrp

# Verify unicast peer IP is correct
grep unicast_peer /etc/keepalived/keepalived.conf

# Ensure VIRTUAL_ROUTER_ID is same on both nodes
grep virtual_router_id /etc/keepalived/keepalived.conf
```

## Upstream Projects

This project uses:

- **[mpgirro/docker-pihole-unbound](https://github.com/mpgirro/docker-pihole-unbound)** - Pi-hole + Unbound + Redis
- **[keepalived](https://github.com/acassen/keepalived)** - VRRP implementation for HA

## License

MIT License - See [LICENSE](LICENSE) for details.

## Contributing

Pull requests welcome! Please ensure:
- Code follows existing patterns
- Configuration changes are documented
- Test on both ARM64 and AMD64 if possible
