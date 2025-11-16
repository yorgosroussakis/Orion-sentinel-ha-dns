# Visual Architecture Comparison

This document provides clear visual comparisons between the current single-node setup and the proposed multi-node HA setups.

## Current Architecture: Single-Node HA

### Network Topology
```
Internet
   ↓
Gateway (192.168.8.1)
   ↓
Home Network (192.168.8.0/24)
   ↓
┌────────────────────────────────────────────────────────────────┐
│                   Raspberry Pi #1 (192.168.8.250)              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Docker Host                            │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐         │  │
│  │  │  Pi-hole   │  │  Pi-hole   │  │            │         │  │
│  │  │  Primary   │  │ Secondary  │  │ Keepalived │         │  │
│  │  │  .251      │  │   .252     │  │    VIP     │         │  │
│  │  │            │  │            │  │   .255     │         │  │
│  │  └─────┬──────┘  └─────┬──────┘  └────────────┘         │  │
│  │        │               │                                  │  │
│  │  ┌─────▼──────┐  ┌─────▼──────┐                         │  │
│  │  │  Unbound   │  │  Unbound   │                         │  │
│  │  │  Primary   │  │ Secondary  │                         │  │
│  │  │   .253     │  │   .254     │                         │  │
│  │  └────────────┘  └────────────┘                         │  │
│  │                                                           │  │
│  │  All on macvlan network                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘

✅ Pros:
   - Simple setup (one physical device)
   - Container-level redundancy
   - Quick failover (<5 seconds)
   - Lower cost (1 Pi)

❌ Cons:
   - Single point of failure (hardware)
   - No protection against:
     - SD card failure
     - Power supply failure
     - Hardware failure
     - Physical damage
   - If Pi #1 goes down, DNS is completely offline
```

### Failure Scenarios
```
Scenario 1: Pi-hole Primary Container Crash
┌─────────────────────────┐
│ ✅ RECOVERS QUICKLY     │
│ Keepalived detects     │
│ failure and routes     │
│ to Secondary           │
│ Time: <5 seconds       │
└─────────────────────────┘

Scenario 2: Entire Raspberry Pi Failure
┌─────────────────────────┐
│ ❌ COMPLETE OUTAGE     │
│ All containers down    │
│ No failover possible   │
│ Manual intervention    │
│ required               │
└─────────────────────────┘
```

---

## Proposed Architecture: Multi-Node HA (Option A - Recommended)

### Network Topology
```
Internet
   ↓
Gateway (192.168.8.1)
   ↓
Home Network (192.168.8.0/24)
   ↓
┌──────────────────────────────┐    ┌──────────────────────────────┐
│  Raspberry Pi #1             │    │  Raspberry Pi #2             │
│  Physical IP: 192.168.8.11   │    │  Physical IP: 192.168.8.12   │
│  ┌────────────────────────┐  │    │  ┌────────────────────────┐  │
│  │  Docker Host           │  │    │  │  Docker Host           │  │
│  │  ┌──────────────────┐  │  │    │  │  ┌──────────────────┐  │  │
│  │  │   Pi-hole        │  │  │    │  │  │   Pi-hole        │  │  │
│  │  │   Primary        │  │  │    │  │  │   Secondary      │  │  │
│  │  │   .251           │◄─┼──┼────┼──┼──┤   .252           │  │  │
│  │  │                  │  │  │    │  │  │                  │  │  │
│  │  └────────┬─────────┘  │  │    │  │  └────────┬─────────┘  │  │
│  │           │             │  │    │  │           │             │  │
│  │  ┌────────▼─────────┐  │  │    │  │  ┌────────▼─────────┐  │  │
│  │  │   Unbound        │  │  │    │  │  │   Unbound        │  │  │
│  │  │   Primary        │  │  │    │  │  │   Secondary      │  │  │
│  │  │   .253           │◄─┼──┼────┼──┼──┤   .254           │  │  │
│  │  └──────────────────┘  │  │    │  │  └──────────────────┘  │  │
│  │                        │  │    │  │                        │  │
│  │  ┌──────────────────┐  │  │    │  │  ┌──────────────────┐  │  │
│  │  │  Keepalived      │  │  │    │  │  │  Keepalived      │  │  │
│  │  │  MASTER          │◄─┼──┼────┼──┼─►│  BACKUP          │  │  │
│  │  │  Priority: 100   │  │  │    │  │  │  Priority: 90    │  │  │
│  │  └──────────────────┘  │  │    │  │  └──────────────────┘  │  │
│  └────────────────────────┘  │    │  └────────────────────────┘  │
│              │                │    │              │                │
└──────────────┼────────────────┘    └──────────────┼────────────────┘
               │                                    │
               └────────────┬───────────────────────┘
                            │
                            ▼
              Virtual IP (VIP): 192.168.8.255
             (Floats between Pi #1 and Pi #2)
                            │
                            ▼
                    Client Devices
            (Always use 192.168.8.255 for DNS)

         VRRP Heartbeats (every 1 second)
    ◄──────────────────────────────────────────►
```

