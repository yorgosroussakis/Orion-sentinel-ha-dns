#!/bin/bash
# Generate self-signed TLS certificates for DoH/DoT Gateway
# These certificates are used by Blocky for encrypted DNS connections
#
# Usage: ./generate-certs.sh [hostname]
# Example: ./generate-certs.sh dns.mylab.local
#
# The generated certificates will be placed in the certs/ directory
# and will be valid for 365 days.
#
# For production use with trusted certificates:
# - Replace server.crt and server.key with your ACME/Let's Encrypt certs
# - Or integrate with Traefik/Caddy for automatic certificate management

set -e

CERT_DIR="$(dirname "$0")/certs"
HOSTNAME="${1:-dns.orion-sentinel.local}"
DAYS_VALID=365

# Create certs directory if it doesn't exist
mkdir -p "${CERT_DIR}"

echo "=========================================="
echo "Generating TLS Certificates for DoH/DoT"
echo "=========================================="
echo "Hostname: ${HOSTNAME}"
echo "Output:   ${CERT_DIR}"
echo "Valid:    ${DAYS_VALID} days"
echo "=========================================="

# Generate private key
openssl genrsa -out "${CERT_DIR}/server.key" 4096

# Generate self-signed certificate
openssl req -new -x509 \
    -key "${CERT_DIR}/server.key" \
    -out "${CERT_DIR}/server.crt" \
    -days ${DAYS_VALID} \
    -subj "/CN=${HOSTNAME}/O=Orion Sentinel/OU=DNS Gateway" \
    -addext "subjectAltName=DNS:${HOSTNAME},DNS:localhost,IP:127.0.0.1"

# Set appropriate permissions
chmod 600 "${CERT_DIR}/server.key"
chmod 644 "${CERT_DIR}/server.crt"

echo ""
echo "Certificates generated successfully!"
echo "  Private Key: ${CERT_DIR}/server.key"
echo "  Certificate: ${CERT_DIR}/server.crt"
echo ""
echo "IMPORTANT: These are self-signed certificates."
echo "Clients will need to trust this certificate to use DoH/DoT."
echo ""
echo "To trust on clients:"
echo "  - Android: Settings → Security → Install certificate"
echo "  - iOS: Settings → General → Profile → Install"
echo "  - macOS: Keychain Access → Import certificate"
echo "  - Windows: Certificate Manager → Import"
echo ""
echo "For production, consider using Let's Encrypt or your internal CA."
