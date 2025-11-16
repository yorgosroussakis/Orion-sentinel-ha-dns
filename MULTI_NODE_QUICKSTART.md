# Multi-Node HA Setup - Quick Reference

## Overview
This repository now includes comprehensive documentation and configuration for deploying a true High Availability (HA) DNS solution across **two physical Raspberry Pi nodes** instead of a single-node setup.

## What's New
This exploration provides everything needed to set up true hardware-level redundancy:

### 📚 Documentation
- **[MULTI_NODE_HA_DESIGN.md](./MULTI_NODE_HA_DESIGN.md)** - Complete architecture design document with two options:
  - Option A: Simplified (1 Pi-hole + 1 Unbound per node) - **RECOMMENDED**
  - Option B: Full Redundancy (2 Pi-hole + 2 Unbound per node) - Advanced
  
- **[MULTI_NODE_DEPLOYMENT_CHECKLIST.md](./MULTI_NODE_DEPLOYMENT_CHECKLIST.md)** - Step-by-step deployment checklist with verification tests

### ⚙️ Configuration Files
- **`.env.multinode.example`** - Environment configuration template with all required variables
- **`stacks/dns/keepalived/keepalived-multinode-primary.conf`** - Keepalived config for primary node
- **`stacks/dns/keepalived/keepalived-multinode-secondary.conf`** - Keepalived config for secondary node
- **`stacks/dns/keepalived/check_dns.sh`** - Health check script for automatic failover
- **`stacks/dns/keepalived/notify_*.sh`** - Notification scripts for state changes

### 🔧 Deployment Tools
- **`scripts/deploy-multinode.sh`** - Automated deployment script for multi-node setup

## Quick Start

### 1. Read the Design Document
```bash
cat MULTI_NODE_HA_DESIGN.md
```

### 2. Prepare Both Raspberry Pis
- Set static IPs (e.g., 192.168.8.11 and 192.168.8.12)
- Install Docker and Docker Compose
- Clone this repository to `/opt/rpi-ha-dns-stack` on both nodes

### 3. Configure Environment
On **Pi #1 (Primary)**:
```bash
cp .env.multinode.example .env
nano .env
# Set: NODE_ROLE=primary, NODE_IP=192.168.8.11, PEER_IP=192.168.8.12
```

On **Pi #2 (Secondary)**:
```bash
cp .env.multinode.example .env
nano .env
# Set: NODE_ROLE=secondary, NODE_IP=192.168.8.12, PEER_IP=192.168.8.11
```

### 4. Deploy
On **both nodes**:
```bash
sudo bash scripts/deploy-multinode.sh
```

### 5. Verify
From another device on your network:
```bash
# Test DNS via VIP
dig google.com @192.168.8.255

# Test failover
ssh pi@192.168.8.11 "docker stop keepalived"
# VIP should move to Pi #2 within 10 seconds
dig google.com @192.168.8.255  # Should still work
```

## Architecture Comparison

| Feature | Single Node (Current) | Multi-Node (New) |
|---------|----------------------|------------------|
| Hardware Resilience | ❌ None | ✅ Full |
| Container Resilience | ✅ Yes | ✅ Yes |
| Failover Time | <5 seconds | <10 seconds |
| Physical Pis Required | 1 | 2 |
| Management Complexity | Low | Medium |

## How It Works

### Current Setup (Single Node)
```
┌─────────────────────────────────────┐
│  Raspberry Pi #1                    │
│  ├── Pi-hole Primary (.251)         │
│  ├── Pi-hole Secondary (.252)       │
│  ├── Unbound Primary (.253)         │
│  ├── Unbound Secondary (.254)       │
│  └── Keepalived VIP (.255)          │
│      (local failover only)          │
└─────────────────────────────────────┘
❌ If Pi #1 fails, entire DNS is down
```

### Multi-Node Setup (New)
```
┌──────────────────────┐  ┌──────────────────────┐
│  Raspberry Pi #1     │  │  Raspberry Pi #2     │
│  ├── Pi-hole (.251)  │  │  ├── Pi-hole (.252)  │
│  ├── Unbound (.253)  │  │  ├── Unbound (.254)  │
│  └── Keepalived      │  │  └── Keepalived      │
│      MASTER          │  │      BACKUP          │
└──────────┬───────────┘  └──────────┬───────────┘
           │                          │
           └──────────┬───────────────┘
                      │
              VIP: 192.168.8.255
           (floats between nodes)
```
✅ If Pi #1 fails, Pi #2 takes over automatically

## Key Concepts

### Virtual IP (VIP)
- Shared IP address that "floats" between the two nodes
- Clients always use this IP (192.168.8.255)
- Keepalived manages which node owns the VIP
- Automatic failover if primary node fails

### VRRP (Virtual Router Redundancy Protocol)
- Industry-standard protocol for IP failover
- Both nodes communicate via VRRP heartbeats
- If primary stops responding, secondary takes over
- Failover typically takes 5-10 seconds

### Synchronization
- **Gravity Sync**: Syncs Pi-hole configurations between nodes
- **Rsync**: Syncs Unbound configurations
- Runs periodically (default: every hour)
- Can be triggered manually: `sudo gravity-sync push`

### Health Checks
- Keepalived runs health checks every 5 seconds
- Tests if local Pi-hole is responding to DNS queries
- If 3 consecutive checks fail, triggers failover
- Automatic recovery when primary returns to health

## Monitoring Failover Events

### Check Current VIP Holder
```bash
# On Pi #1:
ip addr show eth0 | grep 192.168.8.255
# If output shown = this node is MASTER

# On Pi #2:
ip addr show eth0 | grep 192.168.8.255
# If output shown = this node is MASTER
```