### Data Flow - Normal Operation
```
1. Client sends DNS query to VIP (192.168.8.255)
   ↓
2. VIP is currently on Pi #1 (MASTER)
   ↓
3. Query reaches Pi-hole Primary (192.168.8.251)
   ↓
4. Pi-hole forwards to Unbound Primary (192.168.8.253)
   ↓
5. Unbound performs recursive DNS resolution
   ↓
6. Response returns to client

Simultaneously:
- Gravity Sync: Pi #1 → Pi #2 (every hour)
- VRRP heartbeats: Pi #1 ↔ Pi #2 (every second)
- Health checks: Every 5 seconds on both nodes
```

### Data Flow - After Failover
```
1. Pi #1 fails (power loss, hardware failure, etc.)
   ↓
2. Pi #2 stops receiving VRRP heartbeats (3 missed = 3 seconds)
   ↓
3. Pi #2 transitions to MASTER state
   ↓
4. VIP (192.168.8.255) moves to Pi #2
   ↓
5. Client sends DNS query to VIP (192.168.8.255)
   ↓
6. VIP now on Pi #2, query reaches Pi-hole Secondary (192.168.8.252)
   ↓
7. Pi-hole forwards to Unbound Secondary (192.168.8.254)
   ↓
8. Response returns to client

Total failover time: 5-10 seconds
Client experience: Brief timeout, then automatic recovery
No manual intervention required!
```

### Comparison Matrix

| Aspect | Single Node | Multi-Node (Option A) |
|--------|-------------|----------------------|
| **Physical Devices** | 1 Pi | 2 Pis |
| **Pi-hole Instances** | 2 (same host) | 2 (different hosts) |
| **Unbound Instances** | 2 (same host) | 2 (different hosts) |
| **Hardware Failure Protection** | ❌ No | ✅ Yes |
| **Container Failure Protection** | ✅ Yes | ✅ Yes |
| **Network Failure Protection** | ❌ No | ✅ Yes |
| **Power Failure Protection** | ❌ No | ✅ Partial (if one Pi) |
| **Failover Time** | 5 sec | 5-10 sec |
| **Setup Complexity** | Low | Medium |
| **Cost** | $ | $$ |
| **Management Overhead** | Low | Medium |
| **Production Ready** | Lab/Home | Production |

---

## Proposed Architecture: Multi-Node HA (Option B - Full Redundancy)

