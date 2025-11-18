# Wirehole Comparison and Learning

This document details what we learned from the wirehole project and how we adapted and improved upon it for our use case.

## Wirehole Overview

**Repository**: https://github.com/IAmStoxe/wirehole  
**Concept**: Combines WireGuard VPN with Pi-hole for ad-blocking via VPN

### Wirehole Architecture

```
Internet → Router → WireGuard Server → Pi-hole → Unbound → Internet
                                    ↓
                              VPN Clients
```

### Key Components in Wirehole
1. **WireGuard**: VPN server (linuxserver/wireguard)
2. **WireGuard-UI**: Web management interface
3. **Pi-hole**: DNS filtering and ad-blocking
4. **Unbound**: Recursive DNS resolver

### Wirehole Configuration
- Single docker-compose.yml file
- Simple environment-based configuration
- Private network (10.2.0.0/24)
- Basic port forwarding setup

## What We Learned

### 1. Service Integration Pattern

**Wirehole Approach**:
```yaml
services:
  wireguard:
    depends_on:
      - unbound
      - pihole
  wireguard-ui:
    network_mode: service:wireguard  # Shares wireguard's network
  pihole:
    dns:
      - 127.0.0.1
      - ${PIHOLE_DNS}
```

**Our Learning**: 
- Network mode sharing is efficient for UI + server
- Dependency ordering ensures proper startup
- Environment variables provide flexibility

**Our Adaptation**:
- Used same network mode sharing pattern
- Added proper health checks
- Integrated with existing HA DNS infrastructure instead of single Pi-hole

### 2. Environment Variable Configuration

**Wirehole Variables**:
```bash
TIMEZONE=America/Los_Angeles
PIHOLE_DNS=10.2.0.200
WIREGUARD_PEERS=1
WG_HOST=my.ddns.net
WGUI_USERNAME=admin
WGUI_PASSWORD=admin
```

**Our Learning**:
- Simple, clear variable naming
- Sensible defaults
- All configuration in one place

**Our Improvement**:
- More comprehensive variable set
- Better security (no default passwords)
- Additional advanced options (MTU, keepalive, etc.)
- Integration variables for existing stack

### 3. Network Design

**Wirehole Network**:
```yaml
networks:
  private_network:
    ipam:
      driver: default
      config:
        - subnet: 10.2.0.0/24
```

**Our Learning**:
- Isolated network for VPN services
- Static IP assignments for reliability
- Simple IPAM configuration

**Our Adaptation**:
- Used 10.13.13.0/24 to avoid conflicts
- Multiple networks for better isolation (vpn_net, proxy_net)
- Integration with existing dns_net

### 4. DNS Configuration

**Wirehole Approach**:
- VPN clients point to Pi-hole (10.2.0.100)
- Pi-hole points to Unbound (10.2.0.200)
- Unbound resolves to root DNS servers

**Our Learning**:
- Cascading DNS provides both ad-blocking and privacy
- Static IPs crucial for DNS reliability
- DNS is the cornerstone of the whole setup

**Our Enhancement**:
- VPN clients use existing HA Pi-hole (192.168.8.251)
- Benefit from dual Pi-hole setup
- Keepalived VIP for additional redundancy
- Already configured Unbound backend

### 5. Split Tunnel Recommendation

**Wirehole Documentation**:
> "For a split-tunnel VPN, configure your WireGuard client AllowedIps to 10.2.0.0/24"

**Our Learning**:
- Split tunnel is more efficient for most users
- Full tunnel has privacy benefits but performance cost
- Users should choose based on needs

**Our Enhancement**:
- Documented three configurations: full, split, DNS-only
- Provided examples for each
- Explained trade-offs clearly
- Made split tunnel the default recommendation

## Our Improvements

### 1. Enhanced Documentation

**Wirehole**: Basic README with setup instructions

