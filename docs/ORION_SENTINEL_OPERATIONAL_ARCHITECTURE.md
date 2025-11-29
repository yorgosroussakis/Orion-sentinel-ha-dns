# Orion Sentinel Operational Architecture

**Version 1.0 - Production-Ready DNS HA Setup**

---

## 📖 Overview

This document describes the target operational architecture for Orion Sentinel DNS HA - a production-ready high-availability DNS solution using two Raspberry Pis with a floating VIP.

---

## 🎯 Target Architecture

### Physical Nodes

| Node | IP Address | Role | Services |
|------|------------|------|----------|
| **Pi #1** | 192.168.8.241 | Primary DNS | Pi-hole, Unbound, Keepalived (MASTER) |
| **Pi #2** | 192.168.8.242 | Secondary DNS | Pi-hole, Unbound, Keepalived (BACKUP) |
| **NetSec Pi** | 192.168.8.243 | Security | Suricata IDS, AI Service |
| **CoreSrv** | 192.168.8.100 | Observability | Prometheus, Grafana, Loki, Uptime Kuma |

### Virtual IP (VIP)

| VIP | IP Address | Purpose |
|-----|------------|---------|
| **DNS VIP** | 192.168.8.249 | Floating IP that clients use for DNS |

### DNS Service IPs

| Service | Primary IP | Secondary IP |
|---------|------------|--------------|
| **Pi-hole** | 192.168.8.251 | 192.168.8.252 |
| **Unbound** | 192.168.8.253 | 192.168.8.254 |

---

## 🏗️ Architecture Diagram

```
                              ┌─────────────────────┐
                              │    DHCP/Router      │
                              │ Hands out VIP as    │
                              │ DNS: 192.168.8.249  │
                              └──────────┬──────────┘
                                         │
                                         ▼
                         ┌───────────────────────────────┐
                         │   Virtual IP: 192.168.8.249   │
                         │   (Floats between Pi #1 & #2) │
                         └───────────────┬───────────────┘
                                         │
                    ┌────────────────────┴────────────────────┐
                    │                                          │
                    ▼                                          ▼
    ┌───────────────────────────────┐      ┌───────────────────────────────┐
    │  Raspberry Pi #1 (PRIMARY)    │      │  Raspberry Pi #2 (SECONDARY)  │
    │  Physical IP: 192.168.8.241   │      │  Physical IP: 192.168.8.242   │
    │                               │      │                               │
    │  ┌─────────────────────────┐  │      │  ┌─────────────────────────┐  │
    │  │ Keepalived (MASTER)     │  │      │  │ Keepalived (BACKUP)     │  │
    │  │ Priority: 100           │◄─┼──────┼─►│ Priority: 90            │  │
    │  │ VRRP Heartbeats         │  │      │  │ VRRP Heartbeats         │  │
    │  └─────────────────────────┘  │      │  └─────────────────────────┘  │
    │                               │      │                               │
    │  ┌─────────────────────────┐  │      │  ┌─────────────────────────┐  │
    │  │ Pi-hole                 │  │      │  │ Pi-hole                 │  │
    │  │ IP: 192.168.8.251       │  │ Sync │  │ IP: 192.168.8.252       │  │
    │  │ (DNS Blocking)          │◄─┼──────┼─►│ (DNS Blocking)          │  │
    │  └───────────┬─────────────┘  │      │  └───────────┬─────────────┘  │
    │              │                │      │              │                │
    │  ┌───────────▼─────────────┐  │      │  ┌───────────▼─────────────┐  │
    │  │ Unbound                 │  │      │  │ Unbound                 │  │
    │  │ IP: 192.168.8.253       │  │      │  │ IP: 192.168.8.254       │  │
    │  │ (Recursive DNS+DNSSEC)  │  │      │  │ (Recursive DNS+DNSSEC)  │  │
    │  └─────────────────────────┘  │      │  └─────────────────────────┘  │
    │                               │      │                               │
    │  ┌─────────────────────────┐  │      │  ┌─────────────────────────┐  │
    │  │ Node Exporter           │  │      │  │ Node Exporter           │  │
    │  │ Pi-hole Exporter        │──┼──────┼──│ Pi-hole Exporter        │  │
    │  │ (Metrics Export)        │  │      │  │ (Metrics Export)        │  │
    │  └─────────────────────────┘  │      │  └─────────────────────────┘  │
    └───────────────────────────────┘      └───────────────────────────────┘
                    │                                          │
                    └────────────────────┬─────────────────────┘
                                         │
                           Metrics & Logs│
                                         ▼
                    ┌───────────────────────────────────────────┐
                    │      Dell CoreSrv: 192.168.8.100          │
                    │                                           │
                    │  ┌─────────────┐  ┌─────────────────────┐ │
                    │  │ Prometheus  │  │ Grafana             │ │
                    │  │ (Metrics)   │  │ (Dashboards)        │ │
                    │  └─────────────┘  └─────────────────────┘ │
                    │  ┌─────────────┐  ┌─────────────────────┐ │
                    │  │ Loki        │  │ Uptime Kuma         │ │
                    │  │ (Logs)      │  │ (Status Monitoring) │ │
                    │  └─────────────┘  └─────────────────────┘ │
                    └───────────────────────────────────────────┘
```

