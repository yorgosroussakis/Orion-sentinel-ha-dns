# VPN Edition: End User Access Guide

This guide explains how to connect to your home network using the VPN Edition from anywhere in the world.

## 📱 For Non-Technical Users

### What You'll Get

When connected to the VPN:
- ✅ Access your home network from anywhere
- ✅ Stream from your media server (Jellyfin, Plex, etc.)
- ✅ Access your NAS files
- ✅ Ad-blocking everywhere (Pi-hole)
- ✅ Secure encrypted connection
- ✅ Works on any WiFi or cellular network

### Prerequisites

**You need:**
1. A WireGuard configuration (QR code or .conf file from your admin)
2. The WireGuard app on your device
3. Internet connection (WiFi or cellular)

**That's it!** No technical knowledge required.

---

## 📲 Setup Instructions by Device

### iOS (iPhone/iPad)

**Step 1: Install WireGuard**
1. Open App Store
2. Search for "WireGuard"
3. Install the official WireGuard app (by WireGuard Development Team)

**Step 2: Add Your VPN Profile**

**Option A: Using QR Code (Easiest)**
1. Open WireGuard app
2. Tap the **+** button
3. Select **"Create from QR code"**
4. Point camera at the QR code your admin sent you
5. Give it a name (e.g., "Home VPN")
6. Tap **"Save"**

**Option B: Using Configuration File**
1. Your admin sent you a `.conf` file via email/message
2. Tap the file on your iPhone
3. Choose **"Share"** → **"WireGuard"**
4. Tap **"Save"**

**Step 3: Connect**
1. Open WireGuard app
2. Toggle the switch next to "Home VPN" to **ON**
3. Approve the VPN connection if prompted
4. You'll see "Active" and a timer

**You're connected!** 🎉

---

### Android

**Step 1: Install WireGuard**
1. Open Google Play Store
2. Search for "WireGuard"
3. Install the official WireGuard app (by WireGuard Development Team)

**Step 2: Add Your VPN Profile**

**Option A: Using QR Code (Easiest)**
1. Open WireGuard app
2. Tap the **+** button (bottom right)
3. Select **"Scan from QR code"**
4. Point camera at the QR code your admin sent you
5. Give it a name (e.g., "Home VPN")
6. Tap **"Create Tunnel"**

**Option B: Using Configuration File**
1. Save the `.conf` file your admin sent you
2. Open WireGuard app
3. Tap **+** → **"Import from file or archive"**
4. Select the `.conf` file
5. Tap **"Create Tunnel"**

**Step 3: Connect**
1. Open WireGuard app
2. Tap the toggle next to "Home VPN"
3. Approve the VPN connection if prompted
4. You'll see a key icon in your status bar

**You're connected!** 🎉

---

### Windows