### Network Topology
```
┌──────────────────────────────┐    ┌──────────────────────────────┐
│  Raspberry Pi #1             │    │  Raspberry Pi #2             │
│  Physical IP: 192.168.8.11   │    │  Physical IP: 192.168.8.12   │
│  ┌────────────────────────┐  │    │  ┌────────────────────────┐  │
│  │  Docker Host           │  │    │  │  Docker Host           │  │
│  │                        │  │    │  │                        │  │
│  │  ┌────────┐ ┌────────┐ │  │    │  │  ┌────────┐ ┌────────┐ │  │
│  │  │Pi-hole │ │Pi-hole │ │  │    │  │  │Pi-hole │ │Pi-hole │ │  │
│  │  │Primary │ │Second. │ │◄─┼────┼──┼─►│Primary │ │Second. │ │  │
│  │  │  .251  │ │  .252  │ │  │    │  │  │  .253  │ │  .254  │ │  │
│  │  └───┬────┘ └───┬────┘ │  │    │  │  └───┬────┘ └───┬────┘ │  │
│  │      │          │       │  │    │  │      │          │       │  │
│  │  ┌───▼────┐ ┌───▼────┐ │  │    │  │  ┌───▼────┐ ┌───▼────┐ │  │
│  │  │Unbound │ │Unbound │ │  │    │  │  │Unbound │ │Unbound │ │  │
│  │  │Primary │ │Second. │ │  │    │  │  │Primary │ │Second. │ │  │
│  │  │  .255  │ │  .256  │ │  │    │  │  │  .257  │ │  .258  │ │  │
│  │  └────────┘ └────────┘ │  │    │  │  └────────┘ └────────┘ │  │
│  │                        │  │    │  │                        │  │
│  │  ┌──────────────────┐  │  │    │  │  ┌──────────────────┐  │  │
│  │  │  Keepalived      │  │  │    │  │  │  Keepalived      │  │  │
│  │  │  MASTER          │◄─┼──┼────┼──┼─►│  BACKUP          │  │  │
│  │  │  Priority: 100   │  │  │    │  │  │  Priority: 90    │  │  │
│  │  └──────────────────┘  │  │    │  │  └──────────────────┘  │  │
│  └────────────────────────┘  │    │  └────────────────────────┘  │
│              │                │    │              │                │
└──────────────┼────────────────┘    └──────────────┼────────────────┘
               │                                    │
               └────────────┬───────────────────────┘
                            │
                            ▼
              Virtual IP (VIP): 192.168.8.255
```

### Redundancy Levels

**Option B provides THREE levels of redundancy:**

1. **Container Level**: Each node has 2 Pi-hole + 2 Unbound instances
   - If one Pi-hole crashes → other Pi-hole on same node handles queries
   
2. **Node Level**: Two physical nodes
   - If entire node fails → other node takes over via VIP
   
3. **Network Level**: Multiple paths to DNS
   - Clients can use VIP, or direct IPs as fallback

### Resource Comparison

```
Resource Usage:

Single-Node:
├── 1 Pi: ~2GB RAM, ~15% CPU
└── Total: 1 device

Multi-Node Option A:
├── Pi #1: ~1.5GB RAM, ~10% CPU
├── Pi #2: ~1.5GB RAM, ~10% CPU
└── Total: 2 devices

Multi-Node Option B:
├── Pi #1: ~3GB RAM, ~20% CPU
├── Pi #2: ~3GB RAM, ~20% CPU
└── Total: 2 devices (heavy load)
```

---

## Failure Scenario Comparison

### Scenario 1: Container Crash (Pi-hole)

**Single-Node:**
```
1. Pi-hole primary crashes
2. Keepalived detects (5 sec)
3. Routes to Pi-hole secondary
4. ✅ DNS continues working
Time to recover: ~5 seconds
```

**Multi-Node Option A:**
```
1. Pi-hole on Pi #1 crashes
2. Keepalived detects (5 sec)
3. VIP moves to Pi #2
4. ✅ DNS continues via Pi #2
Time to recover: ~10 seconds
```

**Multi-Node Option B:**
```
1. Pi-hole primary on Pi #1 crashes
2. Keepalived routes to secondary on same node
3. ✅ DNS continues on Pi #1
Time to recover: ~5 seconds
(VIP doesn't need to move)
```

### Scenario 2: Complete Node Failure

**Single-Node:**
```
1. Pi #1 loses power
2. All containers stop
3. ❌ Complete DNS outage
4. Manual intervention needed
Time to recover: Manual (minutes to hours)
```

**Multi-Node (Both Options):**
```
1. Pi #1 loses power
2. Pi #2 stops receiving heartbeats
3. Pi #2 becomes MASTER (10 sec)
4. VIP moves to Pi #2
5. ✅ DNS continues on Pi #2
Time to recover: ~10 seconds (automatic!)
```

### Scenario 3: Network Split

**Single-Node:**
```
Not applicable (single node)
```

**Multi-Node (Both Options):**
```
1. Network cable to Pi #1 disconnected
2. Pi #2 assumes Pi #1 is down
3. Pi #2 becomes MASTER
4. ✅ DNS continues on Pi #2

Note: When network reconnects, VIP
returns to Pi #1 (higher priority)
```

