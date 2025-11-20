# Single Raspberry Pi Installation Guide

**Orion Sentinel DNS HA - Single-Node Setup**

This guide walks you through installing Orion DNS HA on a single Raspberry Pi for home use.

---

## Overview

A single-Pi deployment provides:
- ✅ Network-wide ad blocking with Pi-hole
- ✅ Privacy-focused recursive DNS with Unbound
- ✅ Container-level redundancy (dual Pi-hole and Unbound instances)
- ✅ Monitoring and dashboards
- ✅ DNS security profiles (Family / Standard / Paranoid)

**What you won't get:**
- ❌ Hardware failover (if the Pi fails, DNS fails)
- ❌ Zero-downtime updates (brief interruption during Pi reboot)

**Good for:** Home networks, testing, learning, budget-conscious setups

---

## Prerequisites

### Hardware Requirements

- **Raspberry Pi 4** (4GB RAM recommended, 2GB minimum)
- **MicroSD card** (32GB or larger, Class 10)
- **Ethernet cable** (Wi-Fi works but ethernet is more reliable)
- **Power supply** (official RPi power supply recommended)

### Network Requirements

- Static IP address for your Pi (configured on your router or manually)
- Access to your router's admin interface (to configure DNS settings)

### Software Requirements

- Raspberry Pi OS (64-bit recommended)
- SSH access enabled (or keyboard/monitor attached)

---

## Installation Methods

Choose your preferred installation method:

### Method 1: Web Wizard (Easiest - Recommended for Beginners)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yorgosroussakis/Orion-sentinel-ha-dns.git
   cd Orion-sentinel-ha-dns
   ```

2. **Run the install script:**
   ```bash
   bash scripts/install.sh
   ```

3. **Access the web wizard:**
   ```
   http://<your-pi-ip>:8080
   ```

4. **Follow the wizard:**
   - Choose "Single-Node" mode
   - Enter your Pi's IP address
   - Set a strong Pi-hole password
   - Select a DNS security profile
   - Complete setup

5. **Deploy the stack:**
   ```bash
   docker compose -f stacks/dns/docker-compose.yml up -d
   ```

6. **Apply your DNS profile:**
   ```bash
   python3 scripts/apply-profile.py --profile standard
   ```

See [First-Run Wizard Guide](first-run-wizard.md) for detailed wizard instructions.

---

### Method 2: Guided CLI Script

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yorgosroussakis/Orion-sentinel-ha-dns.git
   cd Orion-sentinel-ha-dns
   ```

2. **Run the install script:**
   ```bash
   bash scripts/install.sh
   ```

   The script will:
   - Check prerequisites (Docker, disk space, memory)
   - Install Docker if needed
   - Create network configuration
   - Set up directories
   - Ask you to configure `.env`

3. **Configure `.env` for single-node:**
   ```bash
   cp .env.example .env
   nano .env
   ```

   **Key settings for single-node:**
   ```bash
   # Your Pi's IP address
   HOST_IP=192.168.1.100
   
   # In single-node mode, VIP = Pi IP
   DNS_VIP=192.168.1.100
   VIP_ADDRESS=192.168.1.100
   
   # Always MASTER for single-node
   NODE_ROLE=MASTER
   
   # Network interface (usually eth0)
   NETWORK_INTERFACE=eth0
   
   # Set strong passwords
   PIHOLE_PASSWORD=<your-strong-password>
   GRAFANA_ADMIN_PASSWORD=<your-strong-password>
   VRRP_PASSWORD=<your-strong-password>
   
   # Network configuration
   SUBNET=192.168.1.0/24
   GATEWAY=192.168.1.1
   ```

   **Generate secure passwords:**
   ```bash
   openssl rand -base64 32
   ```

4. **Deploy the stack:**
   ```bash
   docker compose -f stacks/dns/docker-compose.yml up -d
   ```

5. **Apply DNS profile:**
   ```bash
   python3 scripts/apply-profile.py --profile standard
   ```

---

### Method 3: Manual Configuration (Power Users)

1. **Clone and prepare:**
   ```bash
   git clone https://github.com/yorgosroussakis/Orion-sentinel-ha-dns.git
   cd Orion-sentinel-ha-dns
   ```

2. **Install Docker (if not already installed):**
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   newgrp docker
   ```

3. **Create `.env` from template:**
   ```bash
   cp .env.example .env
   ```

4. **Edit `.env` manually** with your favorite editor

5. **Create Docker network:**
   ```bash
   docker network create -d macvlan \
     --subnet=192.168.1.0/24 \
     --gateway=192.168.1.1 \
     -o parent=eth0 \
     dns_net
   
   docker network create observability_net
   ```

6. **Deploy:**
   ```bash
   docker compose -f stacks/dns/docker-compose.yml up -d
   ```

---

## Post-Installation Steps

### 1. Verify Services Are Running

```bash
# Check container status
docker ps

# Should see:
# - pihole_primary
# - pihole_secondary
# - unbound_primary
# - unbound_secondary
# - keepalived
# - pihole-sync
# - dns-wizard (optional)
```

### 2. Access Pi-hole Admin Interface

```
http://<your-pi-ip>/admin
```

Or if using the VIP IP (same as Pi IP in single-node):
```
http://192.168.1.100/admin
```

Login with the password you set in `.env` (`PIHOLE_PASSWORD`).

### 3. Configure Your Router

**Critical step:** Point your router's DNS to your Pi.

1. Log into your router's admin interface
2. Find DNS/DHCP settings
3. Set Primary DNS to your Pi's IP (e.g., `192.168.1.100`)
4. Set Secondary DNS to the same IP or leave blank
5. Save and reboot router (if needed)

**Common router locations:**
- **TP-Link:** Advanced → Network → DHCP Server → Primary DNS
- **Netgear:** Basic → Internet → Domain Name Server (DNS)
- **Asus:** LAN → DHCP Server → DNS Server
- **Linksys:** Connectivity → Local Network → DHCP Server Configuration

### 4. Test DNS Resolution

From any device on your network:

```bash
# Should show your Pi's IP as the DNS server
nslookup google.com

