# DNS High Availability (HA) with Two Raspberry Pis

**Orion Sentinel DNS HA - Automatic Failover Between Two Pi Nodes**

This document describes the two-Pi HA architecture, client configuration, and operational procedures.

---

## Overview

The two-Pi HA deployment provides:
- ✅ **Hardware redundancy** — DNS continues if one Pi fails
- ✅ **Automatic failover** — VIP moves within seconds
- ✅ **Zero-downtime updates** — Update one Pi at a time
- ✅ **No manual iptables rules** — VIP works via host's 0.0.0.0:53 binding

---

## Architecture

### Network Layout

| Node | IP Address | Role | Priority |
|------|------------|------|----------|
| Pi1 | 192.168.8.250 | Primary (MASTER) | 200 (higher) |
| Pi2 | 192.168.8.243 | Secondary (BACKUP) | 150 (lower) |
| **VIP** | **192.168.8.249** | Virtual IP (floats) | - |

### DNS Flow

```
Clients → VIP (192.168.8.249) → Pi-hole → Unbound → Root DNS Servers
```

### Component Diagram

```
┌─────────────────────────────────────┐    ┌─────────────────────────────────────┐
│  Pi1 (192.168.8.250) — MASTER       │    │  Pi2 (192.168.8.243) — BACKUP       │
│                                      │    │                                      │
│  ┌─────────────────────────────┐    │    │  ┌─────────────────────────────┐    │
│  │  Keepalived                  │◄───┼────┼──│  Keepalived                  │    │
│  │  Priority: 200               │    │    │  │  Priority: 150               │    │
│  │  State: MASTER               │    │    │  │  State: BACKUP               │    │
│  │  VIP: 192.168.8.249 ✓        │    │    │  │  VIP: (standby)              │    │
│  └─────────────────────────────┘    │    │  └─────────────────────────────┘    │
│                                      │    │                                      │
│  ┌─────────────────────────────┐    │    │  ┌─────────────────────────────┐    │
│  │  Pi-hole Primary             │    │    │  │  Pi-hole Secondary           │    │
│  │  Port 53:53 (0.0.0.0)       │    │    │  │  Port 53:53 (0.0.0.0)       │    │
│  │  Port 80:80 (Admin UI)      │    │    │  │  Port 80:80 (Admin UI)      │    │
│  └─────────────┬────────────────┘    │    │  └─────────────┬────────────────┘    │
│                │                     │    │                │                     │
│  ┌─────────────▼────────────────┐    │    │  ┌─────────────▼────────────────┐    │
│  │  Unbound Primary             │    │    │  │  Unbound Secondary           │    │
│  │  Recursive DNS Resolver      │    │    │  │  Recursive DNS Resolver      │    │
│  │  Port 5335 (internal)        │    │    │  │  Port 5335 (internal)        │    │
│  └──────────────────────────────┘    │    │  └──────────────────────────────┘    │
└──────────────────────────────────────┘    └──────────────────────────────────────┘
                                │
                                └───────────┐
                                            │
                               ┌────────────▼────────────┐
                               │ VIP: 192.168.8.249/24   │
                               │ Clients point DNS here  │
                               └─────────────────────────┘
```

---

## Client Contract

### What Clients Need to Know

**Set your DNS to `192.168.8.249` only.**

- The VIP automatically points to whichever Pi is active
- Failover between Pis is automatic (2-5 seconds)
- No client-side changes needed during failover

### Router Configuration

Configure your router's DHCP server to distribute:
- **Primary DNS**: `192.168.8.249`
- **Secondary DNS**: `192.168.8.249` (same VIP)

> Note: Using the same VIP for both prevents clients from bypassing Pi-hole during failover.

---

## How It Works

### Normal Operation

1. Pi1 is MASTER with VIP 192.168.8.249 assigned to eth0
2. Pi2 is BACKUP, monitoring Pi1 via VRRP heartbeats
3. Clients query 192.168.8.249 → routed to Pi1's Pi-hole → Unbound → Internet

### Failover Process

1. Keepalived on Pi1 monitors Pi-hole health via `dig @127.0.0.1 example.com`
2. If Pi-hole fails to respond (or Pi1 goes down), Pi2 detects missing heartbeats
3. Pi2 promotes itself to MASTER and acquires VIP 192.168.8.249
4. Gratuitous ARP announces the VIP move to the network
5. DNS queries automatically route to Pi2
6. When Pi1 recovers, it reclaims VIP (higher priority)

### Failover Time

| Phase | Duration |
|-------|----------|
| Detection | 5-15 seconds |
| Switchover | 1-3 seconds |
| **Total** | **6-18 seconds** |

---

## No Manual iptables Required

The default configuration requires **no manual iptables rules**:

