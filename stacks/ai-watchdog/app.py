#!/usr/bin/env python3
from flask import Flask, jsonify
from prometheus_client import Counter, Gauge, generate_latest, CONTENT_TYPE_LATEST
import docker
import requests
import os
import time
import re
import threading
from datetime import datetime, timedelta
from collections import defaultdict, deque

app = Flask(__name__)
client = docker.from_env()

# Prometheus metrics
restart_counter = Counter('ai_watchdog_restarts_total', 'Number of container restarts performed', ['container'])
container_health_gauge = Gauge('ai_watchdog_container_health', 'Container health status', ['container'])
uptime_gauge = Gauge('ai_watchdog_uptime_seconds', 'Watchdog uptime in seconds')
containers_monitored_gauge = Gauge('ai_watchdog_containers_monitored', 'Number of containers being monitored')
log_errors_counter = Counter('ai_watchdog_log_errors_total', 'Number of errors detected in logs', ['container', 'error_type'])
predicted_failures_counter = Counter('ai_watchdog_predicted_failures_total', 'Number of predicted failures', ['container'])
preventive_restarts_counter = Counter('ai_watchdog_preventive_restarts_total', 'Number of preventive restarts', ['container'])

WATCHLIST = ['pihole_primary', 'pihole_secondary', 'unbound_primary', 'unbound_secondary', 'keepalived']

# Signal webhook bridge configuration
SIGNAL_BRIDGE_URL = os.environ.get('SIGNAL_BRIDGE_URL', 'http://signal-webhook-bridge:8080/test')

# Restart tracking with exponential backoff
restart_history = {}
MAX_RESTARTS_PER_HOUR = 5
start_time = time.time()
last_check_time = None

# Log analysis tracking
log_error_history = defaultdict(lambda: deque(maxlen=60))  # Track errors for last 60 minutes
ERROR_PATTERNS = {
    'oom_killer': re.compile(r'(out of memory|OOM|killed.*memory)', re.IGNORECASE),
    'dns_timeout': re.compile(r'(timeout|timed out|dns.*timeout)', re.IGNORECASE),
    'connection_refused': re.compile(r'(connection refused|connection reset)', re.IGNORECASE),
    'config_error': re.compile(r'(config.*error|configuration.*failed|invalid.*config)', re.IGNORECASE),
    'permission_denied': re.compile(r'(permission denied|access denied)', re.IGNORECASE),
    'disk_full': re.compile(r'(no space left|disk.*full)', re.IGNORECASE),
    'network_unreachable': re.compile(r'(network.*unreachable|no route to host)', re.IGNORECASE),
    'fatal_error': re.compile(r'(fatal|critical|emergency)', re.IGNORECASE),
}

# Failure prediction thresholds
ERROR_THRESHOLD_WARNING = 5  # errors per minute for warning
ERROR_THRESHOLD_CRITICAL = 10  # errors per minute for preventive action
prediction_cache = {}  # Cache predictions to avoid duplicate alerts

def get_uptime():
    """Get watchdog uptime in seconds"""
    return time.time() - start_time

def should_restart_container(container_name):
    """Check if container should be restarted (rate limiting)"""
    current_hour = datetime.now().strftime('%Y%m%d%H')
    key = f"{container_name}_{current_hour}"
    
    if key not in restart_history:
        restart_history[key] = 0
    
    if restart_history[key] >= MAX_RESTARTS_PER_HOUR:
        send_signal_notification(
            f"⚠️ AI-Watchdog: Container {container_name} restart limit exceeded "
            f"({MAX_RESTARTS_PER_HOUR}/hour). Manual intervention required."
        )
        return False
    
    restart_history[key] += 1
    return True

def send_signal_notification(message):
    """Send notification via Signal webhook bridge"""
    try:
        response = requests.post(
            SIGNAL_BRIDGE_URL,
            json={'message': message},
            timeout=5
        )
        if response.status_code == 200:
            print(f"Signal notification sent: {message}")
        else:
            print(f"Failed to send Signal notification: {response.status_code}")
    except Exception as e:
        print(f"Error sending Signal notification: {str(e)}")

