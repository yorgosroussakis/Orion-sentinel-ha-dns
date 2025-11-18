# Remote Access Stack - Choose Your Solution

This stack provides THREE user-friendly options for remote access to your home services. Choose based on your needs and technical comfort level.

## 🎯 Which Option Should I Use?

### Quick Decision Guide

**Choose Tailscale if:**
- ✅ You want the EASIEST solution for end users
- ✅ Users should just "install app and sign in"
- ✅ You don't want to manage configurations
- ✅ You want automatic device discovery
- ✅ No port forwarding hassles

**Choose Cloudflare Tunnel if:**
- ✅ You only need web services (HTTP/HTTPS)
- ✅ Users should just "click a link"
- ✅ You want professional URLs (jellyfin.yourdomain.com)
- ✅ You want free SSL certificates
- ✅ No VPN app needed for users

**Choose WireGuard if:**
- ✅ You're technical and want full control
- ✅ You can distribute config files to users
- ✅ You want self-hosted only (no third party)
- ✅ Users are technical enough to configure VPN

### Recommended: Use Multiple!

**Best Setup:**
- **Tailscale**: For technical users and full network access
- **Cloudflare Tunnel**: For non-technical users and web services
- **WireGuard**: Optional, for advanced use cases

## 📦 Option 1: Tailscale (EASIEST) ⭐⭐⭐⭐⭐

### What is Tailscale?

Tailscale creates a mesh VPN that "just works". Users install an app, sign in, and they're connected. No configuration files, no port forwarding, no technical knowledge needed.

### Setup for You (Service Owner)

1. **Get Tailscale Auth Key**:
   - Go to https://login.tailscale.com/admin/settings/keys
   - Create an auth key (check "Reusable" and "Ephemeral")
   - Copy the key

2. **Add to .env**:
   ```bash
   TAILSCALE_AUTH_KEY=tskey-auth-xxxxxxxxx
   TAILSCALE_HOSTNAME=rpi-dns-stack
   TAILSCALE_ROUTES=192.168.8.0/24
   ```

3. **Deploy**:
   ```bash
   docker compose -f stacks/remote-access/docker-compose.yml --profile tailscale up -d
   ```

4. **Approve Route** (one-time):
   - Go to https://login.tailscale.com/admin/machines
   - Find your Pi
   - Click "Edit route settings"
   - Approve the 192.168.8.0/24 subnet route

### Setup for End Users (SUPER EASY!)

**Instructions you send to users:**

"Hi! To access my media server, follow these 3 steps:

1. Install Tailscale:
   - iPhone/iPad: https://apps.apple.com/app/tailscale/id1470499037
   - Android: https://play.google.com/store/apps/details?id=com.tailscale.ipn
   - Windows/Mac: https://tailscale.com/download

2. Open Tailscale and sign in with your Google/Microsoft/GitHub account

3. That's it! I'll approve you and you can access:
   - Jellyfin: http://100.x.x.x:8096 (I'll send you the IP)
   - Or use MagicDNS: http://rpi-dns-stack:8096"

**What happens:**
1. User installs app (2 minutes)
2. User signs in with familiar account (30 seconds)
3. You see them in admin panel, click "Approve" (10 seconds)
4. User can now access all your services!

### Advantages
- ✅ **Zero Configuration**: No config files to distribute
- ✅ **Automatic**: Just works across all networks
- ✅ **No Port Forwarding**: Works behind NAT
- ✅ **Works with Router VPN**: No conflicts with Proton VPN
- ✅ **Cross-Platform**: Same experience everywhere
- ✅ **Access Control**: Easy to revoke access

### Cost
- **Free**: Up to 100 devices, 3 users
- **Personal**: $5/month for unlimited users
- **Perfect for**: Home use

### URLs After Connection
- Jellyfin: `http://rpi-dns-stack:8096` or `http://100.x.x.x:8096`
- Pi-hole: `http://192.168.8.251/admin`
- Any service on your network!

---

## 📦 Option 2: Cloudflare Tunnel (WEB ONLY) ⭐⭐⭐⭐⭐

### What is Cloudflare Tunnel?

Makes your web services accessible via HTTPS without VPN. Users just click a link - no app installation needed!