---

## ⚡ How It Works

### Normal Operation

1. **Clients** receive DNS VIP (192.168.8.249) from DHCP
2. **Pi #1** (MASTER) owns the VIP and handles all DNS queries
3. **Pi #2** (BACKUP) monitors via VRRP heartbeats
4. **Configuration sync** keeps Pi-hole settings identical on both nodes
5. **Metrics** are scraped by CoreSrv Prometheus

### Failover Scenario

1. **Pi #1 fails** (power, hardware, network, or crash)
2. **Pi #2 detects** missing VRRP heartbeats (within 3 seconds)
3. **Pi #2 promotes itself** to MASTER state
4. **VIP moves** to Pi #2 (gratuitous ARP announcement)
5. **DNS continues** seamlessly on Pi #2
6. **Failover time**: 5-10 seconds typical

### Failback Scenario

1. **Pi #1 recovers** and rejoins the network
2. **Pi #1 reclaims MASTER** (higher priority: 100 vs 90)
3. **VIP returns** to Pi #1
4. **Pi #2 returns** to BACKUP state

---

## 📊 Monitoring & Observability

### Grafana Dashboards

| Dashboard | Purpose |
|-----------|---------|
| **Orion Sentinel - Home** | Single pane of glass for all services |
| **DNS HA Overview** | DNS-specific metrics and status |

### Key Metrics

| Metric | Source | Description |
|--------|--------|-------------|
| `probe_success{instance="192.168.8.249"}` | Blackbox | VIP availability (1=UP, 0=DOWN) |
| `up{job="pihole-*"}` | Pi-hole Exporter | Pi-hole service status |
| `up{job="unbound-*"}` | Unbound Exporter | Unbound service status |
| `pihole_dns_queries_today` | Pi-hole Exporter | Total DNS queries |
| `pihole_ads_percentage_blocked_today` | Pi-hole Exporter | Ad blocking percentage |
| `probe_dns_lookup_time_seconds` | Blackbox | DNS latency |

### Critical Alerts

| Alert | Severity | Description |
|-------|----------|-------------|
| `VIPProbeFailed` | 🔴 Critical | VIP is unreachable - DNS may be down |
| `AllPiHolesDown` | 🔴 Critical | Both Pi-hole instances are down |
| `AllUnboundDown` | 🔴 Critical | Both Unbound instances are down |
| `HADegraded` | 🟡 Warning | Only one DNS Pi is online |
| `HighDNSLatency` | 🟡 Warning | DNS lookup time > 1 second |

---

## 🔧 Configuration

### Router/DHCP Configuration

Configure your router to hand out the VIP as the DNS server:

```
Primary DNS:   192.168.8.249  (VIP)
Secondary DNS: 192.168.8.251  (Pi-hole Primary - optional fallback)
```

### Example .env Configuration