def parse_log_line(line, container_name):
    """Parse a log line and detect error patterns"""
    for error_type, pattern in ERROR_PATTERNS.items():
        if pattern.search(line):
            # Record error with timestamp
            error_time = time.time()
            log_error_history[container_name].append({
                'type': error_type,
                'time': error_time,
                'line': line[:200]  # Store first 200 chars for context
            })
            log_errors_counter.labels(container=container_name, error_type=error_type).inc()
            return error_type
    return None

def analyze_failure_risk(container_name):
    """Analyze error patterns to predict imminent failure"""
    if container_name not in log_error_history:
        return None, 0
    
    errors = log_error_history[container_name]
    if not errors:
        return None, 0
    
    # Calculate error rate in last 5 minutes
    current_time = time.time()
    recent_errors = [e for e in errors if current_time - e['time'] < 300]
    
    if not recent_errors:
        return None, 0
    
    # Calculate errors per minute
    time_window = min(5 * 60, current_time - recent_errors[0]['time'])
    error_rate = (len(recent_errors) / time_window) * 60 if time_window > 0 else 0
    
    # Identify most common error type
    error_types = [e['type'] for e in recent_errors]
    most_common_error = max(set(error_types), key=error_types.count) if error_types else None
    
    # Predict failure based on error rate and type
    if error_rate >= ERROR_THRESHOLD_CRITICAL:
        return most_common_error, error_rate
    elif error_rate >= ERROR_THRESHOLD_WARNING:
        # Check if error rate is increasing
        very_recent = [e for e in recent_errors if current_time - e['time'] < 60]
        if len(very_recent) >= ERROR_THRESHOLD_WARNING:
            return most_common_error, error_rate
    
    return None, error_rate

def monitor_container_logs(container_name):
    """Monitor container logs in real-time for error patterns"""
    print(f"Starting log monitor for {container_name}")
    
    while True:
        try:
            container = client.containers.get(container_name)
            
            # Stream logs with tail
            for line in container.logs(stream=True, follow=True, tail=10):
                line_str = line.decode('utf-8', errors='ignore').strip()
                if line_str:
                    error_type = parse_log_line(line_str, container_name)
                    
                    if error_type:
                        print(f"[{container_name}] Detected {error_type}: {line_str[:100]}")
                        
                        # Analyze if this could lead to failure
                        predicted_error, error_rate = analyze_failure_risk(container_name)
                        
                        if predicted_error and error_rate >= ERROR_THRESHOLD_CRITICAL:
                            # Check if we already predicted this recently
                            cache_key = f"{container_name}_{predicted_error}"
                            last_prediction = prediction_cache.get(cache_key, 0)
                            
                            if time.time() - last_prediction > 300:  # 5 minutes cooldown
                                prediction_cache[cache_key] = time.time()
                                predicted_failures_counter.labels(container=container_name).inc()
                                
                                message = (
                                    f"⚠️ AI-Watchdog PREDICTION: Container {container_name} showing "
                                    f"signs of imminent failure!\n"
                                    f"Error Type: {predicted_error}\n"
                                    f"Error Rate: {error_rate:.2f} errors/min\n"
                                    f"Taking preventive action..."
                                )
                                send_signal_notification(message)
                                
                                # Take preventive action
                                if should_restart_container(container_name):
                                    try:
                                        container.restart()
                                        preventive_restarts_counter.labels(container=container_name).inc()
                                        send_signal_notification(
                                            f"✅ AI-Watchdog: Preventively restarted {container_name}"
                                        )
                                        print(f"Preventively restarted {container_name}")
                                    except Exception as e:
                                        send_signal_notification(
                                            f"❌ AI-Watchdog: Failed to restart {container_name}: {str(e)}"
                                        )
                        
        except docker.errors.NotFound:
            print(f"Container {container_name} not found, waiting...")
            time.sleep(30)
        except Exception as e:
            print(f"Error monitoring {container_name}: {str(e)}")
            time.sleep(10)

def start_log_monitors():
    """Start log monitoring threads for all containers"""
    for container_name in WATCHLIST:
        thread = threading.Thread(
            target=monitor_container_logs,
            args=(container_name,),
            daemon=True,
            name=f"LogMonitor-{container_name}"
        )
        thread.start()
        print(f"Started log monitor thread for {container_name}")

