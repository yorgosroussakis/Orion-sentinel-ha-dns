# Multi-Node HA Deployment Checklist

Quick reference guide for deploying the DNS stack across two Raspberry Pi nodes.

## Pre-Deployment Checklist

### Hardware
- [ ] Two Raspberry Pi 4/5 with 4GB+ RAM
- [ ] Both Pis have Ethernet connectivity (not Wi-Fi)
- [ ] Both Pis are powered and accessible
- [ ] Network switch supports multicast (or plan to use unicast VRRP)

### Network Planning
- [ ] Decided on IP addresses for both physical Pis
  - Pi #1 (Primary): ____________ (e.g., 192.168.8.11)
  - Pi #2 (Secondary): ____________ (e.g., 192.168.8.12)
- [ ] Decided on VIP address: ____________ (e.g., 192.168.8.255)
- [ ] Verified IP addresses are not in DHCP range
- [ ] Verified no conflicts with existing devices
- [ ] Gateway address: ____________ (e.g., 192.168.8.1)
- [ ] Subnet: ____________ (e.g., 192.168.8.0/24)

### Software Requirements
- [ ] Both Pis running Raspberry Pi OS (64-bit)
- [ ] Docker installed on both Pis
- [ ] Docker Compose installed on both Pis
- [ ] Git installed on both Pis
- [ ] SSH access between Pis configured

## Architecture Decision
Select one:
- [ ] **Option A:** Simplified (1 Pi-hole + 1 Unbound per node) - RECOMMENDED
- [ ] **Option B:** Full Redundancy (2 Pi-hole + 2 Unbound per node) - Advanced

## Deployment Steps

### Step 1: Prepare Pi #1 (Primary)
- [ ] Set static IP on eth0: ____________
- [ ] Update system: `sudo apt update && sudo apt upgrade -y`
- [ ] Install Docker: `curl -fsSL https://get.docker.com | sh`
- [ ] Install Docker Compose: `sudo apt install docker-compose-plugin`
- [ ] Add user to docker group: `sudo usermod -aG docker $USER`
- [ ] Reboot: `sudo reboot`
- [ ] Clone repository to `/opt/rpi-ha-dns-stack`
- [ ] Copy `.env.example` to `.env`
- [ ] Edit `.env` with primary node settings

### Step 2: Prepare Pi #2 (Secondary)
- [ ] Set static IP on eth0: ____________
- [ ] Update system: `sudo apt update && sudo apt upgrade -y`
- [ ] Install Docker: `curl -fsSL https://get.docker.com | sh`
- [ ] Install Docker Compose: `sudo apt install docker-compose-plugin`
- [ ] Add user to docker group: `sudo usermod -aG docker $USER`
- [ ] Reboot: `sudo reboot`
- [ ] Clone repository to `/opt/rpi-ha-dns-stack`
- [ ] Copy `.env.example` to `.env`
- [ ] Edit `.env` with secondary node settings

### Step 3: Configure SSH Between Nodes
- [ ] On Pi #1: Generate SSH key: `ssh-keygen -t ed25519`
- [ ] On Pi #1: Copy key to Pi #2: `ssh-copy-id pi@<Pi2_IP>`
- [ ] Test SSH from Pi #1 to Pi #2: `ssh pi@<Pi2_IP> "echo OK"`
- [ ] On Pi #2: Generate SSH key: `ssh-keygen -t ed25519`
- [ ] On Pi #2: Copy key to Pi #1: `ssh-copy-id pi@<Pi1_IP>`
- [ ] Test SSH from Pi #2 to Pi #1: `ssh pi@<Pi1_IP> "echo OK"`

### Step 4: Create Docker Networks
- [ ] On Pi #1: Create macvlan network
  ```bash
  sudo docker network create -d macvlan \
    --subnet=192.168.8.0/24 --gateway=192.168.8.1 \
    -o parent=eth0 dns_net
  ```
- [ ] On Pi #2: Create macvlan network (same command)
- [ ] Verify on both: `docker network ls | grep dns_net`

### Step 5: Configure Keepalived
- [ ] On Pi #1: Edit `stacks/dns/keepalived/keepalived.conf`
  - [ ] Set `state MASTER`
  - [ ] Set `priority 100`
  - [ ] Set `unicast_src_ip` to Pi #1 IP
  - [ ] Set `unicast_peer` to Pi #2 IP
  - [ ] Set `virtual_ipaddress` to VIP
- [ ] On Pi #2: Edit `stacks/dns/keepalived/keepalived.conf`
  - [ ] Set `state BACKUP`
  - [ ] Set `priority 90`
  - [ ] Set `unicast_src_ip` to Pi #2 IP
  - [ ] Set `unicast_peer` to Pi #1 IP
  - [ ] Set `virtual_ipaddress` to VIP
