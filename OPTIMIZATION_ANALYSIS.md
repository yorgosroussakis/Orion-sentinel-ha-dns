# Stack Optimization Analysis

## Current Setup Review

### ✅ Optimizations Already Implemented

#### DNS Stack (Excellent)
- **ARM64 Images**: Using native ARM images for all services
- **Network**: External macvlan for stability and performance
- **Unique IPs**: No conflicts, proper IP allocation (.250-.255 range)
- **Unbound Port**: Correct port 5335 for Pi-hole forwarding
- **Keepalived**: Host network mode for VRRP (optimal for failover)
- **Health Checks**: Proper monitoring for all containers
- **Resource Limits**: Appropriate CPU/memory limits set
- **Pi-hole Sync**: Custom v6-compatible sync every 5 minutes
- **Blocklists**: Hagezi Pro++ + OISD Big (~5M domains total)

#### Observability Stack (Good)
- **All services present**: Prometheus, Grafana, Loki, Promtail, Alertmanager
- **Signal notifications**: CLI API + webhook bridge configured
- **Health checks**: Implemented for all services
- **Resource limits**: Set appropriately
- **Persistent storage**: Volumes for data retention

#### AI Watchdog (Good)
- **Docker socket access**: Can monitor containers
- **Network connectivity**: Bridge + observability networks
- **Health check**: Implemented
- **Resource limits**: Conservative settings

### 🔍 Optimization Opportunities

#### 1. DNS Stack - Minor Improvements

**Current Status**: 9/10 (Excellent)

**Potential Enhancements**:
```yaml
# Add DNS query logging for better observability
pihole_primary:
  environment:
    - DNSMASQ_LISTENING=all  # Ensure listening on all interfaces
    - QUERY_LOGGING=yes       # Enable query logging
```

**Unbound Performance Tuning**:
```yaml
# In unbound.conf - add these for better performance
server:
    num-threads: 2           # Already in unbound2
    msg-cache-size: 50m      # Already in unbound2
    rrset-cache-size: 100m   # Already in unbound2
    outgoing-range: 8192     # ADD: More concurrent queries
    num-queries-per-thread: 4096  # ADD: Queries per thread
    jostle-timeout: 200      # ADD: Faster timeout for busy
```

**Recommendation**: ✅ Current setup is already very good. Minor tuning optional.

---

#### 2. Observability Stack - Optimizations Needed

**Current Status**: 7/10 (Good, needs optimization)

**Issues to Address**:

##### A. Network Configuration
**Problem**: Using bridge network, should use host network or specific IPs
```yaml
# CURRENT (observability/docker-compose.yml)
networks:
  default:
    external: true
    name: observability_net

# BETTER - Add specific network config
networks:
  observability_net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24
```

##### B. Prometheus Configuration
**Optimization**: Add retention and query performance tuning
```yaml
prometheus:
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--storage.tsdb.path=/prometheus'
    - '--storage.tsdb.retention.time=30d'     # ADD
    - '--storage.tsdb.retention.size=10GB'    # ADD
    - '--web.console.libraries=/etc/prometheus/console_libraries'
    - '--web.console.templates=/etc/prometheus/consoles'
    - '--web.enable-lifecycle'                # ADD: Hot reload
```

##### C. Grafana Optimization
**Add**: More environment variables for better performance
```yaml
grafana:
  environment:
    - GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}
    - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
    - GF_INSTALL_PLUGINS=grafana-piechart-panel  # ADD: Useful plugins
    - GF_SERVER_ROOT_URL=http://192.168.8.250:3000  # ADD
    - GF_USERS_ALLOW_SIGN_UP=false            # ADD: Security
    - GF_AUTH_ANONYMOUS_ENABLED=false         # ADD: Security
```

##### D. Loki Optimization
**Add**: Retention configuration
```yaml
loki:
  command:
    - '-config.file=/etc/loki/local-config.yaml'
    - '-config.expand-env=true'  # ADD: Environment variables
```

**Loki config file should include**:
```yaml
limits_config:
  retention_period: 168h  # 7 days
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20
```

##### E. Promtail Enhancement
**Add**: Docker container log scraping
```yaml
promtail:
  volumes:
    - ./promtail:/etc/promtail
    - /var/log:/var/log:ro
    - /var/lib/docker/containers:/var/lib/docker/containers:ro  # ADD
```

**Recommendation**: ⚠️ Apply these optimizations for better performance and monitoring.

---

#### 3. AI Watchdog - Needs Enhancement

**Current Status**: 6/10 (Functional, needs improvement)

**Issues to Address**:

##### A. Resource Monitoring
**Problem**: No metrics exposed
**Solution**: Add Prometheus metrics endpoint
```python
# In app.py, add:
from prometheus_client import start_http_server, Counter, Gauge

# Metrics
container_restarts = Counter('watchdog_container_restarts_total', 'Container restarts', ['container'])
container_health = Gauge('watchdog_container_health', 'Container health', ['container'])

# Start metrics server on port 5000
start_http_server(5000)
```

##### B. Better Health Checks
**Current**: Basic health check
**Enhancement**: Add detailed health status
```python
@app.route('/health')
def health():
    return {
        'status': 'healthy',
        'uptime': get_uptime(),
        'containers_monitored': len(get_monitored_containers()),
        'last_check': last_check_time
    }
```

