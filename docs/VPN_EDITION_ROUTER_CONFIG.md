# VPN Edition: Router Configuration Guide

This guide walks you through configuring your home router for WireGuard VPN access.

## 📋 Prerequisites

Before starting:
- ✅ VPN Edition installed and running on your Pi
- ✅ Pi has a static IP on your network (e.g., 192.168.8.250)
- ✅ Router admin access (username/password)
- ✅ Public IP or DDNS hostname configured

---

## 🌐 Understanding Port Forwarding

### What is Port Forwarding?

Port forwarding tells your router to send incoming internet traffic on a specific port to a specific device on your network.

**For VPN Edition:**
- **External Port:** 51820 (UDP) - What the internet sees
- **Internal IP:** Your Pi's IP (e.g., 192.168.8.250)
- **Internal Port:** 51820 (UDP) - Where Pi listens
- **Protocol:** UDP (required for WireGuard)

### Why UDP Port 51820?

- WireGuard's default port
- UDP provides better performance than TCP for VPN
- Single port = minimal attack surface
- No other ports need to be opened!

---

## 🔧 Configuration by Router Brand

### Universal Steps (All Routers)

1. **Access Router Admin Panel**
   - Open browser
   - Go to router IP (usually `192.168.1.1` or `192.168.0.1`)
   - Login with admin credentials

2. **Find Port Forwarding Section**
   - Common names:
     - "Port Forwarding"
     - "Virtual Servers"
     - "NAT Forwarding"
     - "Applications & Gaming"
     - "Firewall" → "Port Forwarding"

3. **Create Forward Rule**
   - **Service/Application Name:** WireGuard VPN
   - **External Port:** 51820
   - **Internal IP:** 192.168.8.250 (your Pi)
   - **Internal Port:** 51820
   - **Protocol:** UDP
   - **Enable/Active:** Yes

4. **Save & Apply**

---

### TP-Link Routers

**Path:** Advanced → NAT Forwarding → Virtual Servers

**Configuration:**
```
Service Type: Custom
External Port: 51820
Internal Port: 51820
Internal IP: 192.168.8.250
Protocol: UDP
Status: Enabled
```

**Screenshot Tip:** Look for "Add" or "+" button

**Save:** Click "Save" then "Apply"

---

### ASUS Routers

**Path:** WAN → Virtual Server / Port Forwarding

**Configuration:**
```
Enable: Yes
Service Name: WireGuard
Port Range: 51820
Local IP: 192.168.8.250
Local Port: 51820
Protocol: UDP
Source IP: (leave blank for all)
```

**Save:** Click "Apply"

**Advanced (Optional):** You can set source IP to limit which external IPs can connect

---

### Netgear Routers

**Path:** Advanced → Advanced Setup → Port Forwarding/Port Triggering

**Configuration:**
```
Service Name: WireGuard-VPN
Service Type: UDP
External Port: 51820
Internal Port: 51820
Internal IP Address: 192.168.8.250
```

**Save:** Click "Apply"

---

### Linksys Routers

**Path:** Security → Apps and Gaming → Single Port Forwarding

**Configuration:**
```
Application Name: WireGuard
External Port: 51820-51820
Internal Port: 51820-51820
Protocol: UDP
To IP Address: 192.168.8.250
Enabled: ✓
```

**Save:** Click "Save Settings"

---

### D-Link Routers

**Path:** Advanced → Port Forwarding

**Configuration:**
```
Name: WireGuard
IP Address: 192.168.8.250
Computer Name: (auto-fills or use dropdown)
Start Port: 51820
End Port: 51820
Traffic Type: UDP
Inbound Filter: Allow All
Schedule: Always
```

**Save:** Click "Save Settings"

---

### Google WiFi / Nest WiFi

**Note:** Google WiFi doesn't support traditional port forwarding via web interface.

**Using Google Home App:**
1. Open Google Home app
2. Tap WiFi → Settings → Advanced Networking
3. Tap "Port forwarding" (if available)
4. Add rule:
   - **Internal IP:** 192.168.8.250
   - **External Port:** 51820
   - **Internal Port:** 51820
   - **Protocol:** UDP

**Limitation:** Some Google WiFi models don't support custom port forwarding. Consider:
- Using Tailscale instead (no port forwarding needed)
- Upgrading to Nest WiFi Pro
- Using a different router

---

### UniFi (Ubiquiti) Routers

**Path:** Settings → Routing & Firewall → Port Forwarding

**Configuration:**
1. Click "Create New Port Forward Rule"
2. Fill in:
   ```
   Name: WireGuard VPN
   From: Anywhere
   Port: 51820
   Forward IP: 192.168.8.250
   Forward Port: 51820
   Protocol: UDP
   Enable: Yes
   ```
