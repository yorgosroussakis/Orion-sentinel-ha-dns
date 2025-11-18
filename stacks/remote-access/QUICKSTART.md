# Quick Start - Remote Access

**Time to deploy:** 5-15 minutes depending on option chosen

## Step 1: Do you need remote access?

**No** → Your DNS stack is already complete! You're done. 🎉  
**Yes** → Continue to Step 2

## Step 2: Choose your solution

### For Non-Technical End Users → Tailscale

**Best if your users:**
- Want something that "just works"
- Can install an app
- Have a Google/Microsoft/GitHub account
- Need access to all your services

**Quick setup:**
```bash
# Get auth key from: https://login.tailscale.com/admin/settings/keys
echo "TAILSCALE_AUTH_KEY=tskey-auth-xxxxxxxxx" >> .env

# Deploy
docker compose -f stacks/remote-access/docker-compose.yml --profile tailscale up -d

# Approve users in: https://login.tailscale.com/admin/machines
```

**Tell users:**
"Install Tailscale app, sign in with Google. I'll approve you, then you can access everything!"

---

### For Web Services (Jellyfin, etc.) → Cloudflare Tunnel

**Best if:**
- Users should just "click a link"
- You only need HTTP/HTTPS access
- You want professional URLs
- You have a domain name ($10/year)

**Quick setup:**
```bash
# 1. Buy domain, point to Cloudflare (free)
# 2. Create tunnel: https://dash.cloudflare.com → Zero Trust → Access → Tunnels
# 3. Copy tunnel token

echo "CLOUDFLARE_TUNNEL_TOKEN=your-token" >> .env

# Deploy
docker compose -f stacks/remote-access/docker-compose.yml --profile cloudflare up -d
```

**Tell users:**
"Access at https://jellyfin.yourdomain.com"

---

### For Power Users → WireGuard

**Best if:**
- You're technical
- Users are technical
- You want full control
- You can manage config files

**Quick setup:**
See `stacks/vpn/README.md` for full WireGuard documentation.

---

## Step 3: Deploy Multiple (Optional)

Want both Tailscale AND Cloudflare?

```bash
# Deploy both
docker compose -f stacks/remote-access/docker-compose.yml \
  --profile tailscale \
  --profile cloudflare \
  up -d
```

Now you have:
- Tailscale for technical users who want full access
- Cloudflare for non-technical users who just want Jellyfin

---

## Step 4: Test

### Testing Tailscale

1. Install Tailscale on your phone
2. Sign in
3. Approve yourself in admin panel
4. Access: http://rpi-dns-stack:8096

### Testing Cloudflare

1. Open browser
2. Go to: https://jellyfin.yourdomain.com
3. Should load immediately

### Testing WireGuard

1. Create config in WireGuard-UI
2. Import on device
3. Connect
4. Access services

---

## Real-World Example

**Scenario:** You want to share Jellyfin with your parents who live far away.

### Option A: Tailscale (Easier)
```
You: "Download Tailscale from the app store"
Parents: "Okay, done"
You: "Sign in with your Google account"
Parents: "Done"
You: *approve them in admin panel*
You: "Now open http://rpi-dns-stack:8096 in your browser"
Parents: "It works! This is easy!"
```

### Option B: Cloudflare (Easiest!)
```
You: "Open https://movies.ourfamily.com in your browser"
Parents: "Wow, that's it? Amazing!"
```

### Option C: WireGuard (Don't do this to your parents!)
```
You: "I'm sending you a .conf file"
Parents: "What's that?"
You: "Download WireGuard app..."
Parents: "This is confusing..."
*30 minutes of troubleshooting later*
```

---

## Common Questions

**Q: Do I need port forwarding?**
- Tailscale: No
- Cloudflare: No
- WireGuard: Yes

**Q: Will this work with my Proton VPN router?**
- Tailscale: Yes, perfect!
- Cloudflare: Yes, perfect!
- WireGuard: Maybe, see `stacks/vpn/examples/router-vpn-bypass.md`

**Q: Can I use multiple options?**
Yes! Deploy all three and let users choose what works for them.

**Q: Is my DNS stack affected?**
No! Remote access is completely optional and separate.

**Q: What if I change my mind?**
Easy to add/remove anytime:
```bash
# Remove Tailscale
docker compose -f stacks/remote-access/docker-compose.yml --profile tailscale down

# Add it back later
docker compose -f stacks/remote-access/docker-compose.yml --profile tailscale up -d
```

---

## Recommendation

**Most users should use:**
1. **Tailscale** as the primary remote access solution
2. **Cloudflare Tunnel** for specific web services you want to share publicly

This combination gives you:
- ✅ Easy setup
- ✅ Happy users
- ✅ No port forwarding
- ✅ Works with any network setup
- ✅ Professional experience

**Total cost:** $0-10/year (domain for Cloudflare is optional)
**Total setup time:** 15 minutes
**User setup time:** 2 minutes (Tailscale) or 0 seconds (Cloudflare)

---

## Get Help

- **Tailscale**: [stacks/remote-access/README.md](stacks/remote-access/README.md)
- **Cloudflare**: [stacks/remote-access/README.md](stacks/remote-access/README.md)
- **WireGuard**: [stacks/vpn/README.md](stacks/vpn/README.md)
- **Compare Options**: [stacks/vpn/USER_FRIENDLY_ALTERNATIVES.md](stacks/vpn/USER_FRIENDLY_ALTERNATIVES.md)

---

## Bottom Line

**The DNS stack works perfectly without any remote access.**

But if you need it:
- **Easy for you:** Tailscale (5 min setup)
- **Easy for users:** Tailscale (2 min) or Cloudflare (0 min - just click link)
- **Happy everyone:** Deploy and forget it! 🎉
