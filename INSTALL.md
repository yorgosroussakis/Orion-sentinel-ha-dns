# Installation Guide

Complete installation guide for Orion Sentinel HA DNS on Raspberry Pi.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Hardware Requirements](#hardware-requirements)
- [Network Planning](#network-planning)
- [Installation Steps](#installation-steps)
  - [Single Node Setup](#single-node-setup)
  - [Two-Node HA Setup](#two-node-ha-setup)
- [Post-Installation](#post-installation)
- [Verification](#verification)
- [Upgrading](#upgrading)
- [Uninstallation](#uninstallation)

---

## Prerequisites

### Software Requirements

On each Raspberry Pi, ensure the following are installed:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install Docker Compose plugin
sudo apt install -y docker-compose-plugin

# Install required tools
sudo apt install -y git dnsutils curl jq

# Log out and back in for docker group to take effect
```

### Verify Docker Installation

```bash
docker --version
docker compose version
```

---

## Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **Raspberry Pi** | Pi 4 (2GB) | Pi 5 (4GB+) |
| **Storage** | 16GB SD Card | 32GB+ SSD (USB boot) |
| **Network** | Ethernet | Gigabit Ethernet |
| **Power** | 3A USB-C | Official Pi power supply |

For **two-node HA**, you need two identical (or similar) Raspberry Pis.

---

## Network Planning

Before installation, plan your network configuration:

| Setting | Default | Your Value |
|---------|---------|------------|
| **Node A (Primary) IP** | 192.168.8.249 | ___________ |
| **Node B (Secondary) IP** | 192.168.8.243 | ___________ |
| **Virtual IP (VIP)** | 192.168.8.250 | ___________ |
| **Network Interface** | eth1 | ___________ |
| **Subnet Mask** | /24 | ___________ |
| **Gateway** | 192.168.8.1 | ___________ |

### Important Notes

1. **VIP must be unused** - The VIP address must not be assigned to any other device
2. **Static IPs required** - Both nodes need static IP addresses
3. **Same subnet** - All IPs (Node A, Node B, VIP) must be on the same subnet
4. **Interface name** - Check your interface name with `ip link show`

---

## Installation Steps

### Single Node Setup

For a single Pi-hole + Unbound installation without HA.

#### Step 1: Clone Repository

```bash
cd /opt
sudo git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git orion-dns-ha
sudo chown -R $USER:$USER /opt/orion-dns-ha
cd /opt/orion-dns-ha
```

#### Step 2: Configure Environment

```bash
cp .env.example .env
nano .env
```

**Required settings:**
```bash
# Set a strong password for Pi-hole admin
PIHOLE_PASSWORD=your_secure_password_here

# Your timezone
TZ=Europe/London
```

#### Step 3: Deploy

```bash
make single
```

#### Step 4: Verify

```bash
# Test DNS resolution
dig @127.0.0.1 google.com

# Check container status
docker ps

# Access Pi-hole admin
echo "Open http://$(hostname -I | awk '{print $1}')/admin"
```

---

### Two-Node HA Setup

For a redundant two-node setup with automatic failover.

#### Step 1: Prepare Both Nodes

On **both** Raspberry Pis:

```bash
# Clone repository
cd /opt
sudo git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git orion-dns-ha
sudo chown -R $USER:$USER /opt/orion-dns-ha
cd /opt/orion-dns-ha
```

#### Step 2: Configure Primary Node (Node A)

On **Node A (192.168.8.249)**:

```bash
cp .env.primary.example .env
nano .env
```

**Edit these values:**
```bash
# Required - Set strong passwords (SAME on both nodes)
PIHOLE_PASSWORD=your_secure_password_here
VRRP_PASSWORD=your_vrrp_password_here

# Network settings (adjust to your network)
VIP_ADDRESS=192.168.8.250
NETWORK_INTERFACE=eth1
PEER_IP=192.168.8.243  # Node B's IP
```

#### Step 3: Configure Secondary Node (Node B)

On **Node B (192.168.8.243)**:

```bash
cp .env.secondary.example .env
nano .env
```

**Edit these values (SAME passwords as Node A):**
```bash
# Required - MUST match Node A
PIHOLE_PASSWORD=your_secure_password_here
VRRP_PASSWORD=your_vrrp_password_here

# Network settings
VIP_ADDRESS=192.168.8.250
NETWORK_INTERFACE=eth1
PEER_IP=192.168.8.249  # Node A's IP
```

#### Step 4: Deploy Primary Node

On **Node A**:

```bash
make primary
```

Wait for containers to start (about 60 seconds).

#### Step 5: Deploy Secondary Node

On **Node B**:

```bash
make secondary
```

#### Step 6: Verify HA Setup

```bash
# On Node A - Should show VIP assigned
ip addr show eth1 | grep 192.168.8.250

# On Node B - Should NOT show VIP (it's on Node A)
ip addr show eth1 | grep 192.168.8.250

# Test DNS via VIP (from any machine)
dig @192.168.8.250 google.com
```

---

## Post-Installation

### Install Systemd Services (Recommended)

For autostart on boot and auto-healing:

**On Node A (Primary):**
```bash
sudo make install-systemd-primary
```

**On Node B (Secondary):**
```bash
sudo make install-systemd-backup
```

This installs:
- **Autostart** - Services start on boot
- **Health monitoring** - Checks every 2 minutes, restarts on failure
- **Daily backups** - Runs at 2 AM
- **Pi-hole sync** - Syncs config every 6 hours (primary only)

### Configure SSH Keys for Sync (Primary Node)

For Pi-hole sync to work, set up SSH key authentication from primary to secondary:

```bash
# On Node A (Primary)
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519

# Copy key to Node B
ssh-copy-id pi@192.168.8.243

# Test connection
ssh pi@192.168.8.243 "echo 'SSH OK'"
```

### Configure Your Router

Point your router's DHCP DNS setting to the VIP:

1. Access your router's admin panel
2. Find DHCP settings
3. Set **Primary DNS** to: `192.168.8.250` (the VIP)
4. Optionally set **Secondary DNS** to: `192.168.8.249` (Node A's IP)
5. Save and restart DHCP or reconnect devices

---

## Verification

### Check Service Status

```bash
# Container status
make status

# Health check
make health

# View logs
make logs
```

### Test DNS Resolution

```bash
# Via VIP
dig @192.168.8.250 google.com +short

# Via localhost
dig @127.0.0.1 google.com +short

# Check ad blocking
dig @192.168.8.250 ads.google.com +short
# Should return 0.0.0.0 or empty
```

### Test Failover (Two-Node Only)

```bash
# On Node A, stop Pi-hole
docker stop pihole_unbound

# Wait 10 seconds, then test DNS via VIP (should still work!)
dig @192.168.8.250 google.com +short

# Check VIP moved to Node B
ssh pi@192.168.8.243 "ip addr show eth1 | grep 192.168.8.250"

# Restart Node A
docker start pihole_unbound

# VIP should return to Node A (higher priority)
```

---

## Upgrading

### Update Repository

```bash
cd /opt/orion-dns-ha
git pull origin main
```

### Rebuild Containers

```bash
# Single node
make down
make single

# Primary node
make down
make primary

# Secondary node  
make down
make secondary
```

### Update Pi-hole Image

```bash
docker compose pull
make down
make primary  # or make single/secondary
```

---

## Uninstallation

### Stop Services

```bash
make down
```

### Remove Systemd Services

```bash
sudo systemctl disable --now orion-dns-ha-primary.service 2>/dev/null || true
sudo systemctl disable --now orion-dns-ha-backup.service 2>/dev/null || true
sudo systemctl disable --now orion-dns-health.timer 2>/dev/null || true
sudo systemctl disable --now orion-dns-backup.timer 2>/dev/null || true
sudo systemctl disable --now orion-dns-sync.timer 2>/dev/null || true

sudo rm -f /etc/systemd/system/orion-dns-*.service
sudo rm -f /etc/systemd/system/orion-dns-*.timer
sudo systemctl daemon-reload
```

### Remove Data (Optional)

```bash
# Remove containers and volumes (DELETES ALL DATA)
make clean

# Remove repository
sudo rm -rf /opt/orion-dns-ha
```

---

## Troubleshooting

See [README.md](README.md#troubleshooting) for common issues and solutions.

### Quick Fixes

**Port 53 already in use:**
```bash
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
```

**VIP not assigned:**
```bash
# Check keepalived logs
docker logs keepalived

# Verify interface exists
ip link show eth1
```

**Containers not starting:**
```bash
# Check Docker status
sudo systemctl status docker

# View all container logs
docker compose logs
```

---

## Support

- **Issues**: [GitHub Issues](https://github.com/orionsentinel/Orion-sentinel-ha-dns/issues)
- **Documentation**: See [README.md](README.md)
