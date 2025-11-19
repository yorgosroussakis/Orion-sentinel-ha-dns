# RPi HA DNS Stack 🌐

A high-availability DNS stack running on Raspberry Pi 5.

## 📚 Documentation Quick Links

- **[🚀 QUICKSTART.md](QUICKSTART.md)** - One-page guide to get started fast
- **[📖 INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)** - Detailed installation instructions
- **[🔧 TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Fix common issues (SSH disconnects, reboots, errors)
- **[👤 USER_GUIDE.md](USER_GUIDE.md)** - How to use and maintain the stack

---

## 🆕 Choose Your Deployment Option!

This repository now supports **FOUR complete deployment options** for different High Availability scenarios, including a **VPN Edition**!

### **[📂 View All Deployment Options →](deployments/)**

| Option | Description | Best For |
|--------|-------------|----------|
| **[HighAvail_1Pi2P2U](deployments/HighAvail_1Pi2P2U/)** | 1 Pi with 2 Pi-hole + 2 Unbound | Home labs, Testing |
| **[HighAvail_1Pi2P2U_VPN](deployments/HighAvail_1Pi2P2U_VPN/)** 🆕 ⭐ | 1 Pi with HA DNS + **WireGuard VPN** | **Remote Access + Ad-blocking** |
| **[HighAvail_2Pi1P1U](deployments/HighAvail_2Pi1P1U/)** ⭐ | 2 Pis with 1 Pi-hole + 1 Unbound each | **Production** (RECOMMENDED) |
| **[HighAvail_2Pi2P2U](deployments/HighAvail_2Pi2P2U/)** | 2 Pis with 2 Pi-hole + 2 Unbound each | Mission-Critical |

Each deployment option includes complete docker-compose files, configurations, and detailed instructions.

**🆕 VPN Edition Features:**
- 📱 QR codes for instant mobile setup
- 🌐 Web UI for managing VPN peers  
- 🛡️ Integrated with HA VIP (192.168.8.255)
- 🚀 Remote access to all home services
- ✅ Ad-blocking everywhere!

**Architecture Documentation:**
- **[📑 Documentation Index](MULTI_NODE_INDEX.md)** - Navigation guide
- **[🚀 Quick Start](MULTI_NODE_QUICKSTART.md)** - Overview
- **[📐 Architecture Design](MULTI_NODE_HA_DESIGN.md)** - Detailed design
- **[🎨 Visual Comparison](ARCHITECTURE_COMPARISON.md)** - Diagrams

## Network Configuration 🛠️
- **Host (Raspberry Pi) IP:** 192.168.8.250 (eth0)
- **Primary DNS:** 192.168.8.251 (pihole_primary)
- **Secondary DNS:** 192.168.8.252 (pihole_secondary)
- **Primary Unbound:** 192.168.8.253 (unbound_primary)
- **Secondary Unbound:** 192.168.8.254 (unbound_secondary)
- **Keepalived VIP:** 192.168.8.255

## Stack Includes:
- Dual Pi-hole v6 instances with Unbound recursive DNS.
- Keepalived for HA failover.
- Gravity Sync for Pi-hole synchronization.
- AI-Watchdog for self-healing with Signal notifications.
- Prometheus + Grafana + Alertmanager + Loki for observability.
- Signal webhook bridge for notifications via CallMeBot.
- **🆕 WireGuard VPN for secure remote access to home services.**
- **🆕 Nginx Proxy Manager for exposing services with SSL support.**
- **🆕 Single Sign-On (SSO) with Authelia for centralized authentication.**
- **🆕 Intrusion Detection System (CrowdSec) for automated security protection.**
- Docker + Portainer setup.

## ASCII Network Diagram 🖥️
```plaintext
[192.168.8.250] <- Raspberry Pi Host
     |         |
     |         |
[192.168.8.251] [192.168.8.252]
 Pi-hole 1     Pi-hole 2
     |         |
     |         |
[192.168.8.253] [192.168.8.254]
 Unbound 1    Unbound 2
     |         |
     |         |
[192.168.8.255] <- Keepalived VIP

```

## Deployment Options 🎯

This repository provides **three complete deployment configurations**:

### HighAvail_1Pi2P2U - Single Pi Setup
- **Architecture:** 1 Pi with 2 Pi-hole + 2 Unbound
- **Redundancy:** Container-level only
- **Best for:** Home labs, testing, single Pi setups
- **Hardware:** 1x Raspberry Pi (4GB+ RAM)
- **[View Details →](deployments/HighAvail_1Pi2P2U/)**

### HighAvail_2Pi1P1U - Simplified Two-Pi Setup ⭐ RECOMMENDED
- **Architecture:** 2 Pis with 1 Pi-hole + 1 Unbound each
- **Redundancy:** Hardware + Node-level
- **Best for:** Production home networks, small offices
- **Hardware:** 2x Raspberry Pi (4GB+ RAM each)
- **[View Details →](deployments/HighAvail_2Pi1P1U/)**

### HighAvail_2Pi2P2U - Full Redundancy Two-Pi Setup
- **Architecture:** 2 Pis with 2 Pi-hole + 2 Unbound each
- **Redundancy:** Container + Hardware + Node-level (triple)
- **Best for:** Mission-critical environments
- **Hardware:** 2x Raspberry Pi (8GB RAM recommended)
- **[View Details →](deployments/HighAvail_2Pi2P2U/)**

**Quick Decision:** Have 2 Pis? → Use **HighAvail_2Pi1P1U** ⭐  
**[See Full Comparison →](deployments/)**

## Features List 📝
- High availability through Keepalived.
- Enhanced security and performance using Unbound.
- Real-time observability with Prometheus and Grafana.
- Automated sync of DNS records with Gravity Sync.
- Self-healing through AI-Watchdog.
- **🆕 Multi-node deployment for true hardware redundancy.**

## Quick Start Instructions 🚀

### 🚀 One-Line Installation (Recommended for Raspberry Pi)

**The easiest way to get started - just one command!**

```bash
curl -fsSL https://raw.githubusercontent.com/yorgosroussakis/rpi-ha-dns-stack/main/install.sh | bash
```

This installer will:
- ✅ Check system compatibility
- ✅ Install Docker and Docker Compose automatically
- ✅ Clone the repository
- ✅ Launch the web setup wizard

**Then follow the web wizard at:** `http://<your-pi-ip>:5555`

---

### 🌟 Web Setup UI (Modern & User-Friendly) ✨

**Graphical web interface for easy setup!** No terminal knowledge needed.

The Web Setup UI provides:
- ✅ Modern, responsive web interface
- ✅ 8-step guided wizard (Prerequisites → Hardware → Deployment → Node Role → Network → Security → Notifications → Summary)
- ✅ Automatic prerequisites checking (Docker, RAM, disk space)
- ✅ Hardware survey with detailed system information
- ✅ **NEW:** Node role selection for multi-Pi deployments (Primary/Secondary)
- ✅ Visual deployment option selection
- ✅ Form-based network and security configuration
- ✅ Real-time validation and feedback
- ✅ Configuration summary and deployment instructions
- ✅ Access from any device on your network

**Manual Installation:**
```bash
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack
bash scripts/launch-setup-ui.sh
```

**Then open your browser at:** `http://localhost:5555` or `http://<your-pi-ip>:5555`

**That's it!** Follow the step-by-step wizard in your browser - no terminal knowledge required!

---

### 🔐 Security Best Practices

**Before deploying**, generate secure passwords:

```bash
# Generate and save these passwords securely
echo "PIHOLE_PASSWORD=$(openssl rand -base64 32)"
echo "GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32)"
echo "VRRP_PASSWORD=$(openssl rand -base64 20)"
```

**After configuring your .env file**, validate it:

```bash
# Validate environment configuration
bash scripts/validate-env.sh

# Test .env file format
bash scripts/test-env-format.sh
```

Both validation scripts must pass before deployment to ensure:
- All required variables are set
- No default/weak passwords remain
- Proper file formatting

---

### Alternative: Terminal-Based Setup

#### 🆕 Option 1: Easy Installer (Recommended) ✨

**NEW:** Robust installer with proper error handling and recovery!

```bash
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack
bash scripts/easy-install.sh
```

Features:
- ✅ Comprehensive prerequisite checks
- ✅ Safe error handling (won't cause unexpected reboots)
- ✅ Automatic recovery from failures
- ✅ Choose between Web UI or Terminal setup
- ✅ Verbose mode for debugging: `bash scripts/easy-install.sh --verbose`
- ✅ Help available: `bash scripts/easy-install.sh --help`

#### Option 2: Interactive Terminal Wizard

If you prefer a terminal-based interactive wizard:
```bash
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack
bash scripts/interactive-setup.sh
```

#### Option 3: Guided Terminal Setup

For a simpler guided terminal setup:
```bash
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack
bash scripts/setup.sh
```

#### Option 3: Manual Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
   cd rpi-ha-dns-stack
   ```
2. Set up Signal notifications (optional but recommended):
   - Follow the detailed guide in [SIGNAL_INTEGRATION_GUIDE.md](SIGNAL_INTEGRATION_GUIDE.md)
   - Quick start: Register a phone number with signal-cli-rest-api
   - Copy `.env.example` to `.env` and update:
     - `SIGNAL_NUMBER`: Your phone number registered with Signal (e.g., +1234567890)
     - `SIGNAL_RECIPIENTS`: Recipient phone numbers (comma-separated)

3. Deploy the stack:
   ```bash
   bash scripts/install.sh
   ```

## Updating the Stack 🔄
To update your installation when the repository is updated:
```bash
cd rpi-ha-dns-stack
bash scripts/update.sh
```

The update script will:
- Backup your current configuration
- Pull latest changes from git
- Rebuild updated containers
- Restart services with zero downtime
- Preserve your `.env` and override files

## Service Access URLs 🌐
- **🆕 Web Setup UI:** [http://192.168.8.250:5555](http://192.168.8.250:5555) - Installation & Configuration Interface
- **Pi-hole Primary Dashboard:** [http://192.168.8.251/admin](http://192.168.8.251/admin)
- **Pi-hole Secondary Dashboard:** [http://192.168.8.252/admin](http://192.168.8.252/admin)
- **Metrics Dashboard (Grafana):** [http://192.168.8.250:3000](http://192.168.8.250:3000)
- **Prometheus:** [http://192.168.8.250:9090](http://192.168.8.250:9090)
- **Alertmanager:** [http://192.168.8.250:9093](http://192.168.8.250:9093)
- **Signal CLI REST API:** [http://192.168.8.250:8081](http://192.168.8.250:8081)
- **Signal Webhook Bridge:** [http://192.168.8.250:8080/health](http://192.168.8.250:8080/health)

### VPN & Remote Access URLs (Optional Stack)
- **🆕 WireGuard-UI:** [http://192.168.8.250:5000](http://192.168.8.250:5000) - VPN Peer Management
- **🆕 Nginx Proxy Manager:** [http://192.168.8.250:81](http://192.168.8.250:81) - Reverse Proxy Configuration

### SSO URLs (Optional Stack) 🔐
- **🆕 Authelia Portal:** [http://192.168.8.250:9091](http://192.168.8.250:9091) - Single Sign-On Authentication
- **🆕 OAuth2 Proxy:** [http://192.168.8.250:4180](http://192.168.8.250:4180) - Service Proxy Gateway

## Signal Notifications 📱
The stack uses [signal-cli-rest-api](https://github.com/bbernhard/signal-cli-rest-api) for self-hosted Signal notifications:
- **Container restart notifications** from AI-Watchdog
- **Prometheus alerts** via Alertmanager
- **Test notifications** via API endpoint
- **End-to-end encrypted** using Signal protocol
- **No third-party dependencies** - fully self-hosted

For detailed setup instructions, see [SIGNAL_INTEGRATION_GUIDE.md](SIGNAL_INTEGRATION_GUIDE.md)

To test Signal notifications:
```bash
curl -X POST http://192.168.8.250:8080/test \
  -H "Content-Type: application/json" \
  -d '{"message": "Test from RPi HA DNS Stack"}'
```

## Health Check Commands ✅
- Check Pi-hole status:
  ```bash
  pihole status
  ```
- Check Unbound status:
  ```bash
  systemctl status unbound
  ```

## Troubleshooting 🔧

### Installation Issues

If you experience issues during installation (SSH disconnects, system reboots, errors):

1. **Use the Easy Installer** (recommended):
   ```bash
   bash scripts/easy-install.sh --verbose
   ```

2. **Common Issues & Solutions**:
   - **SSH Disconnects**: Use `screen` or `tmux` before installation
   - **System Reboots**: Check power supply (need 3A+), monitor temperature
   - **Docker Errors**: Run `sudo usermod -aG docker $USER && newgrp docker`
   - **Permission Errors**: Ensure you own the repo directory
   - **DNS Unreachable**: Network may be misconfigured - run `bash scripts/fix-dns-network.sh`

3. **Get Help**:
   - See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions
   - Check [QUICKSTART.md](QUICKSTART.md) for quick reference
   - Report issues at: https://github.com/yorgosroussakis/rpi-ha-dns-stack/issues

### DNS Not Working?

If DNS containers are unreachable ("host unreachable" errors):

```bash
# Quick diagnosis
bash scripts/validate-network.sh

# Automated fix
bash scripts/fix-dns-network.sh
```

This typically happens when the network was created with the wrong type (bridge instead of macvlan).
See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#issue-dns-containers-unreachable---host-unreachable-errors) for details.

### Quick Recovery

If installation fails:
```bash
# Check logs
cat install.log

# Resume installation
bash scripts/easy-install.sh

# Full reset (if needed)
docker compose down -v
docker system prune -af
rm -f .install_state .env
bash scripts/easy-install.sh
```

## Configuration Details ⚙️
- [Pi-hole Configuration](https://docs.pi-hole.net/)  
- [Unbound Configuration](https://nlnetlabs.nl/projects/unbound/about/)  
- [Keepalived Documentation](https://www.keepalived.org/)  
- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)  

## 🔒 Remote Access (Optional - Super Easy!)

Need to access your home services remotely? We offer **THREE** user-friendly options - choose the easiest for your users!

### 🎯 Choose Your Solution

| Solution | User Ease | Setup | Best For |
|----------|-----------|-------|----------|
| **Tailscale** ⭐⭐⭐⭐⭐ | Install app & sign in | 5 min | EASIEST - Recommended! |
| **Cloudflare Tunnel** ⭐⭐⭐⭐⭐ | Just click a link | 15 min | Web services only (no app!) |
| **WireGuard** ⭐⭐ | Manual config files | 30 min | Advanced users |

### Option 1: Tailscale (RECOMMENDED - Easiest!)

**For End Users:** "Install Tailscale app, sign in with Google, done!"

**Setup:**
```bash
# 1. Get auth key from https://login.tailscale.com/admin/settings/keys
# 2. Add to .env:
TAILSCALE_AUTH_KEY=tskey-auth-xxxxxxxxx

# 3. Deploy:
docker compose -f stacks/remote-access/docker-compose.yml --profile tailscale up -d
```

**User Experience:**
- ✅ No configuration files
- ✅ No port forwarding needed
- ✅ Works with router VPN (Proton, etc.)
- ✅ Sign in with Google/Microsoft/GitHub
- ✅ Automatic access to all services

### Option 2: Cloudflare Tunnel (Web Services - No App Needed!)

**For End Users:** "Click this link: https://jellyfin.yourdomain.com"

**Setup:**
```bash
# 1. Need a domain name ($10/year)
# 2. Create tunnel in Cloudflare dashboard
# 3. Add to .env:
CLOUDFLARE_TUNNEL_TOKEN=your-token

# 4. Deploy:
docker compose -f stacks/remote-access/docker-compose.yml --profile cloudflare up -d
```

**User Experience:**
- ✅ No app installation
- ✅ No VPN needed
- ✅ Professional URLs (jellyfin.yourdomain.com)
- ✅ Free SSL certificates
- ✅ Works on any device with browser

### Option 3: WireGuard (Advanced)

Traditional VPN for power users. See **[stacks/vpn/README.md](stacks/vpn/README.md)** for details.

### Comparison

**Tailscale vs WireGuard:**
```
WireGuard User: "What do I do with this config file?"
Tailscale User: "I installed the app and signed in with Google. It just works!"
```

**Cloudflare vs Everything:**
```
You: "Access at https://jellyfin.yourdomain.com"
User: *clicks link* "That's it? Amazing!"
```

### Full Documentation

See **[stacks/remote-access/README.md](stacks/remote-access/README.md)** for:
- Detailed setup guides for all three options
- End user instructions
- Troubleshooting
- Which option to choose

### Why These Are Better

**The Problem with Traditional VPN:**
- ❌ Users struggle with config files
- ❌ Requires port forwarding
- ❌ Conflicts with router VPNs
- ❌ Complex troubleshooting

**With Tailscale/Cloudflare:**
- ✅ Users just "install & sign in" or "click a link"
- ✅ No port forwarding needed
- ✅ Works everywhere automatically
- ✅ Happy users! 🎉


## 🔐 Single Sign-On (SSO) - Optional but Powerful!

**Centralized Authentication with Authelia**

Tired of managing separate passwords for Pi-hole, Grafana, and WireGuard-UI? Enable SSO for:
- 🔑 **One Login for All Services** - Log in once, access everything
- 🛡️ **Two-Factor Authentication** - TOTP (Google Authenticator) and WebAuthn (YubiKey, TouchID)
- 👥 **User Management** - Add/remove users from one place
- 🚨 **Brute Force Protection** - Automatic rate limiting and banning
- 📊 **Session Control** - Manage active sessions, force logout
- 🔒 **Fine-grained Access Control** - Configure per-service permissions

### Quick SSO Setup

**Option 1: Use the Web Setup Wizard** (Easiest)

1. Launch the setup wizard:
   ```bash
   bash scripts/launch-setup-ui.sh
   ```

2. Follow the wizard to Step 7 (SSO Configuration)
3. Enable SSO and configure admin user
4. Complete the wizard and deploy

**Option 2: Manual Setup**

```bash
# 1. Generate secrets
cd stacks/sso
bash generate-secrets.sh

# 2. Update .env file
# Add the generated secrets to your .env file

# 3. Deploy SSO stack
docker compose up -d

# 4. Access Authelia portal
# http://192.168.8.250:9091
```

### Integrated Services

| Service | Integration | Access |
|---------|------------|---------|
| **Grafana** | Native OAuth2 | Click "Sign in with Authelia" |
| **Pi-hole** | OAuth2 Proxy | http://192.168.8.250:4180 |
| **WireGuard-UI** | External Auth | Auto-redirect to Authelia |
| **Nginx Proxy Manager** | OAuth2 Proxy | Protected endpoints |

### SSO Features

- **Password Policy**: Minimum 12 characters (configurable)
- **Session Duration**: 1 hour active, 5 minutes inactivity (configurable)
- **Remember Me**: 30 days (optional)
- **2FA Methods**: 
  - TOTP (Google Authenticator, Authy, 1Password, etc.)
  - WebAuthn (YubiKey, TouchID, Windows Hello, Android fingerprint)
- **User Groups**: `admins` (full access) and `users` (limited access)

### Documentation

- **[SSO Setup Guide](stacks/sso/README.md)** - Complete SSO documentation
- **[SSO Integration Guide](SSO_INTEGRATION_GUIDE.md)** - Integrate services with SSO
- **[Security Best Practices](SECURITY_GUIDE.md)** - Secure your SSO deployment

### Example: Grafana with SSO

Before SSO:
```
1. Navigate to http://192.168.8.250:3000
2. Enter username: admin
3. Enter password: your_grafana_password
4. Access Grafana
```

After SSO:
```
1. Navigate to http://192.168.8.250:3000
2. Click "Sign in with Authelia"
3. Enter your Authelia credentials (used for ALL services)
4. Complete 2FA (optional but recommended)
5. Access Grafana automatically
```

**Bonus**: Same login works for Pi-hole, WireGuard-UI, and any other integrated service!

### Why Use SSO?

**Security Benefits:**
- 🔐 One strong password to remember (instead of many)
- 🛡️ Mandatory 2FA for all services
- 🚨 Centralized brute force protection
- 📝 Audit trail of all authentication attempts
- ⏱️ Automatic session expiration

**Convenience Benefits:**
- 🎯 Single login for everything
- 💾 "Remember me" option
- 📱 Mobile-friendly authentication
- 🔄 Easy password reset
- 👥 Team member management

**For Home Users**: SSO might be overkill if you're the only user. But if you have family members or want maximum security, it's awesome!

**For Small Teams**: SSO is perfect for managing access for multiple users without creating separate accounts on each service.


## 🛡️ Intrusion Detection System (Optional but Highly Recommended!)

**Protect your entire stack with automated intrusion detection and prevention!**

CrowdSec is a modern, collaborative security system that protects your Pi-hole, SSH, web services, and entire network from attacks. Unlike traditional tools, it uses **crowdsourced threat intelligence** to block attackers before they even reach your system.

### 🎯 Why Add Intrusion Detection?

**Real-World Protection:**
- 🚨 **Blocks SSH brute-force attacks** automatically (no more failed login spam!)
- 🔥 **Protects Pi-hole admin panel** from unauthorized access
- 🛡️ **Guards Grafana dashboards** against exploits
- 🌐 **Web Application Firewall** blocks SQL injection, XSS, and known CVEs
- 🌍 **Global threat intelligence** - benefit from attacks detected worldwide
- ⚡ **Automated response** - no manual intervention needed

**Lightweight & Efficient:**
- 💚 Only ~100-200MB RAM on Raspberry Pi 5
- 🚀 Written in Go for maximum performance
- 📊 Integrated with your existing Prometheus/Grafana monitoring
- ⏱️ Adds < 2ms latency to network traffic

### 🚀 Quick Start

**Option 1: Automated Setup** (Recommended)
```bash
cd stacks/intrusion-detection
bash setup-crowdsec.sh
```

**Option 2: Manual Setup**
```bash
cd stacks/intrusion-detection
cp .env.example .env
docker compose up -d
```

### 📊 What Gets Protected?

| Service | Protection Type | Automated Response |
|---------|----------------|-------------------|
| **SSH** | Brute-force detection | Ban after 5 failed attempts |
| **Pi-hole** | Admin panel attacks | Block suspicious IPs |
| **Grafana** | Login attempts, exploits | Instant IP ban |
| **Nginx** | HTTP attacks, CVEs | WAF blocking + IP ban |
| **WireGuard** | Connection abuse | Rate limiting |
| **Authelia** | SSO brute-force | Additional protection layer |
| **All Services** | Port scans, DDoS | Network-level blocking |

### 🤔 Will My Pi Handle It?

**Raspberry Pi 5 8GB**: Absolutely! ✅ Full protection with minimal overhead
**Raspberry Pi 5 4GB**: Yes! ✅ Use lightweight configuration
**Raspberry Pi 4**: Carefully ⚠️ Monitor resources, use minimal scenarios

**Performance Impact:**
- RAM: +100-200MB (5-10% increase)
- CPU: +3-8% average usage
- Network latency: +1-2ms (negligible)
- DNS query time: +2ms (you won't notice)

### 📚 Documentation

Detailed guides available in `stacks/intrusion-detection/`:

- **[README.md](stacks/intrusion-detection/README.md)** - Complete setup guide
- **[DECISION_GUIDE.md](stacks/intrusion-detection/DECISION_GUIDE.md)** - Should you add IDS?
- **[PERFORMANCE_GUIDE.md](stacks/intrusion-detection/PERFORMANCE_GUIDE.md)** - Resource requirements
- **[PROMETHEUS_INTEGRATION.md](stacks/intrusion-detection/PROMETHEUS_INTEGRATION.md)** - Monitoring setup

### ✅ Key Benefits

**Security:**
- 🌍 **Crowdsourced intelligence**: Block known attackers globally
- 🚨 **Real-time alerts**: Know immediately when attacked
- 🔄 **Automatic updates**: New threat scenarios added regularly
- 📝 **Detailed logs**: See exactly what was blocked and why

**Ease of Use:**
- ⚙️ **Automated setup**: One script does everything
- 📊 **Visual dashboards**: See security metrics in Grafana
- 🔧 **Low maintenance**: Runs autonomously
- 🎯 **Smart defaults**: Works great out-of-the-box

**Integration:**
- 📈 **Prometheus metrics**: Track security events
- 🔔 **Alertmanager integration**: Get notified of attacks
- 🐳 **Docker native**: Fits perfectly with existing stack
- 🔌 **Extensible**: Add custom scenarios easily

### 🎬 See It In Action

```bash
# View current threats being blocked
docker exec crowdsec cscli decisions list

# See attack alerts
docker exec crowdsec cscli alerts list

# Check protection metrics
docker exec crowdsec cscli metrics

# Test SSH protection (from another machine)
# Try wrong password 5 times → You'll get banned!
```

### 💡 Pro Tips

1. **Start with defaults** - They work great for most users
2. **Monitor the first week** - See what gets blocked
3. **Whitelist your IPs** - Never lock yourself out
4. **Enable Grafana dashboard** - Visual security monitoring
5. **Enroll in CrowdSec Console** (optional) - Get premium blocklists

### 🆚 CrowdSec vs Fail2Ban

Still using Fail2Ban? Here's why CrowdSec is better:

| Feature | CrowdSec | Fail2Ban |
|---------|----------|----------|
| **Global threat intelligence** | ✅ Yes | ❌ Local only |
| **Performance** | 🚀 Excellent (Go) | 🐌 Moderate (Python) |
| **Docker integration** | ✅ Native | ⚠️ Requires config |
| **Web protection** | ✅ WAF included | ❌ SSH/system only |
| **Auto updates** | ✅ Community scenarios | ❌ Manual config |
| **Proactive blocking** | ✅ Before they attack you | ❌ After attack detected |

**Verdict**: CrowdSec is the modern choice for containerized environments! 🏆

### 🔗 Learn More

- **CrowdSec Website**: https://www.crowdsec.net/
- **Scenario Hub**: https://hub.crowdsec.net/ (browse protection scenarios)
- **Documentation**: https://docs.crowdsec.net/
- **Community**: https://discord.gg/crowdsec


## Conclusion 🏁
This README provides all necessary information to configure and run a high-availability DNS stack using Raspberry Pi 5. Enjoy a reliable and powerful DNS solution!