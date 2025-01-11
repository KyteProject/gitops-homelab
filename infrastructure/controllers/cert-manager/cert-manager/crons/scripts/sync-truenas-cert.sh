#!/bin/sh

set -x  # Enable debug output

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

# Show the JSON payload (excluding sensitive data)
echo "Sending request to TrueNAS API..."
echo "JSON structure (sensitive data redacted):"
echo "$JSON_DATA" | sed 's/\("certificate": \)".*"/\1"<REDACTED>"/; s/\("privatekey": \)".*"/\1"<REDACTED>"/'

# Copy to TrueNAS using the API with verbose output
curl -k -v -X POST \
  "https://tank.omux.io/api/v2.0/certificate" \
  -H "Authorization: Bearer ${TRUENAS_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$JSON_DATA"

# Show the response code
echo "Curl exit code: $?"

# Clean up
rm /tmp/truenas.crt /tmp/truenas.key
