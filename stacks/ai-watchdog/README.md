# AI Watchdog - Predictive Container Health Monitor

Intelligent container monitoring system with **log parsing and failure prediction** capabilities. Goes beyond simple health checks by analyzing log patterns to predict and prevent failures before they occur.

## Features

### 🔍 Real-Time Log Analysis
- Continuously streams and parses logs from all monitored containers
- Detects error patterns using regex-based classification
- Tracks error frequency and trends over time

### 🎯 Failure Prediction
- Predicts imminent container failures based on error patterns
- Analyzes error rates (errors per minute)
- Identifies error trends and escalating issues
- Takes **preventive action** before complete failure

### 🚨 Error Pattern Detection
Automatically detects these critical patterns:
- **OOM Killer**: Out of memory conditions
- **DNS Timeout**: DNS resolution failures
- **Connection Refused**: Network connectivity issues
- **Config Errors**: Configuration problems
- **Permission Denied**: Access control issues
- **Disk Full**: Storage exhaustion
- **Network Unreachable**: Network infrastructure problems
- **Fatal Errors**: Critical application errors

### ⚡ Intelligent Actions
- **Warning Threshold**: 5 errors/min - Sends alert
- **Critical Threshold**: 10 errors/min - Preventive restart
- **Rate Limiting**: Max 5 restarts/hour per container
- **Cooldown Period**: 5 minutes between predictions for same error type

### 📊 Prometheus Metrics

```
# Container health status (0=unhealthy, 1=healthy)
ai_watchdog_container_health{container="pihole_primary"} 1

# Total restarts performed
ai_watchdog_restarts_total{container="pihole_primary"} 5

# Errors detected in logs
ai_watchdog_log_errors_total{container="pihole_primary",error_type="dns_timeout"} 42

# Predicted failures
ai_watchdog_predicted_failures_total{container="pihole_primary"} 3

# Preventive restarts
ai_watchdog_preventive_restarts_total{container="pihole_primary"} 2

# Uptime and monitoring stats
ai_watchdog_uptime_seconds 86400
ai_watchdog_containers_monitored 5
```

## API Endpoints

### GET /
Basic status check
```json
{
  "status": "ok",
  "watched": ["pihole_primary", "pihole_secondary", ...]
}
```

### GET /health
Detailed health information with error statistics
```json
{
  "status": "healthy",
  "uptime_seconds": 86400,
  "containers_monitored": 5,
  "last_check": "2024-01-01T12:00:00",
  "watchlist": [...],
  "error_statistics": {
    "pihole_primary": {
      "recent_errors": 3,
      "total_errors_tracked": 42
    }
  },
  "log_monitors_active": 5
}
```

### GET /check
Manual container health check and restart
```json
{
  "pihole_primary": {
    "status": "running"
  },
  "unbound_primary": {
    "status": "exited",
    "action": "restarted"
  }
}
```

### GET /predictions ⭐
**NEW**: Real-time failure predictions
```json
{
  "timestamp": "2024-01-01T12:00:00",
  "predictions": {
    "pihole_primary": {
      "predicted_failure_type": "dns_timeout",
      "error_rate_per_minute": 8.5,
      "risk_level": "warning",
      "recent_errors": 25
    }
  }
}
```

### GET /metrics
Prometheus-compatible metrics endpoint

## How It Works

### 1. Log Monitoring
- Spawns dedicated thread for each container
- Streams logs in real-time using Docker API
- Parses each line against error patterns
- Records errors with timestamp and type

### 2. Error Tracking
- Maintains 60-minute sliding window of errors
- Tracks error frequency and distribution
- Identifies most common error types
- Calculates error rate trends

### 3. Failure Prediction
- Analyzes last 5 minutes of errors
- Calculates errors per minute
- Checks if error rate is increasing
- Identifies critical patterns

### 4. Preventive Action
When error rate ≥ 10/min:
1. **Predict** failure type and severity
2. **Alert** via Signal notification
3. **Restart** container preventively
4. **Verify** container recovers
5. **Log** action to Prometheus

### 5. Rate Limiting
- Max 5 restarts per hour per container
- 5-minute cooldown between duplicate predictions
- Alerts when rate limit exceeded
- Requires manual intervention after limit

## Configuration

### Environment Variables

```yaml
SIGNAL_BRIDGE_URL: http://signal-webhook-bridge:8080/test  # Signal notification endpoint
TZ: UTC  # Timezone for logs
```

### Monitored Containers

Default watchlist in `app.py`:
```python
WATCHLIST = [
    'pihole_primary',
    'pihole_secondary', 
    'unbound_primary',
    'unbound_secondary',
    'keepalived'
]
```