1. Pi-hole containers publish port 53 on `0.0.0.0` (all interfaces)
2. VIP 192.168.8.249 is an IP alias on eth0
3. When VIP is assigned to a host, traffic to VIP:53 goes to that host's Pi-hole

This "just works" because:
- Docker's `-p 53:53` binds to `0.0.0.0:53` on the host
- The VIP is added to eth0 by keepalived
- No DNAT rules are needed — the kernel routes VIP traffic to the local port 53

> **Note**: Legacy documentation may reference iptables DNAT rules. These are optional for advanced troubleshooting only and should not be required in normal operation.

---

## HA Test Suite

### Basic Connectivity Tests

Run these from any LAN client:

```bash
# Test direct connectivity to both Pis
ping -c 3 192.168.8.243    # Pi2 (secondary)
ping -c 3 192.168.8.250    # Pi1 (primary)
ping -c 3 192.168.8.249    # VIP (should respond)

# Test DNS resolution via VIP
dig +short example.com @192.168.8.249

# Test Pi-hole blocking via VIP
dig +short doubleclick.net @192.168.8.249
# Expected: 0.0.0.0 or empty (blocked)
```

### Failover Test

```bash
# Step 1: Identify current MASTER
# On Pi1:
ip -4 addr show eth0 | grep 192.168.8.249
# If VIP appears, Pi1 is MASTER

# On Pi2:
ip -4 addr show eth0 | grep 192.168.8.249
# If VIP appears, Pi2 is MASTER

# Step 2: Stop keepalived on current MASTER
# On current MASTER Pi:
docker stop keepalived

# Step 3: Verify VIP moved
# On the OTHER Pi:
ip -4 addr show eth0 | grep 192.168.8.249
# VIP should now appear here

# Step 4: Test DNS still works via VIP
# From any client:
dig +short example.com @192.168.8.249
# Should still return answers

# Step 5: Restore the original MASTER
# On the Pi where you stopped keepalived:
docker start keepalived

# VIP will return to Pi1 (higher priority)
```

### Health Check Verification

```bash
# Check keepalived status on each Pi
docker logs keepalived --tail 50

# Check Pi-hole health
docker exec pihole_primary dig @127.0.0.1 google.com +short
docker exec pihole_secondary dig @127.0.0.1 google.com +short

# Check Unbound health
docker exec unbound_primary unbound-host example.com
docker exec unbound_secondary unbound-host example.com
```

---

## Configuration Reference

### Environment Variables

Set these in `.env` on each Pi:

| Variable | Pi1 Value | Pi2 Value | Description |
|----------|-----------|-----------|-------------|
| `HOST_IP` | 192.168.8.250 | 192.168.8.243 | This Pi's IP |
| `VIP_ADDRESS` | 192.168.8.249 | 192.168.8.249 | Virtual IP (same) |
| `KEEPALIVED_PRIORITY` | 200 | 150 | Higher = MASTER |
| `PI1_IP` | 192.168.8.250 | 192.168.8.250 | Pi1's IP (same) |
| `PI2_IP` | 192.168.8.243 | 192.168.8.243 | Pi2's IP (same) |
| `VRRP_PASSWORD` | (secure) | (same) | VRRP auth (same) |
| `NETWORK_INTERFACE` | eth0 | eth0 | Network interface |
| `VIRTUAL_ROUTER_ID` | 51 | 51 | VRRP ID (same) |

### Deployment Commands

```bash
# On Pi1 (primary):
cd stacks/dns
docker compose --profile two-pi-ha-pi1 up -d

# On Pi2 (secondary):
cd stacks/dns
docker compose --profile two-pi-ha-pi2 up -d
```

---

## Troubleshooting

### VIP Not Appearing on Either Pi

```bash
# Check keepalived is running
docker ps | grep keepalived

# Check keepalived logs
docker logs keepalived

# Verify VRRP_PASSWORD matches on both Pis
grep VRRP_PASSWORD .env

# Check VRRP packets (from host)
sudo tcpdump -i eth0 vrrp
```

### DNS Not Working Via VIP

```bash
# Test DNS directly on each Pi
dig @192.168.8.250 example.com  # Pi1
dig @192.168.8.243 example.com  # Pi2

# If direct works but VIP doesn't:
# Check VIP is assigned
ip addr show eth0 | grep 192.168.8.249

# Check Pi-hole is listening on 0.0.0.0:53
docker exec pihole_primary netstat -tlnp | grep :53
```

### Frequent Failovers (VIP Flapping)

```bash
# Increase thresholds in keepalived check script
# Edit keepalived entrypoint.sh or check_dns.sh

# Check system resources
free -h
df -h

# Review keepalived logs for health check failures
docker logs keepalived | grep -i "check\|fail\|success"
```

---

## See Also

- [install-two-pi-ha.md](install-two-pi-ha.md) — Installation guide
- [health-and-ha.md](health-and-ha.md) — Health checking details
- [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) — General troubleshooting