- [ ] Create health check script on both nodes

### Step 6: Deploy DNS Services
- [ ] On Pi #1: Deploy primary services
  ```bash
  cd /opt/rpi-ha-dns-stack/stacks/dns
  docker compose up -d pihole_primary unbound_primary keepalived
  ```
- [ ] Wait 30 seconds for initialization
- [ ] Check status: `docker compose ps`
- [ ] Check logs: `docker logs pihole_primary`, `docker logs keepalived`
- [ ] On Pi #2: Deploy secondary services
  ```bash
  cd /opt/rpi-ha-dns-stack/stacks/dns
  docker compose up -d pihole_secondary unbound_secondary keepalived
  ```
- [ ] Wait 30 seconds for initialization
- [ ] Check status: `docker compose ps`
- [ ] Check logs: `docker logs pihole_secondary`, `docker logs keepalived`

### Step 7: Configure Synchronization
- [ ] On Pi #1: Install Gravity Sync
  ```bash
  curl -sSL https://raw.githubusercontent.com/vmstan/gravity-sync/master/gs-install.sh | bash
  ```
- [ ] Configure Gravity Sync:
  - [ ] Remote host: <Pi2_IP>
  - [ ] Remote user: pi
  - [ ] SSH key path: /home/pi/.ssh/id_ed25519
- [ ] Test sync: `sudo gravity-sync push`
- [ ] Enable automated sync: `sudo gravity-sync auto`

## Verification Checklist

### Basic Connectivity
- [ ] From another device, ping VIP: `ping 192.168.8.255`
- [ ] Ping Pi-hole primary: `ping 192.168.8.251`
- [ ] Ping Pi-hole secondary: `ping 192.168.8.252`

### VIP Assignment
- [ ] On Pi #1: Check VIP present: `ip addr show eth0 | grep <VIP>`
  - Expected: VIP should be assigned to eth0