To add more containers, edit the `WATCHLIST` array.

### Thresholds

Adjust in `app.py`:
```python
ERROR_THRESHOLD_WARNING = 5   # errors/min for warning
ERROR_THRESHOLD_CRITICAL = 10  # errors/min for action
MAX_RESTARTS_PER_HOUR = 5     # rate limit
```

## Deployment

```bash
cd /opt/rpi-ha-dns-stack/stacks/ai-watchdog
docker compose up -d
```

## Monitoring the Watchdog

### Check Status
```bash
curl http://localhost:5000/health
```

### View Predictions
```bash
curl http://localhost:5000/predictions
```

### Prometheus Scraping
Add to `prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'ai-watchdog'
    static_configs:
      - targets: ['ai-watchdog:5000']
```

### Grafana Dashboard
Create alerts on:
- `ai_watchdog_predicted_failures_total` - Failure predictions
- `rate(ai_watchdog_log_errors_total[5m])` - Error rate trends
- `ai_watchdog_preventive_restarts_total` - Preventive actions

## Signal Notifications

### Notification Types

**Preventive Action:**
```
⚠️ AI-Watchdog PREDICTION: Container pihole_primary showing 
signs of imminent failure!
Error Type: dns_timeout
Error Rate: 12.5 errors/min
Taking preventive action...
```

**Success:**
```
✅ AI-Watchdog: Preventively restarted pihole_primary
```

**Rate Limit:**
```
🚨 AI-Watchdog: Rate limit reached for: pihole_primary
```

**Manual Intervention:**
```
⚠️ AI-Watchdog: Container pihole_primary restart limit 
exceeded (5/hour). Manual intervention required.
```

## Benefits

### vs. Traditional Health Checks
| Feature | Traditional | AI Watchdog |
|---------|------------|-------------|
| Detection | After failure | Before failure |
| Response Time | Minutes | Seconds |
| Root Cause | Unknown | Identified |
| Prevention | Reactive | Proactive |
| Downtime | Seconds-Minutes | Near zero |

### Real-World Example

**Without Predictive Monitoring:**
1. Pi-hole experiences DNS timeout errors
2. Errors accumulate over 10 minutes
3. Container crashes
4. Watchdog detects crash (30s later)
5. Container restarted
6. **Total downtime: ~45 seconds**

**With Predictive Monitoring:**
1. Pi-hole experiences DNS timeout errors
2. AI Watchdog detects pattern after 2 minutes
3. Predicts imminent failure
4. Preventively restarts container
5. **Total downtime: ~5 seconds (restart only)**

## Troubleshooting

### Log Monitors Not Starting
```bash
# Check container logs
docker logs ai-watchdog

# Verify Docker socket access
docker exec ai-watchdog ls -la /var/run/docker.sock
```

### No Predictions Showing
```bash
# Check if errors are being detected
curl http://localhost:5000/health | jq '.error_statistics'

# View Prometheus metrics
curl http://localhost:5000/metrics | grep log_errors
```

### Too Many False Positives
Increase thresholds in `app.py`:
```python
ERROR_THRESHOLD_WARNING = 10   # default: 5
ERROR_THRESHOLD_CRITICAL = 20  # default: 10
```

### Container Restart Loops
Rate limiting prevents restart loops, but if needed:
```python
MAX_RESTARTS_PER_HOUR = 3  # default: 5
```

## Architecture

```
┌─────────────────┐
│  Log Monitors   │◄──── Docker API
│  (5 threads)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Error Pattern  │
│   Detector      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Failure Risk    │
│   Analyzer      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Prediction    │
│    Engine       │
└────────┬────────┘
         │
         ├──► Prometheus Metrics
         ├──► Signal Alerts
         └──► Container Restart
```

## Performance

- **CPU**: ~0.1-0.3 cores (5 log monitors + Flask)
- **Memory**: ~64-128 MB
- **Network**: Minimal (local Docker socket)
- **Disk**: None (in-memory tracking only)

## Future Enhancements

Potential additions:
- Machine learning for pattern recognition
- Anomaly detection algorithms
- Auto-tuning of thresholds
- Historical trend analysis
- Cross-container correlation
- Predictive scaling recommendations

## Contributing

To add new error patterns, edit `ERROR_PATTERNS` in `app.py`:
```python
ERROR_PATTERNS = {
    'your_pattern': re.compile(r'your regex', re.IGNORECASE),
    ...
}
```

## Version History

- **v2.3.0**: Added predictive failure analysis with log parsing
- **v2.0.0**: Initial AI Watchdog with basic health checks
