# VPN Stack Deployment Guide

This guide walks you through deploying the WireGuard VPN stack to enable secure remote access to your home services.

## Prerequisites

- Raspberry Pi running the base DNS stack
- Public IP address or DDNS hostname
- Router with port forwarding capability
- Basic understanding of networking concepts

## Deployment Steps

### Step 1: Update Environment Configuration

Edit your `.env` file and add the VPN configuration:

```bash
cd /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack
nano .env  # or vim .env
```

Add the following configuration:

```bash
# WireGuard VPN Configuration
WG_SERVER_URL=your-public-ip-or-ddns.com  # Replace with your public IP or DDNS
WG_SERVER_PORT=51820
WG_PEERS=3  # Adjust based on number of devices you want to connect
WG_PEER_DNS=192.168.8.251  # Use Pi-hole for DNS
WG_INTERNAL_SUBNET=10.13.13.0
WG_ALLOWED_IPS=0.0.0.0/0  # Use 192.168.8.0/24 for split tunnel
WG_LOG_CONFS=true

# WireGuard-UI Credentials
WGUI_USERNAME=admin
WGUI_PASSWORD=$(openssl rand -base64 32)  # Generate this first
WGUI_SESSION_SECRET=$(openssl rand -base64 32)  # Generate this first
WGUI_MTU=1420
WGUI_PERSISTENT_KEEPALIVE=25
WGUI_FORWARD_MARK=0xca6c

# Optional: Email Notifications
SENDGRID_API_KEY=
EMAIL_FROM=wireguard@yourdomain.com
EMAIL_FROM_NAME=WireGuard VPN
```