@app.route('/')
def index():
    return jsonify({'status': 'ok', 'watched': WATCHLIST})

@app.route('/health')
def health():
    """Detailed health endpoint"""
    global last_check_time
    
    # Get error statistics
    error_stats = {}
    for container in WATCHLIST:
        if container in log_error_history:
            recent_errors = [e for e in log_error_history[container] 
                           if time.time() - e['time'] < 300]  # last 5 min
            error_stats[container] = {
                'recent_errors': len(recent_errors),
                'total_errors_tracked': len(log_error_history[container])
            }
    
    return jsonify({
        'status': 'healthy',
        'uptime_seconds': get_uptime(),
        'containers_monitored': len(WATCHLIST),
        'last_check': last_check_time,
        'watchlist': WATCHLIST,
        'error_statistics': error_stats,
        'log_monitors_active': threading.active_count() - 1  # -1 for main thread
    })

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    # Update uptime gauge
    uptime_gauge.set(get_uptime())
    containers_monitored_gauge.set(len(WATCHLIST))
    
    # Update health status for each container
    for name in WATCHLIST:
        try:
            c = client.containers.get(name)
            health_status = 1 if c.status == 'running' else 0
            container_health_gauge.labels(container=name).set(health_status)
        except docker.errors.NotFound:
            container_health_gauge.labels(container=name).set(0)
    
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/check')
def check():
    """Check and restart unhealthy containers"""
    global last_check_time
    last_check_time = datetime.now().isoformat()
    
    result = {}
    restarted_containers = []
    rate_limited_containers = []
    
    for name in WATCHLIST:
        try:
            c = client.containers.get(name)
            running = c.status == 'running'
            result[name] = {'status': c.status}
            
            if not running:
                if should_restart_container(name):
                    c.restart()
                    restart_counter.labels(container=name).inc()
                    result[name]['action'] = 'restarted'
                    restarted_containers.append(name)
                else:
                    result[name]['action'] = 'rate_limited'
                    rate_limited_containers.append(name)
        except docker.errors.NotFound:
            result[name] = {'status': 'not_found'}
    
    # Send Signal notification if any containers were restarted
    if restarted_containers:
        message = f"🔧 AI-Watchdog: Restarted containers: {', '.join(restarted_containers)}"
        send_signal_notification(message)
    
    # Send alert for rate-limited containers
    if rate_limited_containers:
        message = f"🚨 AI-Watchdog: Rate limit reached for: {', '.join(rate_limited_containers)}"
        send_signal_notification(message)
    
    return jsonify(result)

@app.route('/predictions')
def predictions():
    """Get current failure predictions for all containers"""
    predictions = {}
    
    for container_name in WATCHLIST:
        predicted_error, error_rate = analyze_failure_risk(container_name)
        
        if predicted_error or error_rate > 0:
            predictions[container_name] = {
                'predicted_failure_type': predicted_error,
                'error_rate_per_minute': round(error_rate, 2),
                'risk_level': 'critical' if error_rate >= ERROR_THRESHOLD_CRITICAL 
                             else 'warning' if error_rate >= ERROR_THRESHOLD_WARNING 
                             else 'normal',
                'recent_errors': len([e for e in log_error_history[container_name] 
                                     if time.time() - e['time'] < 300])
            }
    
    return jsonify({
        'timestamp': datetime.now().isoformat(),
        'predictions': predictions
    })

if __name__ == '__main__':
    print(f"AI Watchdog starting with PREDICTIVE ANALYTICS...")
    print(f"Monitoring: {WATCHLIST}")
    print(f"Max restarts per hour: {MAX_RESTARTS_PER_HOUR}")
    print(f"Error threshold (warning): {ERROR_THRESHOLD_WARNING} errors/min")
    print(f"Error threshold (critical): {ERROR_THRESHOLD_CRITICAL} errors/min")
    print(f"Starting log monitors...")
    
    # Start log monitoring threads
    start_log_monitors()
    
    print(f"Log monitors started. Starting Flask API on port 5000...")
    app.run(host='0.0.0.0', port=5000)