### Setup for You

1. **Domain Required**: You need a domain (e.g., yourdomain.com)
   - Buy from Namecheap, Google Domains, etc. (~$10/year)
   - Point nameservers to Cloudflare (free)

2. **Create Tunnel**:
   ```bash
   # Install cloudflared locally (one-time)
   curl -L https://pkg.cloudflare.com/cloudflared-stable-linux-arm64.deb -o cloudflared.deb
   sudo dpkg -i cloudflared.deb
   
   # Login to Cloudflare
   cloudflared tunnel login
   
   # Create tunnel
   cloudflared tunnel create rpi-tunnel
   
   # This creates a credentials file and gives you a tunnel token
   ```

3. **Add to .env**:
   ```bash
   CLOUDFLARE_TUNNEL_TOKEN=your-tunnel-token-here
   ```

4. **Configure Routes** (in Cloudflare dashboard):
   - jellyfin.yourdomain.com → http://192.168.8.100:8096
   - photos.yourdomain.com → http://192.168.8.101:2283
   - nas.yourdomain.com → http://192.168.8.102:5000

5. **Deploy**:
   ```bash
   docker compose -f stacks/remote-access/docker-compose.yml --profile cloudflare up -d
   ```

### Setup for End Users (EASIEST!)

**Instructions you send to users:**

"Access my media server at: https://jellyfin.yourdomain.com

That's it! Just click the link."

### Advantages
- ✅ **No App Needed**: Works in any browser
- ✅ **Professional URLs**: Custom domains
- ✅ **Free SSL**: Automatic HTTPS
- ✅ **DDoS Protection**: Cloudflare security
- ✅ **Fast**: Cloudflare CDN
- ✅ **Access Control**: Can add authentication

### Limitations
- ⚠️ **Web Only**: Only HTTP/HTTPS services
- ⚠️ **Domain Required**: Need to buy domain name
- ⚠️ **Cloudflare Required**: Traffic goes through Cloudflare

### Cost
- **Free**: Unlimited bandwidth for personal use
- **Domain**: $10-15/year
- **Perfect for**: Sharing web services with family/friends

---

## 📦 Option 3: WireGuard (ADVANCED) ⭐⭐

### What is WireGuard?

Traditional VPN requiring manual configuration. Good for power users who want full control.

### Setup

See `stacks/vpn/` directory for full WireGuard documentation.

**Quick start:**
```bash
# Add to .env
WG_SERVER_URL=your-public-ip-or-ddns.com
WG_PEERS=3
WGUI_PASSWORD=$(openssl rand -base64 32)
WGUI_SESSION_SECRET=$(openssl rand -base64 32)

# Deploy
docker compose -f stacks/remote-access/docker-compose.yml --profile wireguard up -d

# Access UI
http://192.168.8.250:5000
```

### Setup for End Users

1. You create config in WireGuard-UI
2. You send config file or QR code to user
3. User installs WireGuard app
4. User imports configuration
5. User connects

**More complex than Tailscale!**

---

## 🚀 Deployment Guide

### Deploy Single Option

**Tailscale only:**
```bash
docker compose -f stacks/remote-access/docker-compose.yml --profile tailscale up -d
```

**Cloudflare only:**
```bash
docker compose -f stacks/remote-access/docker-compose.yml --profile cloudflare up -d
```

**WireGuard only:**
```bash
docker compose -f stacks/remote-access/docker-compose.yml --profile wireguard up -d
```

### Deploy Multiple Options

**Tailscale + Cloudflare (RECOMMENDED):**
```bash
docker compose -f stacks/remote-access/docker-compose.yml --profile tailscale --profile cloudflare up -d
```

**All three:**
```bash
docker compose -f stacks/remote-access/docker-compose.yml \
  --profile tailscale \
  --profile cloudflare \
  --profile wireguard \
  up -d
```

### Deploy with Nginx Proxy Manager (Always Included)

Nginx Proxy Manager is always deployed as it's useful for all options.

---

## 📊 Comparison Matrix