**Important**: Replace the placeholder values:
- `WG_SERVER_URL`: Your public IP (find it at https://ifconfig.me) or DDNS hostname
- `WGUI_PASSWORD`: Generate with `openssl rand -base64 32`
- `WGUI_SESSION_SECRET`: Generate with `openssl rand -base64 32`

### Step 2: Configure Router Port Forwarding

**Critical Step**: Without port forwarding, VPN connections will fail.

1. Find your router's admin interface (usually http://192.168.8.1 or similar)
2. Log in with admin credentials
3. Navigate to "Port Forwarding" or "Virtual Server" section
4. Add a new rule:
   - **Service Name**: WireGuard VPN
   - **External Port**: 51820
   - **Protocol**: UDP
   - **Internal IP**: 192.168.8.250 (your Raspberry Pi)
   - **Internal Port**: 51820
5. Save and apply the configuration

**For Proton VPN Users**: If you have Proton VPN on your router:
- Check if Proton supports port forwarding (it does for paying customers)
- Alternatively, exclude the Raspberry Pi from the VPN routing
- Or use a DDNS service if your IP changes frequently

### Step 3: Set Up Dynamic DNS (Optional but Recommended)

If your ISP changes your public IP address periodically, use a DDNS service:

#### Option A: No-IP (Free)
1. Sign up at https://www.noip.com/
2. Create a hostname (e.g., `myhome.ddns.net`)
3. Install the No-IP DUC client on your Pi:
   ```bash
   cd /tmp
   wget https://www.noip.com/client/linux/noip-duc-linux.tar.gz
   tar xzf noip-duc-linux.tar.gz
   cd noip-2.1.9-1
   sudo make
   sudo make install
   ```
4. Configure with your No-IP credentials
5. Update `WG_SERVER_URL` in `.env` to your DDNS hostname

#### Option B: DuckDNS (Free)
1. Sign up at https://www.duckdns.org/
2. Create a subdomain
3. Set up cron job to update IP:
   ```bash
   echo "*/5 * * * * curl 'https://www.duckdns.org/update?domains=YOUR_DOMAIN&token=YOUR_TOKEN&ip=' >/dev/null 2>&1" | crontab -
   ```
4. Update `WG_SERVER_URL` in `.env` to your DuckDNS hostname

#### Option C: Cloudflare (Free)
1. Register a domain with Cloudflare
2. Use their DDNS update API
3. Update `WG_SERVER_URL` in `.env` to your domain

### Step 4: Deploy the VPN Stack

```bash
cd /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack

# Verify configuration
cat .env | grep WG_

# Deploy VPN stack
docker compose -f stacks/vpn/docker-compose.yml up -d

# Verify containers are running
docker compose -f stacks/vpn/docker-compose.yml ps

# Check logs
docker logs wireguard
docker logs wireguard-ui
docker logs nginx-proxy-manager
```

Expected output:
```
NAME                   STATUS         PORTS
wireguard              Up             0.0.0.0:51820->51820/udp, 0.0.0.0:5000->5000/tcp
wireguard-ui           Up             (shares network with wireguard)
nginx-proxy-manager    Up             0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp, 0.0.0.0:81->81/tcp
```

### Step 5: Access WireGuard-UI

1. Open your browser to `http://192.168.8.250:5000`
2. Log in with credentials from `.env`:
   - Username: (value of `WGUI_USERNAME`)
   - Password: (value of `WGUI_PASSWORD`)
3. You should see the WireGuard-UI dashboard

### Step 6: Create Your First VPN Client

1. In WireGuard-UI, click "New Client"
2. Fill in the form:
   - **Name**: `MyPhone` (or any descriptive name)
   - **Email**: (optional)
   - **Allocated IPs**: (auto-filled, usually 10.13.13.2)
   - **Allowed IPs**: 
     - Full tunnel: `0.0.0.0/0, ::/0`
     - Split tunnel: `192.168.8.0/24, 10.13.13.0/24`
   - **Extra Allowed IPs**: (leave empty for now)
3. Click "Submit"
4. Click on the client name to view details
5. Either:
   - Scan the QR code with WireGuard mobile app
   - Download the configuration file for desktop clients

### Step 7: Install WireGuard Client

#### Mobile (iOS/Android)
1. Install WireGuard from App Store or Google Play
2. Open the app
3. Tap "+" → "Create from QR code"
4. Scan the QR code from WireGuard-UI
5. Name the tunnel (e.g., "Home VPN")
6. Toggle the switch to connect

#### Desktop (Windows/macOS/Linux)
1. Download WireGuard from https://www.wireguard.com/install/
2. Install the application
3. Download the config file from WireGuard-UI
4. In WireGuard client: "Add Tunnel" → "Import from file"
5. Select your downloaded `.conf` file
6. Click "Activate"

### Step 8: Test VPN Connection

Once connected to the VPN:

1. **Check IP Address**: Your public IP should now be your home IP
   ```bash
   curl ifconfig.me
   ```

2. **Test DNS**: Should use Pi-hole
   ```bash
   nslookup google.com
   # Should show 192.168.8.251 as the server
   ```

3. **Ping Home Network**:
   ```bash
   ping 192.168.8.250
   ```

4. **Access Pi-hole Dashboard**: http://192.168.8.251/admin

### Step 9: Configure Nginx Proxy Manager

1. Open `http://192.168.8.250:81`
2. **First-time login**:
   - Email: `admin@example.com`
   - Password: `changeme`
3. **Change credentials immediately**:
   - Set a strong email and password
4. Navigate to "Proxy Hosts"

#### Example: Expose Jellyfin Media Server

Assuming Jellyfin is at `192.168.8.100:8096`:

1. Click "Add Proxy Host"
2. **Details** tab:
   - Domain Names: `jellyfin.home.local`
   - Scheme: `http`
   - Forward Hostname/IP: `192.168.8.100`
   - Forward Port: `8096`
   - Cache Assets: ✓
   - Block Common Exploits: ✓
   - Websockets Support: ✓
3. **SSL** tab (optional):
   - SSL Certificate: None (for .local domain)
   - Or use Let's Encrypt if you have a real domain
4. Click "Save"

Now access Jellyfin via VPN at: `http://jellyfin.home.local`

#### Example: Multiple Services

Create additional proxy hosts:
- `plex.home.local` → `192.168.8.101:32400`
- `nas.home.local` → `192.168.8.102:5000`
- `homeassistant.home.local` → `192.168.8.103:8123`

### Step 10: Verify Everything Works

**From a VPN-connected device**:

```bash
# Check VPN is active
wg show  # On Linux/macOS

# Test DNS resolution
nslookup jellyfin.home.local
# Should resolve to 192.168.8.100 (or NPM IP)

# Test service access
curl -I http://jellyfin.home.local
# Should return HTTP 200 OK

# Check Pi-hole is filtering ads
curl -I http://doubleclick.net
# Should be blocked by Pi-hole
```

## Post-Deployment Tasks

### Enable Auto-Start on Boot

Ensure the VPN stack starts automatically:

```bash
# Add to system startup
sudo systemctl enable docker

# Create systemd service (optional)
cat << 'EOF' | sudo tee /etc/systemd/system/wireguard-stack.service
[Unit]
Description=WireGuard VPN Stack
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack
ExecStart=/usr/bin/docker compose -f stacks/vpn/docker-compose.yml up -d
ExecStop=/usr/bin/docker compose -f stacks/vpn/docker-compose.yml down

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable wireguard-stack
sudo systemctl start wireguard-stack
```

### Regular Maintenance

**Weekly**:
- Check VPN connection logs: `docker logs wireguard`
- Review connected peers in WireGuard-UI
- Verify services are accessible

**Monthly**:
- Update containers:
  ```bash
  docker compose -f stacks/vpn/docker-compose.yml pull
  docker compose -f stacks/vpn/docker-compose.yml up -d
  ```
- Review and revoke unused peer configurations
- Audit Nginx Proxy Manager logs

**Quarterly**:
- Rotate credentials (WGUI_PASSWORD, WGUI_SESSION_SECRET)
- Review firewall rules
- Test disaster recovery procedures

### Backup Configuration

```bash
#!/bin/bash
# Backup script
BACKUP_DIR="$HOME/vpn-backups/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

cd /home/runner/work/rpi-ha-dns-stack/rpi-ha-dns-stack

# Backup VPN configuration
cp -r stacks/vpn/wireguard "$BACKUP_DIR/"
cp -r stacks/vpn/wireguard-ui "$BACKUP_DIR/"
cp -r stacks/vpn/nginx-proxy-manager "$BACKUP_DIR/"
cp .env "$BACKUP_DIR/.env"

# Create archive
tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

echo "Backup created: $BACKUP_DIR.tar.gz"
```

## Troubleshooting

### VPN Won't Connect

1. **Check port forwarding**: Use https://www.yougetsignal.com/tools/open-ports/ to verify port 51820 is open
2. **Verify public IP**: Ensure `WG_SERVER_URL` matches your current public IP
3. **Check logs**: `docker logs wireguard`
4. **Firewall**: Ensure no firewall is blocking UDP 51820

### Can't Access Services Through VPN

1. **Check routing**: Verify `WG_ALLOWED_IPS` includes your home subnet
2. **Test local access**: Ensure services work locally first
3. **Check proxy config**: Verify Nginx Proxy Manager settings
4. **DNS issues**: Ensure VPN clients are using Pi-hole DNS

### Performance Issues

1. **Lower MTU**: Set `WGUI_MTU=1380` or `1280`
2. **Use split tunnel**: Set `WG_ALLOWED_IPS=192.168.8.0/24`
3. **Check upload speed**: VPN speed limited by home upload bandwidth

### Proton VPN Conflicts

1. **Exclude Pi from router VPN**: Configure router to bypass VPN for 192.168.8.250
2. **Use DDNS**: If IP changes frequently due to VPN
3. **Alternative approach**: Run WireGuard on a separate device

## Security Considerations

1. **Strong Passwords**: Use randomly generated passwords (32+ characters)
2. **Regular Updates**: Keep containers updated
3. **Peer Audit**: Regularly review and remove unused peers
4. **Firewall Rules**: Limit access to necessary services only
5. **SSL Certificates**: Use HTTPS with Let's Encrypt for exposed services
6. **2FA**: Enable if supported by your services
7. **Logging**: Monitor access logs regularly

## Advanced Configuration

### Custom WireGuard Config

Edit `stacks/vpn/wireguard/config/wg0.conf` for advanced settings.

### Multiple Subnets

Allow access to multiple networks:
```bash
WG_ALLOWED_IPS=192.168.8.0/24,192.168.9.0/24,10.0.0.0/24
```

### Site-to-Site VPN

Connect multiple locations by creating peer configs on both ends.

## Integration with Monitoring Stack

To monitor VPN connections:

1. Add WireGuard exporter to observability stack
2. Configure Grafana dashboard for VPN metrics
3. Set up alerts for connection issues

## Support

- **WireGuard Issues**: https://www.wireguard.com/
- **WireGuard-UI**: https://github.com/ngoduykhanh/wireguard-ui
- **Nginx Proxy Manager**: https://nginxproxymanager.com/
- **This Stack**: https://github.com/yorgosroussakis/rpi-ha-dns-stack/issues
