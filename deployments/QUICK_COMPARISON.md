# Quick Visual Comparison of Deployment Options

## Side-by-Side Architecture Comparison

### HighAvail_1Pi2P2U (Single Pi)
```
┌─────────────────────────────────┐
│  Raspberry Pi #1                │
│  IP: 192.168.8.250              │
│  ┌───────────────────────────┐  │
│  │  Pi-hole Primary   .251   │  │
│  │  Pi-hole Secondary .252   │  │
│  │  Unbound Primary   .253   │  │
│  │  Unbound Secondary .254   │  │
│  │  Keepalived VIP    .255   │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘

Hardware: 1x Pi (4GB RAM)
Redundancy: Container-level only
Failover: 5 seconds (local)
Cost: $
Best for: Home labs, testing
```

### HighAvail_2Pi1P1U (Two Pis - Simplified) ⭐
```
┌─────────────────────┐    ┌─────────────────────┐
│  Raspberry Pi #1    │    │  Raspberry Pi #2    │
│  IP: 192.168.8.11   │    │  IP: 192.168.8.12   │
│  ┌─────────────────┐│    │  ┌─────────────────┐│
│  │ Pi-hole   .251  ││    │  │ Pi-hole   .252  ││
│  │ Unbound   .253  ││    │  │ Unbound   .254  ││
│  │ Keepalived      ││◄──►│  │ Keepalived      ││
│  │   MASTER        ││VRRP│  │   BACKUP        ││
│  └─────────────────┘│    │  └─────────────────┘│
└──────────┬──────────┘    └──────────┬──────────┘
           └───────┬──────────────────┘
                   ▼
         VIP: 192.168.8.255

Hardware: 2x Pi (4GB RAM each)
Redundancy: Hardware + Node-level
Failover: 5-10 seconds (network)
Cost: $$
Best for: Production ⭐ RECOMMENDED
```

### HighAvail_2Pi2P2U (Two Pis - Full)
```
┌─────────────────────┐    ┌─────────────────────┐
│  Raspberry Pi #1    │    │  Raspberry Pi #2    │
│  IP: 192.168.8.11   │    │  IP: 192.168.8.12   │
│  ┌─────────────────┐│    │  ┌─────────────────┐│
│  │ Pi-hole 1  .251 ││    │  │ Pi-hole 1  .255 ││
│  │ Pi-hole 2  .252 ││    │  │ Pi-hole 2  .256 ││
│  │ Unbound 1  .253 ││    │  │ Unbound 1  .257 ││
│  │ Unbound 2  .254 ││    │  │ Unbound 2  .258 ││
│  │ Keepalived      ││◄──►│  │ Keepalived      ││
│  │   MASTER        ││VRRP│  │   BACKUP        ││
│  └─────────────────┘│    │  └─────────────────┘│
└──────────┬──────────┘    └──────────┬──────────┘
           └───────┬──────────────────┘
                   ▼
         VIP: 192.168.8.259

Hardware: 2x Pi (8GB RAM each)
Redundancy: Container + Hardware + Node
Failover: 5-10 seconds (multiple paths)
Cost: $$$
Best for: Mission-critical
```

---

## Feature Matrix

| Feature | 1Pi2P2U | 2Pi1P1U | 2Pi2P2U |
|---------|---------|---------|---------|
| **Hardware** | | | |
| Raspberry Pis | 1 | 2 | 2 |
| RAM per Pi | 4GB | 4GB | 8GB |
| Cooling | Standard | Standard | Active Fan |
| | | | |
| **Services** | | | |
| Pi-hole per Pi | 2 | 1 | 2 |
| Unbound per Pi | 2 | 1 | 2 |
| Total Containers | 6 | 4 | 12 |
| | | | |
| **Redundancy** | | | |
| Container-level HA | ✅ | ❌ | ✅ |
| Hardware HA | ❌ | ✅ | ✅ |
| Node-level HA | ❌ | ✅ | ✅ |
| Redundancy Layers | 1 | 1 | 3 |
| | | | |
| **Performance** | | | |
| Failover Time | 5s | 10s | 5-10s |
| DNS Query Latency | Low | Low | Lowest |
| Resource Usage | Med | Med | High |
| | | | |
| **Management** | | | |
| Setup Complexity | Low | Med | High |
| Management Effort | Low | Med | High |
| Sync Complexity | Low | Med | High |
| | | | |
| **Cost** | | | |
| Hardware Cost | $ | $$ | $$$ |
| Power Usage | Low | Med | High |
| Maintenance Time | Low | Med | High |

---

## When to Choose Each Option

### Choose HighAvail_1Pi2P2U if:
```
✅ You have only one Raspberry Pi
✅ Budget is limited
✅ This is for learning/testing
✅ Container-level HA is sufficient
✅ You can tolerate brief hardware outages

❌ Don't choose if:
   • You need protection against hardware failures
   • This is for production use
   • Downtime is unacceptable
```