| Feature | Tailscale | Cloudflare | WireGuard |
|---------|-----------|------------|-----------|
| **User Setup Time** | 2 min | 0 min (just click) | 10+ min |
| **Technical Level** | None | None | Intermediate |
| **Port Forwarding** | No | No | Yes |
| **Works with Router VPN** | Yes | Yes | Maybe |
| **App Installation** | Yes (easy) | No | Yes (complex) |
| **All Protocols** | Yes | Web only | Yes |
| **Free Tier** | Yes (100 devices) | Yes (unlimited) | Yes (self-hosted) |
| **Third Party** | Yes (Tailscale) | Yes (Cloudflare) | No |
| **SSL Certificates** | No (not needed) | Yes (auto) | Manual |
| **Access Control** | Built-in | Built-in | Manual |

---

## 🎓 Real-World Scenarios

### Scenario 1: Sharing Jellyfin with Non-Technical Parents

**Best: Cloudflare Tunnel**
```
You: "Watch movies at https://movies.yourdomain.com"
Them: *clicks link* "It works!"
```

No VPN app, no configuration, just a link.

### Scenario 2: Accessing Everything While Traveling

**Best: Tailscale**
```
Install once, sign in, forget about it.
Works everywhere: hotel WiFi, cellular, airport.
Access everything: Jellyfin, NAS, Pi-hole admin, SSH.
```

### Scenario 3: Power User Wants Full Control

**Best: WireGuard**
```
Full control over configuration.
No third-party services.
Technical user can handle setup.
```

### Scenario 4: Mixed User Base

**Best: All Three!**
- Technical users: Tailscale or WireGuard
- Non-technical users: Cloudflare Tunnel
- Web services: Always available via Cloudflare
- Full access: Available via Tailscale

---

## 🔒 Security Comparison

All three options are secure, but implement security differently:

**Tailscale:**
- Encryption: WireGuard protocol
- Auth: OAuth (Google, Microsoft, GitHub, etc.)
- 2FA: Through OAuth provider
- Key Management: Automatic
- Access Control: Centralized dashboard

**Cloudflare:**
- Encryption: TLS 1.3
- Auth: Optional (Cloudflare Access)
- 2FA: Optional (can enable)
- Key Management: Automatic (TLS certs)
- Access Control: Cloudflare dashboard

**WireGuard:**
- Encryption: WireGuard protocol
- Auth: Pre-shared keys
- 2FA: No
- Key Management: Manual
- Access Control: Manual (per-peer)

---

## 💰 Cost Breakdown

### Tailscale
- **Personal Use**: FREE (up to 100 devices)
- **More Users**: $5/month/user
- **You Pay**: Nothing extra!

### Cloudflare Tunnel
- **Service**: FREE (unlimited bandwidth)
- **Domain**: $10-15/year (required)
- **Optional Pro**: $20/month (not needed for most)

### WireGuard
- **Service**: FREE (self-hosted)
- **DDNS**: $0-25/year (optional)
- **No Other Costs**

---

## 🆘 Troubleshooting

### Tailscale Issues

**Can't connect:**
1. Check if route is approved in admin panel
2. Verify `--accept-routes` is set
3. Restart Tailscale container

**Users can't access services:**
1. Ensure subnet route is advertised
2. Check firewall rules
3. Verify service is running locally

### Cloudflare Issues

**502 Bad Gateway:**
1. Check if service is running
2. Verify internal IP/port in config
3. Check cloudflared logs: `docker logs cloudflared`

**Can't create tunnel:**
1. Verify domain is on Cloudflare
2. Check tunnel token is correct
3. Review Cloudflare dashboard for errors

### WireGuard Issues

See `stacks/vpn/TROUBLESHOOTING.md` for detailed WireGuard help.

---

## 📚 Further Reading

- [Tailscale Documentation](https://tailscale.com/kb/)
- [Cloudflare Tunnel Guide](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [WireGuard Documentation](stacks/vpn/README.md)

---

## 🎉 Recommendation

**For most users:** Start with **Tailscale** for its incredible ease of use. Add **Cloudflare Tunnel** for web services that non-technical users need to access.

This gives you the best of both worlds:
- Technical users get full access via Tailscale
- Non-technical users just click links via Cloudflare
- No complex configuration for anyone
- Works perfectly with your Proton VPN router

**Bottom Line:** Your users will thank you for making it so easy! 🚀
