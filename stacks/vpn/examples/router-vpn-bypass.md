# Router VPN Bypass Configuration
# How to use WireGuard when your router already has a VPN (like Proton VPN)

## The Problem

You have Proton VPN (or another VPN) running on your router, and now you want to:
1. Set up WireGuard to access home services remotely
2. Keep the router VPN active for other devices

## Challenges

1. **IP Address Changes**: Router VPN may change your public IP
2. **Port Forwarding**: Router VPN may interfere with port forwarding
3. **Routing Conflicts**: Both VPNs may conflict
4. **DDNS Updates**: Public IP changes more frequently

## Solutions

### Solution 1: Exclude Raspberry Pi from Router VPN (RECOMMENDED)

Most router VPN implementations allow excluding specific devices.

#### For OpenWRT/DD-WRT:
```bash
# Add to router's VPN configuration
# Exclude the Raspberry Pi IP
route-nopull
route 0.0.0.0 0.0.0.0 net_gateway
```

#### For pfSense/OPNsense:
1. Go to VPN → OpenVPN → Client
2. Add to "Custom options":
   ```
   route-nopull
   ```
3. Create a firewall rule to bypass VPN for 192.168.8.250

#### For Commercial Routers (ASUS, Netgear, etc.):
Look for "VPN Director", "Policy Routing", or "Split Tunneling" options:
1. Access router admin panel
2. Find VPN client settings
3. Add exception for 192.168.8.250
4. Save and apply

**Result**: 
- Pi gets direct internet access
- Other devices still use router VPN
- WireGuard works normally

### Solution 2: Use Dynamic DNS (DDNS)

Since router VPN may change your public IP frequently, use DDNS:

#### Setup DuckDNS (Free):
```bash
# On your Raspberry Pi
# Create update script
cat << 'EOF' > /home/pi/update-ddns.sh
#!/bin/bash
curl "https://www.duckdns.org/update?domains=YOUR_DOMAIN&token=YOUR_TOKEN&ip="
EOF

chmod +x /home/pi/update-ddns.sh

# Add to crontab (updates every 5 minutes)
crontab -e
# Add this line:
*/5 * * * * /home/pi/update-ddns.sh >/dev/null 2>&1
```

#### Update .env:
```bash
WG_SERVER_URL=yourdomain.duckdns.org
```

**Result**: 
- VPN clients always know how to reach your home
- Even if IP changes frequently

### Solution 3: Port Forward Through Router VPN

Some VPN services support port forwarding (Proton VPN paid plans do).

#### For Proton VPN:
1. Log into Proton VPN account
2. Go to Settings → Port Forwarding
3. Request a port (you'll get a random port, e.g., 51234)
4. Configure WireGuard to use that port:
   ```bash
   WG_SERVER_PORT=51234  # Use Proton's assigned port
   ```
5. Update WireGuard peers with new port

**Result**:
- WireGuard works through router VPN
- May have additional latency

### Solution 4: Dual Router Setup

If you have two routers:

```
Internet → Router 1 (Proton VPN) → Router 2 (WireGuard Pi)
                                 → Other Devices
```

1. Connect Router 2 to Router 1's LAN port
2. Put Pi on Router 2
3. Forward ports on both routers: Router 1 → Router 2 → Pi

**Result**:
- Clean separation of concerns
- More complex setup

### Solution 5: VPN Kill Switch Exclusion

If your router has a VPN kill switch:

1. Find kill switch settings
2. Add exception for WireGuard port (51820/udp)
3. Add exception for Pi IP (192.168.8.250)

**Result**:
- Kill switch won't block WireGuard

## Recommended Configuration

### .env Settings for Router VPN Scenario:
```bash
# Use DDNS instead of IP
WG_SERVER_URL=yourhome.duckdns.org

# Default or router-assigned port
WG_SERVER_PORT=51820

# Lower MTU may help with double VPN encapsulation
WGUI_MTU=1380

# More aggressive keepalive
WGUI_PERSISTENT_KEEPALIVE=15

# Standard split tunnel config
WG_ALLOWED_IPS=192.168.8.0/24,10.13.13.0/24
```

## Testing Your Setup

### 1. Test Port Forwarding
```bash
# From external network (use phone on cellular)
nc -vzu your.ddns.address 51820
```

### 2. Check Public IP
```bash
# On Raspberry Pi
curl ifconfig.me

# Should show:
# - Router VPN IP if Pi is behind router VPN
# - Your real IP if Pi is excluded from router VPN
```

### 3. Test WireGuard Connection
```bash
# After connecting to WireGuard
ping 192.168.8.250
# Should work if setup is correct
```

## Troubleshooting

### WireGuard Won't Connect

**Check 1: Port is forwarded**
```bash
# Use online port checker
https://www.yougetsignal.com/tools/open-ports/
# Test your DDNS hostname and port 51820
```

**Check 2: DDNS is updating**
```bash
# On Pi, check current public IP
curl ifconfig.me

# Resolve DDNS
nslookup yourdomain.duckdns.org
# Should match
```

**Check 3: Router VPN status**
```bash
# On router, check if Pi is excluded from VPN
# Look for Pi IP (192.168.8.250) in exception list
```

### Intermittent Disconnections

**Cause**: Public IP changing when router VPN reconnects

**Fix**:
1. Use DDNS (Solution 2 above)
2. Set shorter DDNS update interval (1-2 minutes)
3. Increase WireGuard keepalive:
   ```bash
   WGUI_PERSISTENT_KEEPALIVE=15
   ```

### Slow Performance

**Cause**: Double VPN encapsulation (router VPN + WireGuard)

**Fix**:
1. Exclude Pi from router VPN (Solution 1)
2. Lower MTU:
   ```bash
   WGUI_MTU=1280
   ```
3. Use split tunnel instead of full tunnel

## Best Practice Configuration

```bash
# In .env
WG_SERVER_URL=myhome.duckdns.org  # Use DDNS
WG_SERVER_PORT=51820
WG_PEERS=3
WG_PEER_DNS=192.168.8.251
WG_INTERNAL_SUBNET=10.13.13.0
WG_ALLOWED_IPS=192.168.8.0/24,10.13.13.0/24  # Split tunnel
WGUI_MTU=1380  # Lower for double VPN
WGUI_PERSISTENT_KEEPALIVE=15  # Aggressive keepalive
```

## Summary

**Recommended Approach**: Solution 1 (Exclude Pi from Router VPN) + Solution 2 (Use DDNS)

This provides:
✓ Clean separation of VPNs
✓ Reliable connectivity
✓ Good performance
✓ Easy maintenance

**Quick Setup**:
1. Configure router to exclude 192.168.8.250 from VPN
2. Set up DuckDNS on Pi
3. Use DDNS hostname in WG_SERVER_URL
4. Lower MTU to 1380
5. Use split tunnel configuration

**Result**: WireGuard works perfectly alongside router VPN!