- [ ] On Pi #2: Check VIP absent: `ip addr show eth0 | grep <VIP>`
  - Expected: VIP should NOT be assigned (unless Pi #1 is down)

### Keepalived Status
- [ ] On Pi #1: Check logs: `docker logs keepalived | tail -20`
  - Expected: "Entering MASTER STATE"
- [ ] On Pi #2: Check logs: `docker logs keepalived | tail -20`
  - Expected: "Entering BACKUP STATE"

### DNS Resolution
From another device on your network:
- [ ] Test DNS via VIP: `dig google.com @192.168.8.255`
  - Expected: Successful response
- [ ] Test DNS via Primary: `dig google.com @192.168.8.251`
  - Expected: Successful response
- [ ] Test DNS via Secondary: `dig google.com @192.168.8.252`
  - Expected: Successful response
- [ ] Test blocking: `dig ads.google.com @192.168.8.255`
  - Expected: Blocked (0.0.0.0 or blocked response)

### Pi-hole Web Interface
- [ ] Access primary: http://192.168.8.251/admin
  - [ ] Login with password from `.env`
  - [ ] Check dashboard loads
  - [ ] Check queries are being logged
- [ ] Access secondary: http://192.168.8.252/admin
  - [ ] Login with password from `.env`
  - [ ] Check dashboard loads
  - [ ] Check queries are being logged

### Failover Test
- [ ] **Planned Failover Test:**
  1. [ ] Note current VIP holder (should be Pi #1)
  2. [ ] On Pi #1: `docker stop keepalived`
  3. [ ] Wait 10 seconds
  4. [ ] Check VIP on Pi #2: `ssh pi@<Pi2_IP> "ip addr show eth0 | grep <VIP>"`
     - Expected: VIP now on Pi #2
  5. [ ] Test DNS still works: `dig google.com @192.168.8.255`
     - Expected: Still resolving
  6. [ ] Check Pi #2 keepalived logs: `ssh pi@<Pi2_IP> "docker logs keepalived | tail -10"`
     - Expected: "Entering MASTER STATE"
  7. [ ] Restart keepalived on Pi #1: `docker start keepalived`
  8. [ ] Wait 10 seconds
  9. [ ] Check VIP returned to Pi #1: `ip addr show eth0 | grep <VIP>`
     - Expected: VIP back on Pi #1
  10. [ ] Verify no DNS interruption during failover

- [ ] **Hardware Failover Test (Optional but Recommended):**
  1. [ ] Note current VIP holder (should be Pi #1)
  2. [ ] Power off Pi #1 completely
  3. [ ] Wait 15 seconds
  4. [ ] Test DNS still works: `dig google.com @192.168.8.255`
     - Expected: DNS continues to work via Pi #2
  5. [ ] Power on Pi #1
  6. [ ] Wait for boot and services to start (~2 minutes)
  7. [ ] Verify VIP returns to Pi #1
  8. [ ] Verify both nodes are healthy

### Synchronization Test
- [ ] On Pi #1: Add a custom DNS entry in Pi-hole web interface
  - Example: test.local → 192.168.8.100
- [ ] Wait for sync (or run manually: `sudo gravity-sync push`)
- [ ] On Pi #2: Check if entry appears in Pi-hole web interface
  - [ ] Entry should be present
- [ ] Test resolution: `dig test.local @192.168.8.252`
  - Expected: Returns 192.168.8.100

## Post-Deployment Configuration

### Router/DHCP Configuration
- [ ] Set DNS servers in router DHCP settings:
  - Primary DNS: 192.168.8.255 (VIP)
  - Secondary DNS: 192.168.8.251 or 192.168.8.252
- [ ] Save and reboot router
- [ ] Renew DHCP leases on client devices
- [ ] Verify clients are using the new DNS servers

### Monitoring Setup (Optional)
- [ ] Deploy Grafana/Prometheus on Pi #1 (or both)
- [ ] Configure keepalived state change notifications
- [ ] Set up alerting for failover events
- [ ] Configure backup jobs

## Troubleshooting Guide

### Issue: VIP not showing on any node
**Check:**
```bash
# On both nodes:
docker logs keepalived
tcpdump -i eth0 -nn vrrp
iptables -L -n | grep 112
```
**Fix:** Ensure VRRP packets not blocked, use unicast if needed

### Issue: Both nodes claim MASTER (split brain)
**Check:**
```bash
# Test connectivity between nodes
ping <peer_IP>
# Check for different virtual_router_id
grep virtual_router_id /opt/rpi-ha-dns-stack/stacks/dns/keepalived/keepalived.conf
```
**Fix:** Ensure network connectivity, verify same virtual_router_id

### Issue: Sync not working
**Check:**
```bash
# Test SSH
ssh pi@<peer_IP>
# Check Gravity Sync logs
sudo gravity-sync log
# Run manual sync
sudo gravity-sync push -f
```

### Issue: DNS not resolving
**Check:**
```bash
# Test individual components
docker exec pihole_primary dig @127.0.0.1 google.com
docker exec unbound_primary drill @127.0.0.1 -p 5335 google.com
# Check container status
docker ps
docker logs pihole_primary
```

## Maintenance Tasks

### Regular Tasks
- [ ] **Weekly:** Review keepalived logs for unexpected failovers
- [ ] **Weekly:** Verify sync is working (check both Pi-hole interfaces)
- [ ] **Monthly:** Test failover procedure
- [ ] **Monthly:** Update Docker images: `docker compose pull && docker compose up -d`
- [ ] **Quarterly:** Full system backup
- [ ] **Quarterly:** Review and update blocklists

### Updates
```bash
# On each node:
cd /opt/rpi-ha-dns-stack
git pull
docker compose pull
docker compose up -d
```

## Emergency Procedures

### If Pi #1 (Primary) Fails
1. Pi #2 will automatically take over within 10 seconds
2. DNS continues to work via VIP on Pi #2
3. Fix Pi #1 at your convenience
4. When Pi #1 returns, VIP will failback

### If Pi #2 (Secondary) Fails
1. DNS continues to work via Pi #1 (no failover needed)
2. Fix Pi #2 at your convenience
3. When Pi #2 returns, run sync: `sudo gravity-sync push`

### If Both Pis Fail
1. Clients will fall back to DNS servers configured as "secondary" in DHCP
2. Or manually set clients to use 8.8.8.8 temporarily
3. Fix and restart nodes
4. Verify sync after recovery

## Success Criteria

Your multi-node HA deployment is successful when:

- ✅ Both Pis are running and healthy
- ✅ VIP (192.168.8.255) is assigned to Pi #1 (MASTER)
- ✅ DNS queries via VIP are resolved successfully
- ✅ Keepalived shows MASTER on Pi #1, BACKUP on Pi #2
- ✅ Stopping keepalived on Pi #1 transfers VIP to Pi #2 within 10 seconds
- ✅ DNS continues to work during and after failover
- ✅ VIP returns to Pi #1 when keepalived restarts
- ✅ Configuration sync works (changes on primary appear on secondary)
- ✅ Both Pi-hole web interfaces are accessible and show statistics

## Notes

- **Important:** Due to macvlan, you cannot access container IPs directly from the Raspberry Pi itself. Always test from another device on the network.
- **Sync Direction:** Always sync from Pi #1 (primary) to Pi #2 (secondary)
- **Failover Time:** Expected 5-10 seconds for automatic failover
- **Failback:** Can be configured as automatic (default) or manual

---

**Checklist Version:** 1.0  
**For Repository:** rpi-ha-dns-stack  
**Multi-Node HA Guide:** See MULTI_NODE_HA_DESIGN.md for detailed architecture
