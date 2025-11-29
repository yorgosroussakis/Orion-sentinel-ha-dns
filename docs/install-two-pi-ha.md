# Two Raspberry Pi High Availability Installation Guide

**Orion Sentinel DNS HA - Dual-Pi Setup with Automatic Failover**

This guide walks you through installing Orion DNS HA on two Raspberry Pis with full hardware redundancy and automatic failover.

---

## Overview

A two-Pi HA deployment provides:
- ✅ Hardware redundancy - DNS continues if one Pi fails
- ✅ Automatic failover - VIP moves to backup Pi within seconds
- ✅ Zero-downtime updates - Update one Pi while the other serves DNS
- ✅ Container-level redundancy - Multiple instances per Pi
- ✅ Production-grade reliability

**Deployment model:** `HighAvail_2Pi1P1U` (Recommended)
- 2 Raspberry Pis
- 1 Pi-hole per Pi
- 1 Unbound per Pi
- Shared Virtual IP (VIP)

---

## Prerequisites

### Hardware Requirements

- **2x Raspberry Pi 4** (4GB RAM recommended each)
- **2x MicroSD cards** (32GB or larger, Class 10)
- **2x Ethernet cables** (Wi-Fi not recommended for HA)
- **2x Power supplies** (official RPi power supply)
- **Network switch** with available ports

### Network Requirements

- **2 static IP addresses** for your Pis (one per Pi)
- **1 Virtual IP (VIP)** address not used by any device
- All three IPs must be on the same subnet
- Access to your router's admin interface

**Example IP scheme:**
- Pi #1 (MASTER): `192.168.1.100`
- Pi #2 (BACKUP): `192.168.1.101`
- VIP (shared): `192.168.1.200`

**Important:** The VIP should be outside your router's DHCP range to avoid conflicts.

---

## Installation Process

You need to set up both Pis. The process is similar but with different node roles.

---

## Pi #1 (MASTER Node) Setup

### 1. Clone the Repository

```bash
# On Pi #1
git clone https://github.com/yorgosroussakis/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
```

### 2. Run Initial Setup

```bash
bash scripts/install.sh
```

This will:
- Install Docker if needed
- Create network configuration
- Set up directories
- Prompt you to configure `.env`

### 3. Configure .env for MASTER

**Option A: Use Web Wizard (Easier)**

```bash
# Start the wizard
docker compose -f stacks/dns/docker-compose.yml up -d dns-wizard

# Access at http://192.168.1.100:8080

# In the wizard:
# - Select "High Availability (HA)" mode
# - Pi IP: 192.168.1.100
# - VIP: 192.168.1.200
# - Node Role: MASTER
# - Interface: eth0
# - Set Pi-hole password
```

**Option B: Manual Configuration**

```bash
cp .env.example .env
nano .env
```

Edit the following values:

```bash
# Pi #1 configuration
HOST_IP=192.168.1.100
NETWORK_INTERFACE=eth0

# Virtual IP (shared between both Pis)
DNS_VIP=192.168.1.200
VIP_ADDRESS=192.168.1.200

# Node role
NODE_ROLE=MASTER

# Network configuration
SUBNET=192.168.1.0/24
GATEWAY=192.168.1.1

# Passwords (use strong passwords!)
PIHOLE_PASSWORD=your-strong-password-here
GRAFANA_ADMIN_PASSWORD=your-strong-password-here
VRRP_PASSWORD=your-strong-password-here

# VRRP configuration for HA
VRRP_ROUTER_ID=51
VRRP_PRIORITY=100  # Higher = master preference
```

**Generate secure passwords:**
```bash
openssl rand -base64 32
```

### 4. Deploy Stack on Pi #1

```bash
docker compose -f stacks/dns/docker-compose.yml up -d
```

### 5. Verify Pi #1 is Running

```bash
# Check containers
docker ps

# Verify VIP is on Pi #1
ip addr show eth0 | grep 192.168.1.200

# Should show the VIP on eth0
```

---

## Pi #2 (BACKUP Node) Setup

### 1. Clone the Repository

```bash
# On Pi #2
git clone https://github.com/yorgosroussakis/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
```

### 2. Run Initial Setup

