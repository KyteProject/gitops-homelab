#!/bin/sh

# Get the certificate from the kubernetes secret
kubectl get secret -n cert-manager truenas-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/truenas.crt
kubectl get secret -n cert-manager truenas-tls -o jsonpath='{.data.tls\.key}' | base64 -d > /tmp/truenas.key

# Format certificate and key for JSON
CERT=$(awk '{printf "%s\\n", $0}' /tmp/truenas.crt)
KEY=$(awk '{printf "%s\\n", $0}' /tmp/truenas.key)

# Create JSON payload
JSON_DATA=$(cat <<EOF
{
  "create_type": "CERTIFICATE_CREATE_IMPORTED",
  "name": "letsencrypt",
  "certificate": "$CERT",
  "privatekey": "$KEY",
  "key_type": "RSA"
}
EOF
)

# Copy to TrueNAS using the API
curl -k -X POST \
  "https://tank.omux.io/api/v2.0/certificate" \
  -H "Authorization: Bearer ${TRUENAS_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$JSON_DATA"

# Clean up
rm /tmp/truenas.crt /tmp/truenas.key
