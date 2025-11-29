# NextDNS Fallback Configuration

**Orion Sentinel DNS HA - NextDNS Fallback for Resilient DNS Resolution**

This guide explains how to configure NextDNS as a fallback upstream resolver for your HA DNS stack.

---

## Overview

The NextDNS fallback feature provides an additional layer of DNS resilience. When enabled, Pi-hole will automatically fall back to NextDNS if the local Unbound resolver becomes unavailable.

### DNS Resolution Chain

```
┌──────────────┐     ┌─────────────────┐     ┌─────────────────────┐     ┌───────────────────────┐
│   Clients    │ ──► │   VIP (Pi-hole) │ ──► │ Unbound (primary)   │ ──► │ NextDNS (fallback)    │
│              │     │                 │     │ Recursive resolver  │     │ If Unbound fails      │
└──────────────┘     └─────────────────┘     └─────────────────────┘     └───────────────────────┘
```

**Normal operation:**
- Clients query the VIP (floating between Pi #1 and Pi #2)
- Pi-hole forwards queries to local Unbound
- Unbound performs recursive DNS resolution with DNSSEC validation

**Fallback behavior (when NextDNS is enabled):**
- If Unbound fails, times out, or returns errors
- Pi-hole automatically uses NextDNS as secondary upstream
- DNS resolution continues without client-visible interruption

---

## Architecture

### Two-Pi HA Setup with NextDNS Fallback

```
┌─────────────────────────────────────┐  ┌─────────────────────────────────────┐
│  Pi #1 (MASTER)                     │  │  Pi #2 (BACKUP)                     │
│  192.168.8.11                       │  │  192.168.8.12                       │
│                                     │  │                                     │
│  ┌────────────────────────────────┐ │  │  ┌────────────────────────────────┐ │
│  │     Keepalived (Priority 100)  │ │  │  │     Keepalived (Priority 90)   │ │
│  │     Role: MASTER               │◄─┼──┼─►│     Role: BACKUP               │ │
│  └────────────────────────────────┘ │  │  └────────────────────────────────┘ │
│                                     │  │                                     │
│  ┌───────────────────────────────┐  │  │  ┌───────────────────────────────┐  │
│  │  Pi-hole Primary              │  │  │  │  Pi-hole Secondary            │  │
│  │                               │  │  │  │                               │  │
│  │  Upstream 1: Unbound          │  │  │  │  Upstream 1: Unbound          │  │
│  │  Upstream 2: NextDNS (IPv4)   │  │  │  │  Upstream 2: NextDNS (IPv4)   │  │
│  │  Upstream 3: NextDNS (IPv6)   │  │  │  │  Upstream 3: NextDNS (IPv6)   │  │
│  └───────────────┬───────────────┘  │  │  └───────────────┬───────────────┘  │
│                  │                  │  │                  │                  │
│  ┌───────────────▼───────────────┐  │  │  ┌───────────────▼───────────────┐  │
│  │  Unbound Primary              │  │  │  │  Unbound Secondary            │  │
│  │  Recursive + DNSSEC           │  │  │  │  Recursive + DNSSEC           │  │
│  └───────────────────────────────┘  │  │  └───────────────────────────────┘  │
└──────────────────┬──────────────────┘  └──────────────────┬──────────────────┘
                   │                                        │
                   └────────────────┬───────────────────────┘
                                    │
                          ┌─────────▼─────────┐
                          │   VIP (Floating)  │
                          │  192.168.8.249    │
                          └─────────┬─────────┘
                                    │
                             ┌──────▼──────┐
                             │   Clients   │
                             └─────────────┘
```

**Key points:**
- Both Pis have identical DNS upstream configuration
- Keepalived manages the VIP that floats between nodes
- Clients always use the VIP - they never connect directly to Pi #1 or Pi #2
- NextDNS is only used as fallback when Unbound fails

---

## Configuration

### Environment Variables

Add these variables to your `.env` file:

```bash
#####################################
# NEXTDNS FALLBACK CONFIGURATION
#####################################
# NextDNS IPv4 endpoint (set this to enable fallback)
# Get your profile endpoints from: https://my.nextdns.io
# Example: 45.90.28.0 (for profile ID abc123, use 45.90.28.abc123)
NEXTDNS_DNS_IPV4=45.90.28.123

# NextDNS IPv6 endpoint (optional)
# Example: 2a07:a8c0::ab:cd12
NEXTDNS_DNS_IPV6=

# NextDNS DNS-over-HTTPS URL (optional, for DoH support)
# Example: https://dns.nextdns.io/abc123
NEXTDNS_DOH_URL=
```

### Getting Your NextDNS Endpoints

1. Create an account at [NextDNS](https://nextdns.io)
2. Go to [My NextDNS](https://my.nextdns.io)
3. Create or select a configuration profile
4. In the "Setup" tab, find your endpoints:
   - IPv4: `45.90.28.xxx` or `45.90.30.xxx`
   - IPv6: `2a07:a8c0::xxx:xxxx`
   - DoH: `https://dns.nextdns.io/xxxxxx`

---

## Deployment

### Enable NextDNS Fallback

1. **Edit your .env file:**
   ```bash
   nano .env
   ```

2. **Set the NextDNS IPv4 endpoint:**
   ```bash
   # Setting NEXTDNS_DNS_IPV4 enables the fallback
   NEXTDNS_DNS_IPV4=45.90.28.YOUR_PROFILE_ID
   # Optional: IPv6 endpoint
   NEXTDNS_DNS_IPV6=2a07:a8c0::YOUR:PROFILE
   ```

3. **Deploy/redeploy the stack:**
   ```bash
   cd stacks/dns
   docker compose --profile single-pi-ha up -d
   # Or for two-Pi HA:
   # Pi #1: docker compose --profile two-pi-ha-pi1 up -d
   # Pi #2: docker compose --profile two-pi-ha-pi2 up -d
   ```

### Disable NextDNS Fallback

To run in "Unbound only" mode:

```bash
# Leave NEXTDNS_DNS_IPV4 empty to disable fallback
NEXTDNS_DNS_IPV4=
NEXTDNS_DNS_IPV6=
```

Redeploy the stack after making changes.

---

## Verification

### Check Pi-hole Upstream Configuration

1. **Access Pi-hole admin UI:**
   - Via VIP: `http://192.168.8.249/admin`
   - Or direct: `http://192.168.8.11/admin` (Pi #1) / `http://192.168.8.12/admin` (Pi #2)

2. **Go to Settings → DNS:**
   - Verify Unbound is listed as primary upstream
   - Verify NextDNS is listed as secondary upstream (if enabled)

### Test Unbound is Being Used

Check that queries are going through Unbound:

```bash
# Check Unbound container logs
docker logs unbound_primary | tail -20

# Query a domain and check resolution
dig google.com @192.168.8.249

# Check Pi-hole query log
docker exec pihole_primary pihole -t
```

### Test NextDNS Fallback

To verify fallback works:

1. **Temporarily stop Unbound:**
   ```bash
   docker stop unbound_primary
   ```

2. **Make a DNS query:**
   ```bash
   dig example.com @192.168.8.249
   ```

3. **Check NextDNS logs:**
   - Go to [my.nextdns.io](https://my.nextdns.io) → Logs
   - You should see queries appearing

4. **Restart Unbound:**
   ```bash
   docker start unbound_primary
   ```

---

## Fallback Behavior Details

### How Pi-hole Handles Multiple Upstreams

Pi-hole uses all configured upstream DNS servers and implements intelligent failover:

1. **Primary query:** Sent to the first upstream (Unbound)
2. **Timeout/failure:** If no response within timeout, try next upstream (NextDNS)
3. **Response:** First successful response is returned to client

### Timeout Configuration

Pi-hole's default DNS timeout is usually sufficient. If you experience issues:

1. The Unbound timeout can be tuned in `stacks/dns/unbound/unbound.conf`
2. Pi-hole uses dnsmasq internally, which has reasonable defaults

### DNSSEC Considerations

- Unbound performs full DNSSEC validation
- NextDNS also supports DNSSEC validation
- Both upstreams provide secure DNS resolution

---

## Troubleshooting

### NextDNS Not Receiving Queries

**Check if NextDNS variables are set:**
```bash
grep NEXTDNS .env
```

**Verify Pi-hole configuration:**
```bash
docker exec pihole_primary cat /etc/pihole/setupVars.conf | grep PIHOLE_DNS
```

### Fallback Not Working

**Check Pi-hole logs:**
```bash
docker logs pihole_primary | grep -i dns
```

**Test direct connectivity to NextDNS:**
```bash
dig example.com @45.90.28.YOUR_PROFILE_ID
```

### Unbound Failing Frequently

If Unbound is failing often, investigate:

```bash
# Check Unbound logs
docker logs unbound_primary

# Check container health
docker inspect unbound_primary --format='{{.State.Health.Status}}'

# Check system resources
docker stats unbound_primary --no-stream
```

---

## Best Practices

1. **Test failover regularly:**
   - Monthly test of Unbound failure scenario
   - Verify NextDNS logs show queries during test

2. **Monitor NextDNS usage:**
   - Check NextDNS dashboard for unexpected query volume
   - High NextDNS traffic may indicate Unbound issues

3. **Keep Unbound as primary:**
   - Unbound provides full recursive resolution
   - Better privacy (queries don't leave your network)
   - DNSSEC validation at the source

4. **Use NextDNS features wisely:**
   - Configure NextDNS profile for your needs
   - Consider enabling analytics in NextDNS for visibility
   - Use NextDNS allowlist/blocklist for redundant filtering

---

## Related Documentation

- **[Two-Pi HA Installation](install-two-pi-ha.md)** - Complete HA setup guide
- **[Health & HA Guide](health-and-ha.md)** - Health monitoring and failover
- **[Troubleshooting](../TROUBLESHOOTING.md)** - Common issues and solutions

---

**Questions or Issues?**

- Check [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
- Visit the [GitHub repository](https://github.com/yorgosroussakis/Orion-sentinel-ha-dns)