### Choose HighAvail_2Pi1P1U if: ⭐ RECOMMENDED
```
✅ You have two Raspberry Pis
✅ You want hardware redundancy
✅ You need production-level reliability
✅ You prefer balanced complexity
✅ Each Pi has 4GB+ RAM
✅ You want automatic failover
✅ This is for your home network or small office

❌ Don't choose if:
   • You only have one Pi (use 1Pi2P2U)
   • You need container-level HA per node (use 2Pi2P2U)
```

### Choose HighAvail_2Pi2P2U if:
```
✅ You have two powerful Pis (8GB RAM)
✅ You need MAXIMUM redundancy
✅ DNS is mission-critical
✅ You can handle high complexity
✅ You need to survive multiple concurrent failures
✅ You have active cooling on both Pis
✅ This is for a business or critical infrastructure

❌ Don't choose if:
   • Your Pis have only 4GB RAM (use 2Pi1P1U)
   • You want simple management (use 2Pi1P1U)
   • This is just for home use (use 2Pi1P1U)
   • Budget is a concern (use 2Pi1P1U)
```

---

## Deployment Paths

### Path 1: Start Simple, Upgrade Later
```
Step 1: Deploy HighAvail_1Pi2P2U
        ↓ (learn and test)
Step 2: Get second Pi
        ↓
Step 3: Migrate to HighAvail_2Pi1P1U
        ↓ (if more redundancy needed)
Step 4: Upgrade to HighAvail_2Pi2P2U
```

### Path 2: Go Direct to Production
```
Step 1: Get two Raspberry Pis (4GB)
        ↓
Step 2: Deploy HighAvail_2Pi1P1U
        ↓ (use in production)
Step 3: (Optional) Upgrade to HighAvail_2Pi2P2U
        if you need maximum redundancy
```

---

## Quick Setup Commands

### Using Interactive Wizard (Recommended)
```bash
cd rpi-ha-dns-stack
bash scripts/interactive-setup.sh
```
The wizard will detect your hardware and recommend the best option!

### Manual Setup

**For HighAvail_1Pi2P2U:**
```bash
cd deployments/HighAvail_1Pi2P2U
cp .env.example .env
nano .env  # configure
docker compose up -d
```

**For HighAvail_2Pi1P1U:**
```bash
# On Pi #1:
cd deployments/HighAvail_2Pi1P1U/node1
cp .env.example .env
nano .env  # configure
docker compose up -d

# On Pi #2:
cd deployments/HighAvail_2Pi1P1U/node2
cp .env.example .env
nano .env  # configure
docker compose up -d
```

**For HighAvail_2Pi2P2U:**
```bash
# On Pi #1:
cd deployments/HighAvail_2Pi2P2U/node1
cp .env.example .env
nano .env  # configure
docker compose up -d

# On Pi #2:
cd deployments/HighAvail_2Pi2P2U/node2
cp .env.example .env
nano .env  # configure
docker compose up -d
```

---

## IP Address Quick Reference

### HighAvail_1Pi2P2U
| Service | IP Address |
|---------|------------|
| Pi-hole Primary | 192.168.8.251 |
| Pi-hole Secondary | 192.168.8.252 |
| Unbound Primary | 192.168.8.253 |
| Unbound Secondary | 192.168.8.254 |
| **VIP (use this)** | **192.168.8.255** |

### HighAvail_2Pi1P1U
| Service | IP Address |
|---------|------------|
| Pi #1 Host | 192.168.8.11 |
| Pi #2 Host | 192.168.8.12 |
| Pi-hole on Pi #1 | 192.168.8.251 |
| Pi-hole on Pi #2 | 192.168.8.252 |
| Unbound on Pi #1 | 192.168.8.253 |
| Unbound on Pi #2 | 192.168.8.254 |
| **VIP (use this)** | **192.168.8.255** |

### HighAvail_2Pi2P2U
| Service | IP Address |
|---------|------------|
| Pi #1 Host | 192.168.8.11 |
| Pi #2 Host | 192.168.8.12 |
| Pi-hole #1 on Pi #1 | 192.168.8.251 |
| Pi-hole #2 on Pi #1 | 192.168.8.252 |
| Pi-hole #1 on Pi #2 | 192.168.8.255 |
| Pi-hole #2 on Pi #2 | 192.168.8.256 |
| Unbound #1 on Pi #1 | 192.168.8.253 |
| Unbound #2 on Pi #1 | 192.168.8.254 |
| Unbound #1 on Pi #2 | 192.168.8.257 |
| Unbound #2 on Pi #2 | 192.168.8.258 |
| **VIP (use this)** | **192.168.8.259** |

---

## The Bottom Line

**Most users should choose HighAvail_2Pi1P1U (if they have 2 Pis) or HighAvail_1Pi2P2U (if they have 1 Pi).**

The 2Pi2P2U option is powerful but complex - only choose it if you truly need mission-critical uptime and can dedicate the time to manage it properly.

**Use the interactive setup wizard** - it makes the right recommendation based on your actual hardware!