```bash
bash scripts/install.sh
```

### 3. Configure .env for BACKUP

**Option A: Use Web Wizard**

```bash
# Start the wizard
docker compose -f stacks/dns/docker-compose.yml up -d dns-wizard

# Access at http://192.168.1.101:8080

# In the wizard:
# - Select "High Availability (HA)" mode
# - Pi IP: 192.168.1.101
# - VIP: 192.168.1.200  (SAME as Pi #1)
# - Node Role: BACKUP
# - Interface: eth0
# - Set Pi-hole password (SAME as Pi #1)
```

**Option B: Manual Configuration**

```bash
cp .env.example .env
nano .env
```

Edit the following values:

```bash
# Pi #2 configuration (DIFFERENT from Pi #1)
HOST_IP=192.168.1.101
NETWORK_INTERFACE=eth0

# Virtual IP (SAME as Pi #1)
DNS_VIP=192.168.1.200
VIP_ADDRESS=192.168.1.200

# Node role (DIFFERENT from Pi #1)
NODE_ROLE=BACKUP

# Network configuration (SAME as Pi #1)
SUBNET=192.168.1.0/24
GATEWAY=192.168.1.1

# Passwords (SAME as Pi #1 - very important!)
PIHOLE_PASSWORD=your-strong-password-here
GRAFANA_ADMIN_PASSWORD=your-strong-password-here
VRRP_PASSWORD=your-strong-password-here  # MUST match Pi #1

# VRRP configuration (DIFFERENT from Pi #1)
VRRP_ROUTER_ID=51  # SAME as Pi #1
VRRP_PRIORITY=90   # LOWER than Pi #1 (so Pi #1 is preferred)
```

**Critical:** 
- `VRRP_PASSWORD` **must be the same** on both Pis
- `VRRP_PRIORITY` must be **lower** on BACKUP (e.g., 90) than MASTER (e.g., 100)

### 4. Deploy Stack on Pi #2

```bash
docker compose -f stacks/dns/docker-compose.yml up -d
```

### 5. Verify Pi #2 is Running

```bash
# Check containers
docker ps

# VIP should NOT be on Pi #2 (it's on Pi #1)
ip addr show eth0 | grep 192.168.1.200

# Should show nothing (VIP is on MASTER)
```

---

## Post-Installation Configuration

### 1. Configure Your Router

**Critical:** Point your router's DNS to the VIP address.

1. Log into your router's admin interface
2. Find DNS/DHCP settings
3. Set **Primary DNS**: `192.168.1.200` (the VIP)
4. Set **Secondary DNS**: `192.168.1.200` (same VIP)
5. Save and reboot router if needed

**Why use the VIP for both primary and secondary?**
- The VIP automatically points to whichever Pi is active
- If you used individual Pi IPs, failover wouldn't work for secondary DNS

### 2. Verify Failover Works

**Test 1: Check which Pi has the VIP**

On Pi #1:
```bash
ip addr show eth0 | grep 192.168.1.200
# Should show VIP
```

On Pi #2:
```bash
ip addr show eth0 | grep 192.168.1.200
# Should show nothing
```

**Test 2: Failover Test**

```bash
# From any device on your network
ping -t 192.168.1.200

# On Pi #1, stop Keepalived to trigger failover
docker stop keepalived

# Watch ping output - should continue with minimal packet loss
# VIP should move to Pi #2 within 2-5 seconds
```

Check Pi #2:
```bash
ip addr show eth0 | grep 192.168.1.200
# Should now show VIP on Pi #2
```

**Test 3: Fail back to Pi #1**

```bash
# On Pi #1, restart Keepalived
docker start keepalived

# Wait 5-10 seconds
# VIP should return to Pi #1 (higher priority)

# Verify
ip addr show eth0 | grep 192.168.1.200
# Should show VIP back on Pi #1
```

### 3. Test DNS Resolution

From any device on your network:

```bash
nslookup google.com

# Should show 192.168.1.200 as DNS server
# Try from multiple devices to verify
```

### 4. Apply DNS Security Profile

Choose which profile to use on **both Pis**:

On Pi #1:
```bash
python3 scripts/apply-profile.py --profile standard
```