# Or
dig google.com
```

**From Windows:**
```cmd
nslookup google.com
```

### 5. Apply Your DNS Security Profile

```bash
python3 scripts/apply-profile.py --profile standard

# Or choose a different profile:
# python3 scripts/apply-profile.py --profile family
# python3 scripts/apply-profile.py --profile paranoid
```

See [DNS Profiles Guide](profiles.md) for details on each profile.

---

## Accessing Services

Once running, you can access:

### Pi-hole Dashboard
```
http://<your-pi-ip>/admin
```
- View blocked queries
- Manage whitelist/blacklist
- Configure DNS settings

### Grafana Monitoring
```
http://<your-pi-ip>:3000
```
- Default login: `admin` / `<GRAFANA_ADMIN_PASSWORD from .env>`
- View DNS metrics and dashboards

### Prometheus Metrics
```
http://<your-pi-ip>:9090
```
- Raw metrics and query interface

---

## Single-Node Architecture

```
┌─────────────────────────────────┐
│   Raspberry Pi (192.168.1.100)  │
│                                  │
│  ┌───────────┐  ┌───────────┐  │
│  │ Pi-hole 1 │  │ Pi-hole 2 │  │
│  │ :251      │  │ :252      │  │
│  └─────┬─────┘  └─────┬─────┘  │
│        │              │         │
│        │              │         │
│  ┌─────▼──────┐ ┌────▼──────┐  │
│  │ Unbound 1  │ │ Unbound 2 │  │
│  │ :253       │ │ :254      │  │
│  └────────────┘ └───────────┘  │
│                                  │
│  ┌──────────────────────────┐  │
│  │      Keepalived VIP      │  │
│  │      (192.168.1.100)     │  │
│  └──────────────────────────┘  │
└─────────────────────────────────┘
           │
           │ DNS Queries (port 53)
           │
    ┌──────▼──────┐
    │   Router    │
    │ DHCP/DNS    │
    └─────────────┘
           │
    ┌──────▼──────┐
    │   Devices   │
    └─────────────┘
```

**Key points:**
- DNS VIP = Pi's IP (192.168.1.100 in this example)
- Both Pi-hole instances run on the same physical Pi
- Both Unbound instances run on the same physical Pi
- Keepalived manages the VIP (though it's the same as the host IP)
- If the Pi fails, all DNS services fail
- Container-level redundancy only (not hardware-level)

---

## Maintenance

### Backup Configuration

```bash
bash scripts/backup-config.sh
```

Backups are stored in `backups/` directory.

### Upgrade Stack

```bash
bash scripts/upgrade.sh
```

This will:
1. Create a backup
2. Pull latest code from Git
3. Update Docker images
4. Restart services

### Change DNS Profile

```bash
python3 scripts/apply-profile.py --profile family
```

### View Logs

```bash
# Pi-hole logs
docker logs pihole_primary

# Unbound logs
docker logs unbound_primary

# All services
docker compose -f stacks/dns/docker-compose.yml logs -f
```

---

## Troubleshooting

### DNS Not Working

1. **Check containers are running:**
   ```bash
   docker ps
   ```

2. **Check Pi-hole is reachable:**
   ```bash
   ping 192.168.1.100
   ```

3. **Test DNS directly:**
   ```bash
   dig @192.168.1.100 google.com
   ```

4. **Check router DNS settings** - Must point to Pi's IP

### Pi-hole Admin Not Loading

1. **Verify Pi-hole container is running:**
   ```bash
   docker ps | grep pihole
   ```

2. **Check Pi-hole logs:**
   ```bash
   docker logs pihole_primary
   ```

3. **Try the secondary Pi-hole:**
   ```
   http://192.168.1.100:8080/admin
   ```

### High Memory Usage

Single-Pi deployments run all services on one machine. If memory is constrained:

1. **Check memory usage:**
   ```bash
   free -h
   docker stats
   ```

2. **Stop unnecessary services:**
   ```bash
   # Stop wizard after setup
   docker compose -f stacks/dns/docker-compose.yml stop dns-wizard
   ```

3. **Upgrade to Raspberry Pi with more RAM** (4GB recommended)

---

## Upgrading to Two-Pi HA

If you later acquire a second Pi and want hardware redundancy:

1. **Follow the [Two-Pi HA Installation Guide](install-two-pi-ha.md)**
2. **Use your existing backup:**
   ```bash
   bash scripts/backup-config.sh
   ```
3. **Configure the second Pi as BACKUP node**
4. **Update your router to use the new VIP**

---

## Next Steps

- **[First-Run Wizard Guide](first-run-wizard.md)** - Using the web wizard
- **[DNS Profiles Guide](profiles.md)** - Understanding security profiles
- **[Operations Guide](operations.md)** - Day-to-day management
- **[Troubleshooting Guide](../TROUBLESHOOTING.md)** - Common issues

---

**Questions or Issues?**

- Check [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
- Visit the [GitHub repository](https://github.com/yorgosroussakis/Orion-sentinel-ha-dns)
- Review the [User Guide](../USER_GUIDE.md)
