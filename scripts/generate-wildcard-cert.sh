#!/bin/bash

# Generate wildcard certificate and create YAML manifest
# This script creates both the certificate files and a YAML manifest

set -e

echo "🔐 Generating wildcard certificate for all 127-0-0-1.sslip.io domains..."

# Create certificate configuration
cat > wildcard-cert.conf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C=US
ST=CA
L=San Francisco
O=Kong
OU=KNEP
CN=*.127-0-0-1.sslip.io

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.127-0-0-1.sslip.io
DNS.2 = 127-0-0-1.sslip.io
DNS.3 = *.team-a.127-0-0-1.sslip.io
DNS.4 = team-a.127-0-0-1.sslip.io
DNS.5 = *.team-b.127-0-0-1.sslip.io
DNS.6 = team-b.127-0-0-1.sslip.io
DNS.7 = bootstrap.team-a.127-0-0-1.sslip.io
DNS.8 = bootstrap.team-b.127-0-0-1.sslip.io
EOF

# Generate private key and certificate
openssl genrsa -out wildcard.key 2048
openssl req -new -key wildcard.key -out wildcard.csr -config wildcard-cert.conf
openssl x509 -req -in wildcard.csr -signkey wildcard.key -out wildcard.crt -days 365 -extensions v3_req -extfile wildcard-cert.conf

# Base64 encode the certificate and key for YAML (macOS compatible)
CERT_B64=$(base64 -i wildcard.crt | tr -d '\n')
KEY_B64=$(base64 -i wildcard.key | tr -d '\n')

# Create YAML manifest
cat > wildcard-tls-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
type: kubernetes.io/tls
data:
  tls.crt: ${CERT_B64}
  tls.key: ${KEY_B64}
EOF

# Verify certificate
echo "📋 Certificate verification:"
openssl x509 -in wildcard.crt -text -noout | grep -A 10 "Subject Alternative Name"

# Clean up temporary files
rm -f wildcard-cert.conf wildcard.csr

echo ""
echo "✅ Files generated:"
echo "   📄 wildcard.crt - Certificate file"
echo "   🔑 wildcard.key - Private key file"
echo "   📋 wildcard-tls-secret.yaml - Kubernetes secret manifest"
echo ""
echo "🚀 To apply the secret:"
echo "   kubectl apply -f wildcard-tls-secret.yaml"
echo ""
echo "🔍 To verify the secret:"
echo "   kubectl get secret tls-secret -n knep -o yaml"