On Pi #2:
```bash
python3 scripts/apply-profile.py --profile standard
```

Or use the wizard's profile re-application feature:
- `http://192.168.1.100:8080/done` (Pi #1)
- `http://192.168.1.101:8080/done` (Pi #2)

### 5. Set Up Pi-hole Sync (Optional but Recommended)

To keep Pi-hole configurations synchronized:

```bash
# On both Pis, the pihole-sync container should be running
docker ps | grep pihole-sync

# Check logs to verify sync is working
docker logs pihole-sync
```

The sync container automatically:
- Copies whitelist/blacklist between Pis
- Syncs adlists
- Runs every 5 minutes

---

## Accessing Services

### Pi-hole Admin Interfaces

- **Primary (via VIP):** `http://192.168.1.200/admin`
- **Pi #1 directly:** `http://192.168.1.100/admin`
- **Pi #2 directly:** `http://192.168.1.101/admin`

Login with the password set in `.env` (`PIHOLE_PASSWORD`).

### Grafana Dashboards

- **Pi #1:** `http://192.168.1.100:3000`
- **Pi #2:** `http://192.168.1.101:3000`

### Web Wizard

- **Pi #1:** `http://192.168.1.100:8080`
- **Pi #2:** `http://192.168.1.101:8080`

---

## High Availability Architecture

```
┌─────────────────────────────┐  ┌─────────────────────────────┐
│  Pi #1 (MASTER)             │  │  Pi #2 (BACKUP)             │
│  192.168.1.100              │  │  192.168.1.101              │
│                              │  │                              │
│  ┌────────────────────────┐ │  │  ┌────────────────────────┐ │
│  │     Keepalived         │ │  │  │     Keepalived         │ │
│  │  Priority: 100         │ │  │  │  Priority: 90          │ │
│  │  Role: MASTER          │◄─┼──┼─►│  Role: BACKUP          │ │
│  └────────────────────────┘ │  │  └────────────────────────┘ │
│                              │  │                              │
│  ┌───────────┐              │  │  ┌───────────┐              │
│  │ Pi-hole 1 │              │  │  │ Pi-hole 2 │              │
│  └─────┬─────┘              │  │  └─────┬─────┘              │
│        │                    │  │        │                    │
│  ┌─────▼──────┐             │  │  ┌─────▼──────┐             │
│  │ Unbound 1  │             │  │  │ Unbound 2  │             │
│  └────────────┘             │  │  └────────────┘             │
└──────────┬──────────────────┘  └──────────┬──────────────────┘
           │                                 │
           └────────────┬────────────────────┘
                        │
              ┌─────────▼─────────┐
              │   VIP (Floating)  │
              │  192.168.1.200    │
              └─────────┬─────────┘
                        │
                 ┌──────▼──────┐
                 │   Router    │
                 │  DHCP/DNS   │
                 └─────────────┘
                        │
                 ┌──────▼──────┐
                 │   Devices   │
                 └─────────────┘
```

**Failover process:**
1. Keepalived on both Pis sends VRRP heartbeats
2. If Pi #1 (MASTER) fails, Pi #2 detects missing heartbeats
3. Pi #2 (BACKUP) promotes itself to MASTER
4. VIP moves from Pi #1 to Pi #2
5. DNS queries automatically route to Pi #2
6. When Pi #1 recovers, it reclaims the VIP (higher priority)

**Typical failover time:** 2-5 seconds

---

## DNS Resolution Chain

The stack uses a multi-layer DNS resolution approach:

```
Clients → VIP (Pi-hole) → Unbound (primary) → NextDNS (fallback, if enabled)
```

**Normal operation:**
- Clients query the VIP (floating between Pi #1 and Pi #2)
- Pi-hole forwards queries to local Unbound
- Unbound performs recursive DNS resolution with DNSSEC validation

**With NextDNS fallback enabled:**
- If Unbound fails or times out, Pi-hole automatically uses NextDNS
- DNS resolution continues without client-visible interruption

### Configuring NextDNS Fallback (Optional)

To enable NextDNS as a fallback upstream resolver, add these variables to your `.env` file on **both Pis**:

```bash
# Set NEXTDNS_DNS_IPV4 to enable NextDNS fallback
# Your NextDNS profile endpoints (get from https://my.nextdns.io)
NEXTDNS_DNS_IPV4=45.90.28.YOUR_PROFILE_ID
NEXTDNS_DNS_IPV6=2a07:a8c0::YOUR:PROFILE  # Optional
```

**Important:** Both Pis must have identical NextDNS configuration to ensure consistent behavior during failover.

For detailed configuration and testing instructions, see **[NextDNS Fallback Guide](nextdns-fallback.md)**.

---

## Maintenance

### Backup Both Pis

```bash
# On Pi #1
bash scripts/backup-config.sh

# On Pi #2
bash scripts/backup-config.sh
```

Store backups somewhere safe (external drive, NAS, cloud).

### Upgrade One Pi at a Time (Zero Downtime)

```bash
# Upgrade Pi #2 first (BACKUP)
# On Pi #2:
docker stop keepalived  # Ensure VIP stays on Pi #1
bash scripts/upgrade.sh
docker start keepalived

# Wait a few minutes, verify Pi #2 is healthy

# Upgrade Pi #1 (MASTER)
# On Pi #1:
bash scripts/upgrade.sh
# VIP will briefly move to Pi #2, then return to Pi #1
```

### Monitor HA Status

```bash
# Check Keepalived status on both Pis
docker logs keepalived

# Check which Pi has VIP
# On both Pis:
ip addr show eth0 | grep 192.168.1.200
```

### Sync Pi-hole Configuration

If Pi-hole configs drift:

```bash
# On Pi #1 (MASTER), export settings
docker exec pihole_primary pihole -a -t

# Copy the teleporter archive to Pi #2

# On Pi #2 (BACKUP), import settings
# (Or use Pi-hole web UI: Settings → Teleporter)
```

---

## Troubleshooting

### VIP Not Appearing

**Check Keepalived logs:**
```bash
docker logs keepalived
```

**Common issues:**
- VRRP_PASSWORD mismatch between Pis
- Network interface name wrong (should be `eth0` or similar)
- Both Pis set to same priority

### Failover Not Working

**Verify VRRP communication:**
```bash
# On both Pis
sudo tcpdump -i eth0 vrrp

# Should see VRRP advertisements
```

**Check firewall:**
```bash
# Ensure VRRP (protocol 112) is allowed
sudo iptables -L -n | grep vrrp
```

### Pi-hole Configs Out of Sync

**Use pihole-sync manually:**
```bash
# On Pi #1, copy Pi-hole gravity database to Pi #2
docker cp pihole_primary:/etc/pihole/gravity.db /tmp/
scp /tmp/gravity.db pi@192.168.1.101:/tmp/

# On Pi #2
docker cp /tmp/gravity.db pihole_secondary:/etc/pihole/
docker exec pihole_secondary pihole restartdns reload-lists
```

---

## Best Practices

1. **Use identical .env files** except for:
   - `HOST_IP`
   - `NODE_ROLE`
   - `VRRP_PRIORITY`

2. **Keep Pi-hole configs in sync**
   - Use pihole-sync container
   - Or manually sync via Teleporter

3. **Update one Pi at a time**
   - Prevents total DNS outage
   - Test on BACKUP first

4. **Monitor both Pis**
   - Check logs regularly
   - Set up Grafana alerts

5. **Test failover regularly**
   - Monthly reboot of MASTER
   - Verify VIP moves and returns

6. **Keep backups current**
   - Weekly automated backups
   - Store offsite

---

## Next Steps

- **[Operations Guide](operations.md)** - Day-to-day management
- **[DNS Profiles Guide](profiles.md)** - Security profile details
- **[NextDNS Fallback Guide](nextdns-fallback.md)** - Configure external DNS fallback
- **[Disaster Recovery](../DISASTER_RECOVERY.md)** - Recovery procedures
- **[Troubleshooting Guide](../TROUBLESHOOTING.md)** - Common issues

---

**Questions or Issues?**

- Check [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
- Visit the [GitHub repository](https://github.com/yorgosroussakis/Orion-sentinel-ha-dns)
- Review the [Operational Runbook](../OPERATIONAL_RUNBOOK.md)
