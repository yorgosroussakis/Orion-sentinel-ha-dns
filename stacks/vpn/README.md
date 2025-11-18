# VPN Stack - WireGuard with Remote Service Access

This stack provides secure VPN access to your home network and services using WireGuard, inspired by the [wirehole project](https://github.com/IAmStoxe/wirehole).

## 🎯 Use Cases

- **Remote Access**: Access your home services (media servers, file shares, etc.) from anywhere
- **VPN Through VPN**: Use WireGuard even when your router has Proton VPN or another VPN solution
- **Ad-Blocking on the Go**: Use your Pi-hole DNS for ad-blocking when away from home
- **Secure Tunneling**: Encrypt your traffic through your home connection

## 📦 What's Included

### WireGuard VPN Server
- High-performance, modern VPN protocol
- Easy peer/client configuration
- Automatic port forwarding setup
- Split-tunnel support for efficient routing

### WireGuard-UI
- Web-based management interface at `http://<your-ip>:5000`
- Easy peer creation and QR code generation
- Real-time status monitoring
- Configuration management

### Nginx Proxy Manager
- Reverse proxy for exposing internal services
- SSL/TLS certificate management (Let's Encrypt)
- Easy subdomain routing
- Web UI at `http://<your-ip>:81`

## 🚀 Quick Start

### 1. Configure Environment Variables

Add the following to your `.env` file:

```bash
# WireGuard VPN Configuration
WG_SERVER_URL=your-public-ip-or-ddns.com  # Your public IP or DDNS hostname
WG_SERVER_PORT=51820                       # WireGuard port (default: 51820)
WG_PEERS=3                                 # Number of peer configurations to generate
WG_PEER_DNS=192.168.8.251                  # DNS server for VPN clients (Pi-hole)
WG_INTERNAL_SUBNET=10.13.13.0              # Internal VPN subnet
WG_ALLOWED_IPS=0.0.0.0/0                   # Split tunnel: 0.0.0.0/0 (all) or 192.168.8.0/24 (local only)

# WireGuard-UI Credentials
WGUI_USERNAME=admin
WGUI_PASSWORD=CHANGE_ME_REQUIRED           # Generate strong password
WGUI_SESSION_SECRET=CHANGE_ME_REQUIRED     # Generate with: openssl rand -base64 32

# Optional: Email notifications
SENDGRID_API_KEY=
EMAIL_FROM=wireguard@yourdomain.com
EMAIL_FROM_NAME=WireGuard VPN
```

### 2. Set Up Port Forwarding

**IMPORTANT**: Configure your router to forward UDP port 51820 to your Raspberry Pi:

1. Access your router's admin panel
2. Find "Port Forwarding" or "Virtual Server" settings
3. Add rule: External Port `51820 UDP` → Internal IP `192.168.8.250` Port `51820`
4. Save and apply changes

**Note**: If you have Proton VPN running on your router, you may need to:
- Set up port forwarding through Proton's port forwarding feature
- Or run WireGuard on a different device not affected by the router VPN
- Or use a DDNS service to track your changing IP address

### 3. Deploy the Stack

```bash
cd /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack
docker compose -f stacks/vpn/docker-compose.yml up -d
```

### 4. Access WireGuard-UI

Open your browser to `http://192.168.8.250:5000` (or your Pi's IP)

**Default Credentials**:
- Username: `admin` (or what you set in `.env`)
- Password: (what you set in `WGUI_PASSWORD`)

### 5. Create VPN Clients

In WireGuard-UI:
1. Click "New Client"
2. Enter a name (e.g., "iPhone", "Laptop")
3. Click "Create"
4. Scan the QR code with the WireGuard mobile app, or download the config file

## 🔧 Configuration Options

### Split Tunnel vs Full Tunnel

**Split Tunnel** (Recommended):
```bash
WG_ALLOWED_IPS=192.168.8.0/24,10.13.13.0/24
```
- Only routes local network traffic through VPN
- Internet traffic uses your normal connection
- More efficient, better performance

**Full Tunnel**:
```bash
WG_ALLOWED_IPS=0.0.0.0/0
```
- Routes ALL traffic through VPN
- Use your home internet connection everywhere
- Better privacy, but slower

### DNS Configuration

Point VPN clients to your Pi-hole for ad-blocking:
```bash
WG_PEER_DNS=192.168.8.251    # Primary Pi-hole
# Or use both:
# WG_PEER_DNS=192.168.8.251,192.168.8.252
```

## 🌐 Exposing Services with Nginx Proxy Manager

### Access the NPM Interface

1. Open `http://192.168.8.250:81`
2. Default credentials:
   - Email: `admin@example.com`
   - Password: `changeme`
3. **Change these immediately on first login!**

### Example: Expose Jellyfin Media Server

Assuming you have Jellyfin running at `http://192.168.8.100:8096`:

1. In NPM, go to "Proxy Hosts" → "Add Proxy Host"
2. Configure:
   - **Domain Names**: `jellyfin.home.local` (or use your DDNS domain)
   - **Scheme**: `http`
   - **Forward Hostname/IP**: `192.168.8.100`
   - **Forward Port**: `8096`
3. (Optional) Enable SSL with Let's Encrypt
4. Save

Now you can access Jellyfin via VPN at `http://jellyfin.home.local`

### Example: Expose Multiple Services

Create different proxy hosts for each service:
- `plex.home.local` → `192.168.8.101:32400` (Plex)
- `nas.home.local` → `192.168.8.102:5000` (NAS)
- `homeassistant.home.local` → `192.168.8.103:8123` (Home Assistant)

## 🔒 Security Best Practices

1. **Use Strong Passwords**: Generate random passwords for all services
   ```bash
   openssl rand -base64 32
   ```

2. **Keep Software Updated**: Regularly update the stack
   ```bash
   docker compose -f stacks/vpn/docker-compose.yml pull
   docker compose -f stacks/vpn/docker-compose.yml up -d
   ```

3. **Limit Peer Access**: Only create VPN configs for devices you control

4. **Enable Firewall Rules**: Restrict access to sensitive services

5. **Use HTTPS**: Enable SSL certificates in Nginx Proxy Manager

6. **Regular Audits**: Review connected peers and proxy configurations

## 📱 Client Setup

### Mobile (iOS/Android)

1. Install WireGuard app from App Store/Play Store
2. Open WireGuard-UI on your computer
3. Generate a new peer
4. Scan the QR code with the WireGuard app
5. Toggle the connection on

### Desktop (Windows/Mac/Linux)

1. Install WireGuard from [wireguard.com](https://www.wireguard.com/install/)
2. Download the config file from WireGuard-UI
3. Import the config into WireGuard client
4. Activate the tunnel

## 🔍 Troubleshooting

### Can't Connect to VPN

1. **Check port forwarding**: Ensure UDP 51820 is forwarded to your Pi
2. **Verify public IP**: Make sure `WG_SERVER_URL` matches your current public IP
3. **Check firewall**: Ensure no firewall is blocking the port
4. **Review logs**:
   ```bash
   docker logs wireguard
   ```

### Can't Access Services Through VPN

1. **Check routing**: Verify `WG_ALLOWED_IPS` includes your local subnet
2. **Test DNS**: Ping your Pi-hole from VPN client
3. **Verify service is running**: Check if the service is accessible locally
4. **Review proxy configuration**: Check Nginx Proxy Manager settings

### Proton VPN Conflicts

If you have Proton VPN on your router:
- Ensure WireGuard port is excluded from VPN routing
- Consider using policy-based routing to exclude the Pi from router VPN
- Use DDNS if your public IP changes frequently

### Performance Issues

1. **Reduce MTU**: Lower `WGUI_MTU` to 1380 or 1280
2. **Use split-tunnel**: Don't route all traffic through VPN
3. **Check network speed**: Test your upload speed (VPN limited by upload)

## 🔄 Integration with Main Stack

The VPN stack works alongside your main DNS stack:

```bash
# Start everything
cd /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack
docker compose -f stacks/dns/docker-compose.yml up -d
docker compose -f stacks/observability/docker-compose.yml up -d
docker compose -f stacks/vpn/docker-compose.yml up -d
```

## 📊 Monitoring

Monitor VPN connections through:
- **WireGuard-UI**: Real-time peer status at `http://<ip>:5000`
- **Grafana**: Add WireGuard metrics (requires additional configuration)
- **System logs**: `docker logs -f wireguard`

## 🆘 Support

For issues specific to:
- **WireGuard**: [WireGuard Documentation](https://www.wireguard.com/)
- **WireGuard-UI**: [GitHub Issues](https://github.com/ngoduykhanh/wireguard-ui)
- **Nginx Proxy Manager**: [NPM Documentation](https://nginxproxymanager.com/)

## 📚 Additional Resources

- [WireGuard Quick Start](https://www.wireguard.com/quickstart/)
- [Nginx Proxy Manager Guide](https://nginxproxymanager.com/guide/)
- [Split Tunneling Explained](https://en.wikipedia.org/wiki/Split_tunneling)
- [DDNS Setup Guide](https://www.noip.com/support/knowledgebase/getting-started-with-no-ip-com/)