**Step 1: Install WireGuard**
1. Visit [www.wireguard.com/install](https://www.wireguard.com/install/)
2. Download **"Windows Installer"**
3. Run the installer
4. Click through the installation

**Step 2: Import Configuration**
1. Your admin sent you a `.conf` file
2. Save it somewhere (e.g., Desktop)
3. Open WireGuard app
4. Click **"Import tunnel(s) from file"**
5. Select your `.conf` file
6. Click **"Open"**

**Step 3: Connect**
1. Select "Home VPN" from the list
2. Click **"Activate"**
3. Status changes to "Active"

**You're connected!** 🎉

---

### macOS (Mac)

**Step 1: Install WireGuard**
1. Visit [www.wireguard.com/install](https://www.wireguard.com/install/)
2. Download **"macOS App Store"** link
3. Install from App Store

**Step 2: Import Configuration**
1. Your admin sent you a `.conf` file
2. Double-click the `.conf` file
   - OR: Open WireGuard app → File → Import Tunnel(s) from File
3. Click **"Allow"** when macOS asks permission

**Step 3: Connect**
1. Click the WireGuard icon in menu bar
2. Select your tunnel name
3. Click **"Activate"**

**You're connected!** 🎉

---

### Linux

**Step 1: Install WireGuard**

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install wireguard
```

**Fedora:**
```bash
sudo dnf install wireguard-tools
```

**Arch Linux:**
```bash
sudo pacman -S wireguard-tools
```

**Step 2: Import Configuration**
1. Save the `.conf` file as `/etc/wireguard/home.conf`:
   ```bash
   sudo cp ~/Downloads/home.conf /etc/wireguard/home.conf
   sudo chmod 600 /etc/wireguard/home.conf
   ```

**Step 3: Connect**
```bash
# Start VPN
sudo wg-quick up home

# Stop VPN
sudo wg-quick down home

# Auto-start on boot (optional)
sudo systemctl enable wg-quick@home
```

**You're connected!** 🎉

---

## 🧪 Testing Your Connection

### 1. Check You're Connected

**On Phone/Tablet:**
- WireGuard app shows "Active"
- Timer is running
- VPN icon in status bar (Android)

**On Computer:**
- WireGuard shows "Active"
- Data transfer counter is increasing

### 2. Test Home Network Access

**Try accessing:**
- **Pi-hole Admin:** http://192.168.8.251/admin
- **Media Server (example):** http://192.168.8.100:8096
- **NAS (example):** http://192.168.8.50

**If these work, you're connected!** ✅

### 3. Test Ad-Blocking

1. Visit an ad-heavy website
2. Ads should be blocked
3. Check Pi-hole dashboard - you should see your VPN IP (10.6.0.x) making queries

---

## 🔧 Troubleshooting

### "Unable to Connect"

**Check:**
1. ✅ Is your internet working? (Try browsing without VPN)
2. ✅ Is the VPN server running? (Ask your admin)
3. ✅ Did you use the correct QR code/config file?

**Try:**
- Turn VPN off and on again
- Restart the WireGuard app
- Restart your device
- Contact your admin for help

### "Connected but Can't Access Services"

**Check:**
1. ✅ Are you using the right IP addresses?
2. ✅ Is the service running at home? (Ask admin)
3. ✅ Did you type `http://` not `https://`?

**Try:**
- Ask admin for correct IP addresses
- Ping test: `ping 192.168.8.251` (Windows/Mac/Linux)

### "Slow Connection"

This is normal! Your traffic goes through your home internet connection.

**Tips:**
- Use **Split Tunnel mode** (ask admin) - only home network traffic goes through VPN
- Close other apps using internet
- Check your home internet speed (ask admin)
- If streaming, use lower quality settings

### "VPN Disconnects Randomly"

**On Mobile:**
- Check battery optimization settings
- Allow WireGuard to run in background
- Disable "Optimize battery usage" for WireGuard

**On Computer:**
- Check if your laptop went to sleep
- Disable sleep while on VPN
- Check your internet connection stability

---

## 📊 What Traffic Goes Through VPN?

This depends on your configuration. Ask your admin which mode you have:

### Split Tunnel Mode (Recommended)
**Through VPN:**
- ✅ Home network access (192.168.8.x)
- ✅ DNS queries (ad-blocking)

**Direct (not through VPN):**
- ✅ Regular internet browsing
- ✅ Streaming services (Netflix, YouTube, etc.)

**Advantage:** Faster internet, less load on home connection

### Full Tunnel Mode
**Through VPN:**
- ✅ Everything!
- ✅ All internet traffic goes through home

**Advantage:** Maximum privacy, all traffic encrypted

**Disadvantage:** Slower, uses home internet bandwidth

---

## 🔒 Security & Privacy

### Is This Secure?

**Yes!** WireGuard uses:
- Military-grade encryption (ChaCha20)
- Perfect forward secrecy
- Modern cryptography

Your traffic is encrypted from your device to your home network.

### Best Practices

**DO:**
- ✅ Keep the WireGuard app updated
- ✅ Don't share your QR code/config file
- ✅ Disconnect when not needed (saves battery)
- ✅ Tell admin if you lose your device

**DON'T:**
- ❌ Screenshot and post your QR code
- ❌ Email your config file unencrypted
- ❌ Share your VPN access with others
- ❌ Leave VPN on 24/7 unnecessarily (battery drain)

---

## 💡 Tips & Tricks

### Battery Life (Mobile)

**To save battery:**
1. Only connect when you need home access
2. Use split tunnel mode
3. Disconnect when done
4. Consider on-demand connection (ask admin)

### Quick Toggle (Mobile)

**iOS:**
- Add WireGuard widget to home screen for quick on/off

**Android:**
- Add Quick Settings tile for one-tap toggle

### Streaming Media

**For best experience:**
1. Ensure good home upload speed (ask admin)
2. Use split tunnel if available
3. Lower quality if buffering occurs
4. Connect via WiFi when possible (not cellular)

### Working From Hotel/Coffee Shop

**VPN is perfect for:**
- Accessing work files on home NAS
- Secure browsing on public WiFi
- Accessing Pi-hole ad-blocking anywhere

**Remember:**
- Turn VPN on BEFORE connecting to public WiFi
- Your traffic is encrypted - safe on any network

---

## 🆘 Getting Help

### Contact Your Admin

**Information to provide:**
1. Device type (iPhone, Android, Windows, etc.)
2. What you tried
3. Error messages (screenshot if possible)
4. Can you browse internet without VPN?
5. When did it last work?

### Check Admin's Pi-hole

Your admin can see:
- If you're connected
- Your VPN IP address
- DNS queries you're making

This helps them troubleshoot!

---

## 📝 Quick Reference

### Connection Status

| Indicator | Meaning |
|-----------|---------|
| Active / Connected | ✅ VPN working |
| Timer running | ✅ VPN active |
| Data transfer | ✅ Traffic flowing |
| Inactive / Disconnected | ❌ VPN off |
| Connecting... | ⏳ Establishing connection |
| Error | ⚠️ Problem connecting |

### Common IP Addresses

Ask your admin for your specific IPs:

| Service | Typical IP | Port |
|---------|-----------|------|
| Pi-hole | 192.168.8.251 | 80 |
| Jellyfin | 192.168.8.100 | 8096 |
| Plex | 192.168.8.100 | 32400 |
| NAS | 192.168.8.50 | 445, 5000 |

### Support Resources

- **WireGuard Official:** [www.wireguard.com](https://www.wireguard.com)
- **iOS App Support:** App Store → WireGuard → Support
- **Android App Support:** Play Store → WireGuard → Support

---

## 🎉 Congratulations!

You now have secure remote access to your home network from anywhere in the world!

**Enjoy:**
- 📺 Streaming your media collection
- 📁 Accessing your files
- 🛡️ Ad-blocking everywhere
- 🔒 Encrypted, secure connection

**Questions?** Contact your network administrator.

---

*Last updated: 2025-11-18*
*Version: 1.0*
