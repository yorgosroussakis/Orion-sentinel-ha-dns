# Example Configurations for Common Use Cases

This directory contains example configurations for common VPN and remote access scenarios.

## Available Examples

### 1. Full Tunnel Configuration
**File**: `full-tunnel.env`
**Use Case**: Route all traffic through your home network
**Best For**: Privacy-focused users, remote workers

### 2. Split Tunnel Configuration
**File**: `split-tunnel.env`
**Use Case**: Only route local network traffic through VPN
**Best For**: Most users, better performance

### 3. DNS-Only Configuration
**File**: `dns-only.conf`
**Use Case**: Only use home Pi-hole for DNS, no traffic routing
**Best For**: Mobile ad-blocking only

### 4. Media Server Setup
**File**: `media-server-npm.json`
**Use Case**: Expose Jellyfin/Plex through Nginx Proxy Manager
**Best For**: Streaming media remotely

### 5. Home Lab Access
**File**: `home-lab.env`
**Use Case**: Access multiple home services (NAS, Home Assistant, etc.)
**Best For**: Home automation enthusiasts

### 6. Router VPN Bypass
**File**: `router-vpn-bypass.md`
**Use Case**: Configure when router has its own VPN (like Proton VPN)
**Best For**: Users with router-level VPN

## How to Use These Examples

1. Copy the relevant example file
2. Modify values to match your setup
3. Apply the configuration
4. Test the setup

See individual files for detailed instructions.
