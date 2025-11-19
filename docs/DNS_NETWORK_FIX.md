# DNS Network Fix - Quick Reference

## Problem

Your DNS containers are unreachable with "host unreachable" or "communications error" messages because the `dns_net` Docker network was created as a **bridge** network instead of a **macvlan** network.

## Why This Happens

When you run `docker compose up -d` directly without first creating the macvlan network, Docker Compose automatically creates a default bridge network. Bridge networks don't allow containers to have IPs on the host's subnet (192.168.8.x).

## Quick Fix (Recommended)

Run this automated fix script:

```bash
cd /opt/rpi-ha-dns-stack
bash scripts/fix-dns-network.sh
```

The script will:
1. Detect the network configuration issue
2. Stop all DNS containers
3. Remove the incorrect network
4. Create a new macvlan network
5. Restart the DNS stack

## Manual Fix

If you prefer to do it manually:

```bash
# 1. Load your environment variables
cd /opt/rpi-ha-dns-stack
source .env

# 2. Stop the DNS stack
cd stacks/dns
docker compose down

# 3. Remove the incorrect network
docker network rm dns_net

# 4. Create the correct macvlan network
docker network create \
  -d macvlan \
  --subnet=${SUBNET:-192.168.8.0/24} \
  --gateway=${GATEWAY:-192.168.8.1} \
  -o parent=${NETWORK_INTERFACE:-eth0} \
  dns_net

# 5. Restart the DNS stack
docker compose build keepalived
docker compose up -d

# 6. Wait for services to initialize
sleep 30

# 7. Check status
docker compose ps
```

## Verify the Fix

From **another device on your network** (NOT from the Raspberry Pi itself):

```bash
# Test the VIP (should work)
dig google.com @192.168.8.255

# Test primary Pi-hole
dig google.com @192.168.8.251

# Test secondary Pi-hole
dig google.com @192.168.8.252
```

## Validate Network Configuration

To check if your network is configured correctly:

```bash
bash scripts/validate-network.sh
```

Expected output:
```
[✓] Network 'dns_net' exists
[✓] Network driver is correct: macvlan
[✓] Network subnet is correct: 192.168.8.0/24
[✓] Network gateway is correct: 192.168.8.1
[✓] Network parent interface is correct: eth0
```

## Important Notes

### Why Can't I Test from the Pi?

Due to how macvlan networking works in Docker, the Raspberry Pi host **cannot** directly communicate with containers on the macvlan network. This is a Docker limitation, not a bug.

**This is normal and expected!** You must test DNS from other devices on your network.

### Preventing This Issue

Always deploy using one of these methods instead of running `docker compose` directly:

```bash
# Method 1: Full installation (first time)
bash scripts/install.sh

# Method 2: DNS stack only
bash scripts/deploy-dns.sh

# Method 3: Interactive installer
bash scripts/easy-install.sh
```

## Access Pi-hole Admin Panels

After the fix, access from your browser:
- Primary: http://192.168.8.251/admin
- Secondary: http://192.168.8.252/admin

Password is in your `.env` file: `PIHOLE_PASSWORD`

## Troubleshooting

If you still have issues after the fix:

1. **Check container logs:**
   ```bash
   cd /opt/rpi-ha-dns-stack/stacks/dns
   docker compose logs -f
   ```

2. **Verify containers are running:**
   ```bash
   docker compose ps
   ```

3. **Check network configuration:**
   ```bash
   docker network inspect dns_net
   ```

4. **See full troubleshooting guide:**
   ```bash
   cat TROUBLESHOOTING.md | grep -A 100 "DNS containers unreachable"
   ```

## Additional Help

- Full documentation: [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
- Installation guide: [INSTALLATION_GUIDE.md](../INSTALLATION_GUIDE.md)
- Scripts reference: [scripts/README.md](README.md)