---

## When to Use Each Architecture

### Use Single-Node If:
```
✓ Budget: Limited (1 Raspberry Pi)
✓ Use Case: Home lab, testing, learning
✓ Availability: Can tolerate brief outages
✓ Complexity: Want simple setup
✓ Management: Prefer minimal maintenance
✓ Risk: Container failures are main concern
```

### Use Multi-Node Option A If:
```
✓ Budget: Moderate (2 Raspberry Pis)
✓ Use Case: Home production, small office
✓ Availability: Need high uptime
✓ Complexity: Can handle medium complexity
✓ Management: Okay with sync management
✓ Risk: Hardware failures are a concern
✓ Recommendation: ⭐ BEST BALANCE ⭐
```

### Use Multi-Node Option B If:
```
✓ Budget: Higher (2 powerful Raspberry Pis)
✓ Use Case: Mission-critical, business
✓ Availability: Need maximum uptime
✓ Complexity: Can handle high complexity
✓ Management: Have time for detailed management
✓ Risk: Cannot tolerate any single failure
✓ Resources: Pis have 8GB RAM
```

---

## Visual Decision Tree

```
Do you have 2 Raspberry Pis?
│
├─ NO ──→ Use Single-Node Setup
│          - Simple and effective
│          - Container-level HA
│
└─ YES ──→ Need maximum redundancy?
           │
           ├─ NO ──→ Use Multi-Node Option A ⭐
           │          - Hardware redundancy
           │          - Moderate complexity
           │          - Best for most users
           │
           └─ YES ──→ Use Multi-Node Option B
                      - Maximum redundancy
                      - High complexity
                      - For critical environments
```

---

## Migration Path

### From Single-Node to Multi-Node

```
Current State:
┌────────────────┐
│   Pi #1        │
│   (All services)│
└────────────────┘

Step 1: Set up Pi #2
┌────────────────┐     ┌────────────────┐
│   Pi #1        │     │   Pi #2        │
│   (All services)│     │   (Installing) │
└────────────────┘     └────────────────┘

Step 2: Deploy secondary services on Pi #2
┌────────────────┐     ┌────────────────┐
│   Pi #1        │     │   Pi #2        │
│   - Pi-hole 1  │     │   - Pi-hole 2  │
│   - Pi-hole 2  │     │   - Unbound 2  │
│   - Unbound 1  │     │   - Keepalived │
│   - Keepalived │     │     (BACKUP)   │
│     (MASTER)   │     │                │
└────────────────┘     └────────────────┘

Step 3: Reconfigure Pi #1 (Option A only)
┌────────────────┐     ┌────────────────┐
│   Pi #1        │     │   Pi #2        │
│   - Pi-hole 1  │     │   - Pi-hole 2  │
│   - Unbound 1  │     │   - Unbound 2  │
│   - Keepalived │ ←───→   - Keepalived │
│     (MASTER)   │ VRRP │     (BACKUP)   │
└────────────────┘     └────────────────┘
        ↓                      ↓
    VIP moves between them

Step 4: Configure Gravity Sync
┌────────────────┐     ┌────────────────┐
│   Pi #1        │────→│   Pi #2        │
│   (Primary)    │ Sync│   (Secondary)  │
└────────────────┘     └────────────────┘

✅ Migration complete!
```

---

## Summary Comparison Table

| Feature | Single-Node | Multi-Node A | Multi-Node B |
|---------|-------------|--------------|--------------|
| Physical Pis | 1 | 2 | 2 |
| Pi-hole per node | 2 | 1 | 2 |
| Unbound per node | 2 | 1 | 2 |
| Hardware resilience | ❌ | ✅ | ✅ |
| Container resilience | ✅ | ⚠️ | ✅ |
| Complexity | 🟢 Low | 🟡 Medium | 🔴 High |
| Setup time | 30 min | 1-2 hours | 2-4 hours |
| Monthly cost* | $5 | $10 | $10 |
| Recommended for | Lab/Home | Production | Critical |
| Documentation | Standard | Full | Full |

*Approximate power costs at $0.10/kWh

---

**This completes the visual architecture comparison.**  
**See MULTI_NODE_HA_DESIGN.md for detailed implementation.**