3. Click "Apply Changes"

**Advanced:** You can create a WAN Firewall Rule to log VPN connections

---

### pfSense / OPNsense

**Path:** Firewall → NAT → Port Forward

**Configuration:**
1. Click "Add" (up arrow)
2. Fill in:
   ```
   Interface: WAN
   Protocol: UDP
   Destination: WAN address
   Destination Port Range: 51820 to 51820
   Redirect Target IP: 192.168.8.250
   Redirect Target Port: 51820
   Description: WireGuard VPN
   NAT Reflection: Enable
   ```
3. Click "Save"
4. Click "Apply Changes"

**Firewall Rule:** A corresponding firewall rule is auto-created. Check: Firewall → Rules → WAN

---

### MikroTik Routers

**Via WebFig:**

**Path:** IP → Firewall → NAT

**Configuration:**
1. Click "Add New"
2. General tab:
   ```
   Chain: dstnat
   Protocol: udp
   Dst. Port: 51820
   In. Interface: (your WAN interface)
   ```
3. Action tab:
   ```
   Action: dst-nat
   To Addresses: 192.168.8.250
   To Ports: 51820
   ```
4. Click "Apply" → "OK"

**Via Terminal:**
```
/ip firewall nat
add action=dst-nat chain=dstnat comment="WireGuard VPN" dst-port=51820 \
    in-interface=ether1 protocol=udp to-addresses=192.168.8.250 to-ports=51820
```

---

## 🔒 Security Best Practices

### Do's ✅

**Static IP for Pi:**
```
Why: Prevents port forward breaking if Pi's IP changes
How: Router → DHCP Reservation → MAC: XX:XX:XX:XX:XX:XX → IP: 192.168.8.250
```

**Single Port Only:**
```
Only forward: 51820/UDP
Don't forward: 22 (SSH), 80 (HTTP), 443 (HTTPS), 5000 (WireGuard-UI)
```

**Test Externally:**
```
From outside your network:
- Mobile data (not home WiFi)
- Friend's network
- Use: https://www.yougetsignal.com/tools/open-ports/
```

**Monitor Logs:**
```
Check router logs for:
- Failed connection attempts
- Unusual traffic patterns
- Unknown source IPs
```

### Don'ts ❌

**Don't Forward These Ports:**
```
❌ 22 (SSH) - Use VPN to access SSH instead
❌ 80/443 (HTTP/HTTPS) - Keep admin panels internal
❌ 5000 (WireGuard-UI) - LAN only
❌ 3389 (RDP) - Severe security risk
❌ 445 (SMB) - Severe security risk
```

**Don't Use DMZ:**
```
❌ DMZ exposes ALL ports - extremely dangerous
✅ Use specific port forwarding only
```

**Don't Disable Firewall:**
```
❌ "Exposed Host" or "DMZ Mode"
✅ Keep firewall enabled, forward specific ports
```

---

## 🌍 Dynamic DNS (DDNS) Setup

If your ISP changes your public IP regularly, use DDNS:

### Popular DDNS Services (Free)

**No-IP:**
- Website: https://www.noip.com
- Free: 3 hostnames
- Example: `myhome.ddns.net`

**DuckDNS:**
- Website: https://www.duckdns.org
- Free: Unlimited
- Example: `myhome.duckdns.org`

**Dynu:**
- Website: https://www.dynu.com
- Free: 4 hostnames
- Example: `myhome.dynu.net`

### Router DDNS Setup

Most routers have built-in DDNS:

**Path:** Advanced → DDNS / Dynamic DNS

**Configuration:**
```
Service Provider: (select from dropdown)
Hostname: myhome.duckdns.org
Username: (your DDNS account)
Password: (your DDNS password/token)
Enable: Yes
```

**Save:** Router will update DDNS automatically when IP changes

### Verify DDNS Working

1. Check your current public IP:
   ```
   curl ifconfig.me
   ```

2. Check DDNS resolves to same IP:
   ```
   nslookup myhome.duckdns.org
   ```

3. IPs should match!

---

## 🧪 Testing Your Configuration

### Step 1: Internal Test

**From a device on your network:**
```bash
# Test if Pi is listening
nc -zvu 192.168.8.250 51820

# Expected: "succeeded!"
```

### Step 2: External Port Test

**From outside your network (mobile data):**

Use online port checker:
- https://www.yougetsignal.com/tools/open-ports/
- Enter: `51820`
- Click: "Check"
- Expected: "Open" or "Accessible"

**Or use nmap:**
```bash
nmap -sU -p 51820 your-public-ip
```