**Our Implementation**:
- **README.md**: Overview and quick start
- **DEPLOYMENT_GUIDE.md**: Comprehensive deployment
- **QUICK_REFERENCE.md**: Command reference
- **INTEGRATION_GUIDE.md**: Stack integration
- **Multiple examples**: For different use cases

**Benefit**: Users can find information for any scenario

### 2. Router VPN Compatibility

**Wirehole**: No specific guidance for router VPN scenarios

**Our Implementation**:
- Dedicated guide for router VPN bypass
- Multiple solutions (DDNS, port forwarding, exclusion)
- Specific instructions for Proton VPN
- Troubleshooting section

**Benefit**: Works in complex network scenarios

### 3. HA Integration

**Wirehole**: Standalone Pi-hole instance

**Our Implementation**:
- Integrates with existing HA DNS infrastructure
- Uses dual Pi-hole setup
- Benefits from Keepalived VIP
- Maintains existing monitoring

**Benefit**: Enterprise-grade reliability

### 4. Additional Services

**Wirehole**: VPN + Pi-hole + Unbound

**Our Implementation**:
- VPN + WireGuard-UI (same as wirehole)
- Integration with existing Pi-hole + Unbound (enhanced)
- **+ Nginx Proxy Manager** (new)
- **+ Existing monitoring stack** (Prometheus, Grafana)

**Benefit**: Complete remote access solution, not just VPN

### 5. Deployment Automation

**Wirehole**: Manual docker compose commands

**Our Implementation**:
- Automated deployment script (`deploy-vpn.sh`)
- Pre-flight checks
- Configuration validation
- Post-deployment verification
- Clear error messages

**Benefit**: Reduced deployment errors

### 6. Security Focus

**Wirehole**: Basic security (passwords in .env)

**Our Implementation**:
- Strong password generation instructions
- No default passwords
- Security best practices guide
- Resource limits
- Health checks
- Firewall configuration guidance

**Benefit**: Production-ready security

### 7. Use Case Examples

**Wirehole**: General VPN use case

**Our Implementation**:
- Media server access (Jellyfin/Plex)
- Home automation access
- Mobile ad-blocking
- Full remote work setup
- DNS-only configuration
- Multiple configuration examples

**Benefit**: Clear guidance for specific needs

## Technical Differences

### Docker Compose Structure

**Wirehole**:
```yaml
version: "3"
services:
  unbound:
    image: mvance/unbound:latest
    # Basic config
  
  wireguard:
    image: linuxserver/wireguard
    # Basic config
  
  pihole:
    image: pihole/pihole:latest
    # Basic config
```

**Our Implementation**:
```yaml
services:
  wireguard:
    image: linuxserver/wireguard:latest
    # Advanced config
    environment:
      - SERVERURL=${WG_SERVER_URL:-auto}
      - PEERS=${WG_PEERS:-3}
      # Many more options
    healthcheck:
      test: ["CMD", "test", "-f", "/config/wg_confs/wg0.conf"]
      # Proper health monitoring
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        # Resource management
  
  wireguard-ui:
    # Same as wirehole
  
  nginx-proxy-manager:
    # Additional service
    # Not in wirehole
```

**Improvements**:
- Health checks for reliability
- Resource limits for stability
- More configuration options
- Additional service (NPM)

### Network Configuration

**Wirehole**:
- Single network (10.2.0.0/24)
- All services on same network

**Our Implementation**:
- Multiple networks (vpn_net, proxy_net)
- Integration with existing dns_net
- Better isolation
- More scalable

### Environment Variables

**Wirehole** (7 variables):
```bash
TIMEZONE
PUID / PGID
PIHOLE_DNS
WIREGUARD_PEERS
WGUI_USERNAME
WGUI_PASSWORD
```

**Our Implementation** (15+ variables):
```bash
# All wirehole vars +
WG_SERVER_URL
WG_SERVER_PORT
WG_INTERNAL_SUBNET
WG_ALLOWED_IPS
WG_LOG_CONFS
WGUI_SESSION_SECRET
WGUI_MTU
WGUI_PERSISTENT_KEEPALIVE
WGUI_FORWARD_MARK
# Plus optional email vars
```

