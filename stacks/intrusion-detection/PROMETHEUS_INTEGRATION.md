# CrowdSec Prometheus Integration

Add this job to your Prometheus configuration to scrape CrowdSec metrics.

## Configuration

File: `/path/to/rpi-ha-dns-stack/stacks/observability/prometheus/prometheus.yml`

Add to `scrape_configs` section:

```yaml
  - job_name: 'crowdsec'
    static_configs:
      - targets: ['crowdsec:6060']
    scrape_interval: 30s
    scrape_timeout: 10s
    metrics_path: '/metrics'
```

## Metrics Available

### Decision Metrics
- `cs_active_decisions` - Number of currently active decisions (blocked IPs)
- `cs_active_decisions_ip_count` - Number of unique IPs currently blocked
- `cs_dropped_decisions` - Decisions that were dropped

### Alert Metrics
- `cs_alerts` - Total number of alerts generated
- `cs_alerts_by_scenario` - Alerts grouped by scenario

### Parser Metrics
- `cs_parser_hits` - Number of log lines successfully parsed
- `cs_parser_unparsed_hits` - Log lines that couldn't be parsed
- `cs_parser_parsed_hits` - Successfully parsed log lines

### Bucket Metrics
- `cs_bucket_created` - Total buckets created
- `cs_bucket_overflowed` - Buckets that overflowed (triggered scenarios)
- `cs_bucket_poured` - Events poured into buckets

### LAPI Metrics
- `cs_lapi_route_requests` - API requests by route
- `cs_lapi_machine_requests` - Requests by machine
- `cs_lapi_bouncer_requests` - Requests by bouncer

## Example Queries

### Active Blocked IPs
```promql
cs_active_decisions
```

### Alert Rate (per minute)
```promql
rate(cs_alerts[1m])
```

### Top Scenarios Triggering Alerts
```promql
topk(5, sum by (scenario) (rate(cs_alerts_by_scenario[5m])))
```

### Parser Success Rate
```promql
cs_parser_parsed_hits / (cs_parser_parsed_hits + cs_parser_unparsed_hits) * 100
```

### Bucket Overflow Rate
```promql
rate(cs_bucket_overflowed[5m])
```

## Grafana Dashboard

Import the official CrowdSec dashboard:

1. Go to Grafana → Dashboards → Import
2. Enter Dashboard ID: **15174**
3. Select your Prometheus data source
4. Click Import

This dashboard provides:
- Real-time decision count
- Alert history
- Parser performance
- Scenario statistics
- Bouncer activity

## Custom Alerts

Add these to Alertmanager for security notifications:

```yaml
groups:
  - name: crowdsec_alerts
    interval: 1m
    rules:
      - alert: CrowdSecHighBlockRate
        expr: rate(cs_active_decisions[5m]) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High IP blocking rate detected"
          description: "CrowdSec is blocking {{ $value }} IPs per second"
      
      - alert: CrowdSecBouncerDown
        expr: up{job="crowdsec"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "CrowdSec bouncer is down"
          description: "CrowdSec metrics endpoint is unreachable"
      
      - alert: CrowdSecManyAlerts
        expr: rate(cs_alerts[10m]) > 50
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High alert rate from CrowdSec"
          description: "Detecting {{ $value }} alerts per second - possible attack in progress"
```

## Testing Metrics

After adding to Prometheus:

1. **Verify scraping:**
   - Go to Prometheus → Status → Targets
   - Look for `crowdsec` endpoint
   - Should show "UP" status

2. **Test queries:**
   - Go to Prometheus → Graph
   - Enter: `cs_active_decisions`
   - Click Execute

3. **Check Grafana:**
   - Import dashboard 15174
   - Verify data is displayed

## Restart Services

After updating Prometheus config:

```bash
cd /path/to/rpi-ha-dns-stack/stacks/observability
docker compose restart prometheus
```

Or reload without restart:
```bash
curl -X POST http://localhost:9090/-/reload
```