### Step 3: VPN Connection Test

**From outside your network:**
1. Import WireGuard config on phone
2. Connect to VPN
3. Should connect successfully
4. Check Pi-hole shows your VPN IP (10.6.0.x)

**If it works:** ✅ Configuration successful!

### Troubleshooting Failed Tests

**Port shows "Closed":**
- Check port forwarding rule is enabled
- Verify internal IP is correct
- Ensure protocol is UDP (not TCP)
- Restart router
- Check Pi firewall (ufw status)

**VPN connects but no internet:**
- Check WG_PEER_DNS in .env.vpn
- Verify Pi-hole is running
- Check allowed IPs in peer config

**Can connect from LAN but not internet:**
- Port forwarding not working
- ISP may block port 51820 (try changing port)
- Check router public IP vs actual public IP (CGNAT issue)

---

## 🔧 Advanced: CGNAT Workaround

### What is CGNAT?

**Carrier-Grade NAT** - Your ISP shares one public IP among multiple customers. You can't port forward!

**Check if you have CGNAT:**
```bash
# Your router's public IP
curl ifconfig.me

# Compare to what websites see
# If different → you have CGNAT
```

### Solutions for CGNAT

**Option 1: Request Public IP from ISP**
- Call ISP support
- Request "dedicated public IP"
- May cost $5-10/month
- Not always available

**Option 2: Use Tailscale (Recommended)**
- No port forwarding needed
- Works through any NAT
- See: `stacks/remote-access/README.md`

**Option 3: VPS Tunnel**
- Rent cheap VPS ($5/month)
- Forward port from VPS to home
- Complex setup, not covered here

**Option 4: IPv6**
- If your ISP provides IPv6
- Usually no NAT on IPv6
- Configure WireGuard for IPv6

---

## 📱 Router Mobile Apps

Many routers have mobile apps for easy configuration:

| Router | App Name | Platform |
|--------|----------|----------|
| TP-Link | Tether | iOS/Android |
| ASUS | ASUS Router | iOS/Android |
| Netgear | Nighthawk | iOS/Android |
| Linksys | Linksys App | iOS/Android |
| Google WiFi | Google Home | iOS/Android |
| UniFi | UniFi Network | iOS/Android |

---

## 🆘 Common Issues

### "Can't access router admin panel"

**Default IPs to try:**
- 192.168.1.1
- 192.168.0.1
- 192.168.2.1
- 10.0.0.1

**Find router IP:**
```bash
# Linux/Mac
ip route | grep default

# Windows
ipconfig | findstr "Gateway"
```

**Reset admin password:**
- Look for "Forgot Password" link
- Or factory reset router (hold reset button 10+ seconds)

### "Can't find Port Forwarding option"

**Try these menu names:**
- Virtual Server
- NAT Forwarding
- Applications & Gaming
- Firewall Settings
- Advanced Settings

**Still can't find:**
- Search router manual: "[model number] port forwarding"
- Call ISP support if it's ISP-provided router
- Consider buying your own router

### "Port forwarding not working"

**Checklist:**
1. ✅ Pi has static IP?
2. ✅ Protocol is UDP (not TCP)?
3. ✅ WireGuard container running?
4. ✅ Router rule enabled/active?
5. ✅ Tested from external network?
6. ✅ No CGNAT?
7. ✅ ISP doesn't block port 51820?

**Try:**
- Use different port (e.g., 51821, 51822)
- Update .env.vpn: `WG_PORT=51821`
- Update router forward to new port
- Restart WireGuard container

---

## 📚 Additional Resources

**Router Specific Guides:**
- https://portforward.com (guides for 1000+ routers)
- Search: "[your router model] port forwarding tutorial"

**Video Tutorials:**
- YouTube: "port forwarding [router model]"
- YouTube: "WireGuard port forwarding"

**Community Support:**
- r/HomeNetworking (Reddit)
- r/WireGuard (Reddit)
- Your router manufacturer's forums

---

## ✅ Configuration Complete Checklist

- [ ] Router admin panel accessible
- [ ] Static DHCP reservation for Pi (192.168.8.250)
- [ ] Port forward rule created (51820/UDP → 192.168.8.250:51820)
- [ ] Port forward rule enabled/active
- [ ] Router settings saved
- [ ] DDNS configured (if needed)
- [ ] External port test successful
- [ ] VPN connection from outside successful
- [ ] Pi-hole shows VPN client traffic
- [ ] Security review completed (only 51820/UDP exposed)

**If all checked:** 🎉 Your VPN Edition is fully operational!

---

*Last updated: 2025-11-18*
*Version: 1.0*