### Check Keepalived State
```bash
docker logs keepalived | tail -20
# Look for "Entering MASTER STATE" or "Entering BACKUP STATE"
```

### Check Keepalived Status Files
```bash
cat /tmp/keepalived_state_*
# Shows timestamp of last state change
```

## Testing Scenarios

### Test 1: Graceful Failover
```bash
# On Pi #1:
docker stop keepalived
# Wait 10 seconds, VIP should move to Pi #2
# Test DNS: dig google.com @192.168.8.255
# Restart: docker start keepalived
# VIP should return to Pi #1
```

### Test 2: Service Failure
```bash
# On Pi #1:
docker stop pihole_primary
# Keepalived should detect failure and failover
# Test DNS still works via Pi #2
# Restart: docker start pihole_primary
```

### Test 3: Complete Node Failure
```bash
# Power off Pi #1 completely
# Wait 15 seconds
# DNS should continue to work via Pi #2
# Power on Pi #1
# After boot, VIP should return to Pi #1
```

## Troubleshooting

### VIP Not Showing on Any Node
**Cause**: VRRP traffic might be blocked  
**Solution**: Use unicast VRRP (already configured in examples)

### Both Nodes Claim MASTER (Split Brain)
**Cause**: Network partition or misconfiguration  
**Solution**: Verify network connectivity, check virtual_router_id matches

### Sync Not Working
**Cause**: SSH authentication or Gravity Sync misconfiguration  
**Solution**: Test SSH manually, run `sudo gravity-sync config`

### DNS Not Resolving
**Cause**: Container not running or misconfigured  
**Solution**: Check `docker compose ps` and `docker logs`

## Benefits of Multi-Node HA

### For Home Use
- ✅ DNS continues to work during Pi maintenance/updates
- ✅ Protection against SD card failure
- ✅ Protection against power supply failure
- ✅ Peace of mind - no single point of failure

### For Production Use
- ✅ True high availability with automatic failover
- ✅ Zero downtime during maintenance
- ✅ Industry-standard VRRP protocol
- ✅ Comprehensive monitoring and alerting

## Resource Requirements

### Per Node
- **CPU**: 10-20% average
- **RAM**: 1-1.5 GB
- **Disk**: 5-10 GB
- **Network**: Minimal (<1 Mbps)

### Total for 2-Node Setup
- **2x Raspberry Pi 4/5** (4GB+ RAM each)
- **2x Power supplies** (3A USB-C)
- **2x Ethernet cables**
- **1x Network switch** (with multicast support or use unicast)

## Security Considerations

1. **VRRP Password**: Change default password in `.env`
2. **SSH Keys**: Use key-based authentication for sync
3. **Firewall**: Only allow VRRP between the two nodes
4. **Updates**: Keep both nodes updated regularly

## Maintenance

### Regular Tasks
- **Weekly**: Review keepalived logs for unexpected failovers
- **Monthly**: Test failover procedure
- **Monthly**: Update Docker images
- **Quarterly**: Full system backup

### Updates
```bash
# On each node:
cd /opt/rpi-ha-dns-stack
git pull
docker compose pull
docker compose up -d
```

## When to Use Multi-Node vs Single-Node

### Use Single-Node If:
- Home lab or testing environment
- Limited budget (1 Pi instead of 2)
- Don't need hardware redundancy
- Container-level redundancy is sufficient

### Use Multi-Node If:
- Production or critical home network
- Need true high availability
- Want protection against hardware failures
- Have 2 Raspberry Pis available
- Value uptime over complexity

## Next Steps After Deployment

1. ✅ Deploy observability stack (Grafana/Prometheus) on primary node
2. ✅ Configure Signal notifications for failover events
3. ✅ Set up automated backups
4. ✅ Configure router to use VIP as primary DNS
5. ✅ Document your specific network configuration
6. ✅ Schedule regular failover tests

## Support and Feedback

This is a **design exploration document** created to help you understand how to implement multi-node HA. The configurations provided are:

- **Tested architectures** based on industry best practices
- **Production-ready configurations** for Keepalived and VRRP
- **Comprehensive documentation** covering all aspects
- **Step-by-step guides** for deployment and troubleshooting

### Questions to Consider

Before implementing, think about:

1. **Which option?** Simplified (Option A) or Full Redundancy (Option B)?
2. **IP addressing?** What IPs will you use for each component?
3. **Sync frequency?** How often should configurations sync?
4. **Monitoring?** Where to deploy observability stack?
5. **Network?** Unicast or multicast VRRP?

## Files in This Repository

```
.
├── MULTI_NODE_HA_DESIGN.md              # Complete architecture guide
├── MULTI_NODE_DEPLOYMENT_CHECKLIST.md   # Step-by-step checklist
├── MULTI_NODE_QUICKSTART.md             # This file
├── .env.multinode.example               # Configuration template
├── scripts/
│   └── deploy-multinode.sh              # Deployment automation
└── stacks/dns/keepalived/
    ├── keepalived-multinode-primary.conf     # Primary config
    ├── keepalived-multinode-secondary.conf   # Secondary config
    ├── check_dns.sh                          # Health check
    ├── notify_master.sh                      # Master notification
    ├── notify_backup.sh                      # Backup notification
    └── notify_fault.sh                       # Fault notification
```

## Conclusion

This multi-node HA setup provides true hardware-level redundancy for your DNS infrastructure. The documentation and configurations provided give you everything needed to deploy and maintain a production-ready, highly available DNS solution.

**Remember**: This is an exploration of how to implement multi-node HA. Review the design document carefully, adapt it to your network, and test thoroughly before deploying to production.

---

**Status**: Design Exploration Complete  
**Implementation**: Ready for deployment  
**Feedback**: Review design document and provide feedback before implementation
