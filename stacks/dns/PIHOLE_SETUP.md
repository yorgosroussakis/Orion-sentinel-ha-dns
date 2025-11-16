# Pi-hole Configuration & Sync Guide

## Overview

This setup includes:
- **Two Pi-hole v6 instances** (Primary & Secondary) for high availability
- **Automatic configuration sync** between instances
- **Pre-configured blocklists**: Hagezi Pro++ and OISD Big
- **Disney+ whitelist** for streaming compatibility

## Initial Setup

### 1. Deploy the Stack

```bash
cd /opt/rpi-ha-dns-stack/stacks/dns

# Ensure network exists
sudo docker network create \
  -d macvlan \
  --subnet=192.168.8.0/24 \
  --gateway=192.168.8.1 \
  -o parent=eth0 \
  dns_net

# Build and start services
sudo docker compose build keepalived
sudo docker compose up -d
```

### 2. Configure Pi-hole (First Time Only)

Wait about 60 seconds for containers to fully start, then run:

```bash
cd /opt/rpi-ha-dns-stack/stacks/dns
sudo bash setup-pihole.sh
```

This script will:
- ✅ Add Hagezi Pro++ blocklist (~3M domains)
- ✅ Add OISD Big blocklist (~1.9M domains)
- ✅ Whitelist Disney+ domains
- ✅ Update gravity database
- ✅ Configure both primary and secondary instances

## Configuration Sync

### Automatic Sync (Recommended)

The `pihole-sync` container runs automatically and syncs every 5 minutes:

```bash
# Check sync logs
sudo docker logs pihole-sync -f

# Restart sync service
sudo docker compose restart pihole-sync
```

### Manual Sync

To manually trigger a sync:

```bash
cd /opt/rpi-ha-dns-stack/stacks/dns
sudo bash pihole-sync.sh --once
```

### What Gets Synced

- ✅ Gravity database (blocklists, groups, clients)
- ✅ Custom DNS records
- ✅ Adlist configuration
- ✅ Whitelist/Blacklist
- ✅ Regex filters

## Blocklists Included

### Hagezi Pro++
- **URL**: https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.plus.txt
- **Domains**: ~3,000,000
- **Coverage**: Comprehensive protection including ads, tracking, malware, and phishing

### OISD Big
- **URL**: https://big.oisd.nl/domainswild
- **Domains**: ~1,900,000
- **Coverage**: Ads, trackers, and malicious domains with low false positives

## Whitelisted Domains

Disney+ streaming requires these domains:
- `disneyplus.com`
- `disney-plus.net`
- `disneystreaming.com`
- `bamgrid.com`
- `dssott.com`

## Managing Pi-hole

### Access Web Interface

- **Primary**: http://192.168.8.251/admin
- **Secondary**: http://192.168.8.252/admin
- **VIP (Failover)**: http://192.168.8.255/admin

### Add More Blocklists

1. Access Pi-hole web interface
2. Go to **Adlists**
3. Add blocklist URL
4. Run `pihole updateGravity`
5. Sync will automatically propagate to secondary

### Add to Whitelist

```bash
# Via CLI
sudo docker exec pihole_primary pihole -w example.com

# Or via Web UI: Whitelist → Add domain
```

The sync service will copy changes to the secondary within 5 minutes.

### Add to Blacklist

```bash
# Via CLI
sudo docker exec pihole_primary pihole -b badsite.com

# Or via Web UI: Blacklist → Add domain
```

## Troubleshooting

### Check Container Status

```bash
sudo docker compose ps
```

All containers should show "Up (healthy)".

### Check Sync Status

```bash
sudo docker logs pihole-sync --tail 50
```

### Manual Gravity Update

```bash
# Update primary
sudo docker exec pihole_primary pihole updateGravity

# Sync to secondary
sudo bash pihole-sync.sh --once
```

### Verify Blocklist Count

```bash
# Check how many domains are blocked
sudo docker exec pihole_primary pihole -q -adlist
```

## Configuration Sync vs Gravity Sync

**Why not Gravity Sync?**
- Gravity Sync doesn't support Pi-hole v6
- Our solution works with v6 and is simpler
- Direct database synchronization is more reliable
- No SSH keys or complex setup required

**How It Works:**
1. Sync container runs on the same host as Pi-hole
2. Uses Docker socket to access both containers
3. Copies configuration files directly
4. Triggers DNS reload on secondary
5. Runs automatically every 5 minutes (configurable)

## Performance

With ~5 million blocked domains:
- Query response time: < 50ms
- Memory usage per instance: ~200MB
- CPU usage: < 5%
- Sync duration: ~10 seconds

## Best Practices

1. **Make changes on Primary**: Always configure via primary Pi-hole
2. **Wait for sync**: Changes propagate within 5 minutes
3. **Monitor sync logs**: Check logs occasionally for errors
4. **Backup regularly**: Backup `/opt/rpi-ha-dns-stack/stacks/dns/pihole1`
5. **Test failover**: Verify secondary works by stopping primary

## Security Notes

- Pi-hole admin password set via `.env` file
- Sync uses read-only Docker socket mount
- No network exposure for sync container
- All communication via local Docker network

## Additional Resources

- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Hagezi Blocklists](https://github.com/hagezi/dns-blocklists)
- [OISD Blocklists](https://oisd.nl/)
