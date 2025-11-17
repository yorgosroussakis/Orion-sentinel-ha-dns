# Quick Start Card 🚀

**One-page guide to get started with RPi HA DNS Stack**

---

## Installation Methods

### 🌟 Method 1: Easy Installer (RECOMMENDED) ✨

**Best for**: Everyone - safest and most reliable

```bash
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack
bash scripts/easy-install.sh
```

**Features:**
- ✅ Comprehensive checks before installation
- ✅ Safe error handling (won't crash your session)
- ✅ Resume from failures automatically
- ✅ Choose Web UI or Terminal setup
- ✅ Helpful error messages

**Options:**
- `--verbose` - See detailed output
- `--skip-docker` - Skip Docker installation
- `--force` - Continue despite warnings
- `--help` - Show all options

---

### 🎨 Method 2: Web Setup UI

**Best for**: Users who prefer graphical interfaces

```bash
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack
bash scripts/launch-setup-ui.sh
```

Then open: `http://<your-pi-ip>:5555`

---

### 💻 Method 3: Terminal Setup

**Best for**: Experienced users who prefer command-line

```bash
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack
bash scripts/setup.sh
```

---

## Quick Troubleshooting

### Installation fails?
```bash
# Use verbose mode
bash scripts/easy-install.sh --verbose

# Check logs
cat install.log
```

### SSH session disconnects?
```bash
# Use screen to prevent disconnection
sudo apt-get install screen
screen -S install
bash scripts/easy-install.sh
# If disconnected: screen -r install
```

### Docker permission errors?
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### System appears to reboot?
- Check power supply (need 3A+)
- Monitor temperature: `vcgencmd measure_temp`
- Use the new easy-install script

---

## After Installation

### Access Services

- **Pi-hole Primary**: `http://192.168.8.251/admin`
- **Pi-hole Secondary**: `http://192.168.8.252/admin`
- **Grafana Dashboard**: `http://192.168.8.250:3000`
- **Prometheus**: `http://192.168.8.250:9090`

### Configure Your Router

Set DNS servers to:
- **Primary**: `192.168.8.255` (VIP)
- **Secondary**: `192.168.8.251`

### Check Status

```bash
# Check all containers
docker ps

# Check specific service
docker logs pihole_primary

# Check DNS resolution
dig @192.168.8.255 google.com
```

---

## Common Issues

| Problem | Solution |
|---------|----------|
| Can't access from Pi itself | Normal with macvlan - access from another device |
| High CPU usage | Add cooling, reduce logging |
| Out of memory | Add swap, disable unused stacks |
| DNS not resolving | Check container logs, verify network config |
| Web UI won't load | Check firewall, verify port 5555 is open |

---

## Need More Help?

📖 **Full Documentation:**
- [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md) - Detailed installation
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Complete troubleshooting guide
- [USER_GUIDE.md](USER_GUIDE.md) - How to use the stack

🐛 **Report Issues:**
- GitHub Issues: https://github.com/yorgosroussakis/rpi-ha-dns-stack/issues

---

## Essential Commands

### Managing Services
```bash
# Start all services
cd rpi-ha-dns-stack/stacks/dns
docker compose up -d

# Stop all services
docker compose down

# Restart a service
docker compose restart pihole_primary

# View logs
docker compose logs -f
```

### Updating
```bash
cd rpi-ha-dns-stack
bash scripts/update.sh
```

### Backup
```bash
# Manual backup
docker exec pihole_primary pihole -a -t

# Restore backup
bash scripts/restore-backup.sh
```

---

## System Requirements

**Minimum:**
- Raspberry Pi 4/5
- 4GB RAM
- 32GB SD Card
- Stable 3A power supply

**Recommended:**
- Raspberry Pi 5
- 8GB RAM
- 64GB+ SSD (USB)
- Official 3A+ power supply
- Ethernet connection
- Active cooling

---

## Safety Tips

✅ **DO:**
- Use official power supply
- Add cooling (heatsinks/fan)
- Run in screen/tmux session
- Keep backups
- Monitor temperature

❌ **DON'T:**
- Use insufficient power supply
- Run without cooling
- Edit files while containers are running
- Skip prerequisite checks
- Ignore error messages

---

**Last Updated**: 2025-11-17

For the most up-to-date information, always check the repository's main README.md
