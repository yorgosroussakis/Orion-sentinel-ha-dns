#!/usr/bin/env python3
from flask import Flask, jsonify
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST
import docker
import time

app = Flask(__name__)
client = docker.from_env()

restart_counter = Counter('ai_watchdog_restarts_total', 'Number of container restarts performed')

WATCHLIST = ['pihole1', 'pihole2', 'unbound1', 'unbound2', 'keepalived-primary']

@app.route('/')
def index():
    return jsonify({'status': 'ok', 'watched': WATCHLIST})

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/check')
def check():
    result = {}
    for name in WATCHLIST:
        try:
            c = client.containers.get(name)
            running = c.status == 'running'
            result[name] = {'status': c.status}
            if not running:
                c.restart()
                restart_counter.inc()
                result[name]['action'] = 'restarted'
        except docker.errors.NotFound:
            result[name] = {'status': 'not_found'}
    return jsonify(result)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