##### C. Smarter Restart Logic
**Add**: Exponential backoff and restart limits
```python
# Track restart attempts per container
restart_counts = {}
max_restarts_per_hour = 5

def should_restart_container(container_name):
    current_hour = datetime.now().hour
    key = f"{container_name}_{current_hour}"
    
    if key not in restart_counts:
        restart_counts[key] = 0
    
    if restart_counts[key] >= max_restarts_per_hour:
        send_alert(f"Container {container_name} restart limit exceeded")
        return False
    
    restart_counts[key] += 1
    return True
```

**Recommendation**: ⚠️ Enhance AI watchdog for production readiness.

---

#### 4. Dashboard Serving - NEW REQUIREMENT

**Current Status**: 2/10 (Static files not served)

**Problem**: Dashboard HTML files exist but no web server serves them

**Solution 1: Add Nginx Container (Recommended)**
```yaml
# Add to observability/docker-compose.yml
services:
  dashboard:
    image: nginx:alpine
    container_name: dashboard
    ports:
      - "80:80"
    volumes:
      - ../../dashboard:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost/"]
      interval: 30s
      timeout: 5s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '0.1'
          memory: 32M
```

**Solution 2: Use Python HTTP Server (Quick & Simple)**
```yaml
# Add to observability/docker-compose.yml
services:
  dashboard:
    image: python:3.11-alpine
    container_name: dashboard
    working_dir: /dashboard
    command: python -m http.server 80
    ports:
      - "80:80"
    volumes:
      - ../../dashboard:/dashboard:ro
    restart: unless-stopped
```

**Recommendation**: ⚠️ **CRITICAL** - Dashboard files are not accessible without a web server.

---

#### 5. Security Hardening

**Current Status**: 7/10 (Good, can improve)

**Enhancements Needed**:

##### A. Secrets Management
**Problem**: Passwords in .env file (plain text)
**Solution**: Use Docker secrets or encrypt sensitive data

##### B. Network Segmentation
**Current**: Some containers on default bridge
**Better**: Dedicated networks per stack
```yaml
# Create dedicated networks
networks:
  dns_net:        # Already external macvlan - GOOD
  monitoring:     # For Prometheus, Grafana
  backend:        # For databases, internal services
  frontend:       # For exposed services only
```

##### C. Container Security
**Add**: Security options
```yaml
services:
  service_name:
    security_opt:
      - no-new-privileges:true
    read_only: true  # Where possible
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # Only what's needed
```

**Recommendation**: ⚠️ Implement for production deployment.

---

#### 6. Backup & Recovery

**Current Status**: 3/10 (Not implemented)

**Missing**:
- No automated backups
- No disaster recovery plan
- No configuration backup

**Solution**: Add backup service
```yaml
services:
  backup:
    image: alpine:latest
    container_name: backup
    volumes:
      - ./pihole1:/pihole1:ro
      - ./pihole2:/pihole2:ro
      - prometheus-data:/prometheus:ro
      - grafana-data:/grafana:ro
      - ./backups:/backups
    command: |
      sh -c '
      while true; do
        tar czf /backups/backup-$(date +%Y%m%d-%H%M%S).tar.gz /pihole1 /pihole2 /prometheus /grafana
        find /backups -mtime +7 -delete
        sleep 86400
      done
      '
```

**Recommendation**: ⚠️ **HIGH PRIORITY** - Implement backup strategy.

---

## Optimization Priority Matrix

### 🔴 Critical (Implement Immediately)
1. **Dashboard Web Server** - Users can't access dashboards
2. **Backup Strategy** - No data protection

### 🟡 High Priority (Implement Soon)
3. **AI Watchdog Enhancements** - Better monitoring and metrics
4. **Observability Optimizations** - Better performance and retention
5. **Security Hardening** - Production-ready security

### 🟢 Nice to Have (Optional)
6. **DNS Fine-tuning** - Minor performance gains
7. **Network Segmentation** - Better isolation

---

## Recommended Action Plan

### Phase 1: Critical Fixes (Today)
```bash
# 1. Add dashboard web server
cd /opt/rpi-ha-dns-stack/stacks/observability
# Add nginx service to docker-compose.yml
docker compose up -d dashboard

# 2. Test dashboard access
curl http://192.168.8.250/dashboard.html
```

### Phase 2: High Priority (This Week)
```bash
# 1. Enhance observability stack
# 2. Improve AI watchdog
# 3. Add backup service
# 4. Implement security hardening
```

### Phase 3: Optimization (Next Week)
```bash
# 1. Fine-tune DNS performance
# 2. Implement network segmentation
# 3. Add monitoring dashboards
```

---

## Summary

### Current State
- **DNS Stack**: ✅ 9/10 - Excellent (ARM64, macvlan, sync, blocklists)
- **Observability**: ⚠️ 7/10 - Good (needs optimization)
- **AI Watchdog**: ⚠️ 6/10 - Functional (needs enhancement)
- **Dashboard**: 🔴 2/10 - Not accessible (critical issue)
- **Backup**: 🔴 3/10 - Not implemented (high risk)
- **Security**: ⚠️ 7/10 - Good (can improve)

### Overall Score: 67/100 (Good, needs optimization)

### To Achieve 90/100:
1. ✅ Add dashboard web server (+15 points)
2. ✅ Implement backup strategy (+10 points)
3. ✅ Enhance AI watchdog (+5 points)
4. ✅ Optimize observability stack (+3 points)

**Next Steps**: Implement Phase 1 critical fixes immediately.