**Benefit**: More control and flexibility

## What We Kept from Wirehole

### 1. Core Architecture
✅ WireGuard as VPN server  
✅ WireGuard-UI for management  
✅ VPN clients use Pi-hole for DNS  
✅ Network isolation concept

### 2. Technology Choices
✅ linuxserver/wireguard image  
✅ ngoduykhanh/wireguard-ui image  
✅ Environment-based configuration  
✅ Docker Compose deployment

### 3. Design Patterns
✅ Network mode sharing (wireguard-ui with wireguard)  
✅ Dependency ordering (depends_on)  
✅ Static IP assignments  
✅ Volume persistence

## What We Changed

### 1. Integration Approach
❌ Wirehole: Standalone Pi-hole  
✅ Ours: Integrated with HA DNS stack

### 2. Scope
❌ Wirehole: Just VPN + DNS  
✅ Ours: VPN + DNS + Reverse Proxy + Monitoring

### 3. Documentation
❌ Wirehole: Single README  
✅ Ours: Multiple comprehensive guides

### 4. Deployment
❌ Wirehole: Manual  
✅ Ours: Automated with validation

### 5. Use Cases
❌ Wirehole: General VPN  
✅ Ours: Specific scenarios with examples

## Why Our Approach is Better for This Use Case

### 1. HA Requirements
The user already has an HA DNS stack. Our solution:
- Integrates seamlessly without replacing existing infrastructure
- Maintains all HA benefits
- No disruption to existing services

### 2. Router VPN Scenario
The user has Proton VPN on router. Our solution:
- Documented multiple workarounds
- Tested scenarios
- DDNS integration

### 3. Service Exposure
The user wants to expose media servers. Our solution:
- Added Nginx Proxy Manager
- SSL certificate management
- Subdomain routing
- Not in wirehole

### 4. Production Readiness
The user needs reliable solution. Our solution:
- Health checks
- Resource limits
- Monitoring integration
- Backup procedures
- Security best practices

### 5. Ease of Use
The user needs easy deployment. Our solution:
- Automated deployment script
- Pre-flight checks
- Clear error messages
- Step-by-step guides

## Wirehole Strengths

Despite our enhancements, wirehole excels at:

1. **Simplicity**: Single compose file, minimal config
2. **Standalone**: Works independently, no dependencies
3. **Lightweight**: Minimal resource usage
4. **Quick Setup**: Up and running in minutes
5. **Proven**: Large user base, battle-tested

**When to use wirehole**: Starting from scratch, simple needs, standalone VPN

**When to use our implementation**: 
- Already have HA DNS stack
- Need router VPN compatibility
- Want service exposure (media servers)
- Require enterprise features
- Need comprehensive documentation

## Credit Where Credit is Due

Our implementation stands on the shoulders of wirehole:
- Core concept inspired by wirehole
- Similar architecture pattern
- Same core technologies
- Proven approach

**Thank you to the wirehole project for pioneering this integration pattern!**

## Conclusion

Wirehole is an excellent project that pioneered the WireGuard + Pi-hole integration. We learned from it and adapted the concepts for our specific use case:

**What we learned from wirehole**:
- ✅ WireGuard + Pi-hole integration pattern
- ✅ WireGuard-UI for management
- ✅ Network isolation approach
- ✅ Environment-based configuration

**What we added**:
- ✅ HA DNS stack integration
- ✅ Nginx Proxy Manager
- ✅ Router VPN compatibility
- ✅ Comprehensive documentation
- ✅ Automated deployment
- ✅ Production-ready features

**Result**: An enterprise-grade VPN solution that integrates seamlessly with existing infrastructure while maintaining the simplicity and elegance of the wirehole approach.