**Pi #1 (.env):**
```bash
NODE_ROLE=primary
NODE_IP=192.168.8.241
PEER_IP=192.168.8.242
VIP_ADDRESS=192.168.8.249
KEEPALIVED_PRIORITY=100
VIRTUAL_ROUTER_ID=51
```

**Pi #2 (.env):**
```bash
NODE_ROLE=secondary
NODE_IP=192.168.8.242
PEER_IP=192.168.8.241
VIP_ADDRESS=192.168.8.249
KEEPALIVED_PRIORITY=90
VIRTUAL_ROUTER_ID=51
```

---

## 🚀 Deployment Checklist

### Pre-Deployment

- [ ] Two Raspberry Pis with Raspberry Pi OS (64-bit)
- [ ] Docker and Docker Compose installed on both
- [ ] Static IPs assigned to both Pis
- [ ] SSH access configured between nodes
- [ ] Network interface identified (eth0 or similar)

### Deployment Steps

1. [ ] Clone repository on both Pis
2. [ ] Configure `.env` files on both nodes
3. [ ] Create macvlan Docker network on both nodes
4. [ ] Deploy services on Pi #1 (primary)
5. [ ] Deploy services on Pi #2 (secondary)
6. [ ] Verify VIP assignment on Pi #1
7. [ ] Test DNS resolution via VIP
8. [ ] Test failover by stopping keepalived on Pi #1
9. [ ] Configure router DHCP to use VIP as DNS

### Post-Deployment

- [ ] Set up monitoring exporters
- [ ] Configure Prometheus scraping
- [ ] Import Grafana dashboards
- [ ] Verify alerts are working
- [ ] Document any custom configurations

---

## 📝 Operational Procedures

### Daily Operations

- Check Grafana "Orion Sentinel - Home" dashboard
- Review any alerts in the last 24 hours
- Verify both Pis are healthy

### Weekly Maintenance

- Review keepalived logs for failover events
- Check disk usage on all nodes
- Verify backup jobs are running

### Monthly Tasks

- Test failover manually
- Update Docker images
- Review and update blocklists
- Check for security updates

### Quarterly Tasks

- Full system backup
- Review alert thresholds
- Capacity planning review
- Documentation update

---

## 🆘 Troubleshooting

### VIP Not Responding

1. Check which Pi owns the VIP: `ip addr show eth0 | grep 249`
2. Verify keepalived is running: `docker logs keepalived`
3. Check VRRP traffic: `tcpdump -i eth0 -nn vrrp`
4. Verify network connectivity between Pis

### Split Brain (Both MASTER)

1. Check network connectivity: `ping <peer_ip>`
2. Verify VIRTUAL_ROUTER_ID is same on both
3. Check firewall rules for VRRP traffic
4. Review keepalived logs for errors

### DNS Not Resolving

1. Test via VIP: `dig @192.168.8.249 google.com`
2. Test via primary: `dig @192.168.8.251 google.com`
3. Check Pi-hole logs: `docker logs pihole_primary`
4. Verify Unbound is resolving: `dig @192.168.8.253 google.com +short`

---

## 🔗 Related Documentation

- [Deployment Guide](../deployments/HighAvail_2Pi1P1U/README.md)
- [Operational Runbook](../OPERATIONAL_RUNBOOK.md)
- [Troubleshooting Guide](../TROUBLESHOOTING.md)
- [Disaster Recovery](../DISASTER_RECOVERY.md)
- [SPoG Integration Guide](./SPOG_INTEGRATION_GUIDE.md)

---

## 📚 Summary

The Orion Sentinel DNS HA architecture provides:

✅ **High Availability** - Automatic failover between two Pis  
✅ **Privacy** - Network-wide ad blocking via Pi-hole  
✅ **Security** - DNSSEC validation via Unbound  
✅ **Observability** - Comprehensive monitoring via Prometheus/Grafana  
✅ **Simplicity** - Single VIP for all clients  
✅ **Reliability** - Production-ready configuration  

This is the recommended setup for users wanting reliable DNS with hardware-level redundancy.
