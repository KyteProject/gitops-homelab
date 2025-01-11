#!/bin/bash

# Get token from first argument
if [ -z "$1" ]; then
    echo "Error: Token argument is required"
    echo "Usage: $0 <token>"
    exit 1
fi

TOKEN="$1"

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

echo "Sending request to TrueNAS API..."
echo "JSON structure (sensitive data redacted):"
echo "$JSON_DATA" | sed 's/\("certificate": \)".*"/\1"<REDACTED>"/; s/\("privatekey": \)".*"/\1"<REDACTED>"/'

# Use token from argument
curl -k -s -S -X POST \
  "https://tank.omux.io/api/v2.0/certificate" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$JSON_DATA"

# Show the response code
CURL_EXIT=$?
echo "Curl exit code: ${CURL_EXIT}"

if [ $CURL_EXIT -ne 0 ]; then
    echo "Error: curl command failed"
    exit 1
fi

if grep -q "Invalid API key" /tmp/response.txt; then
    echo "Error: Invalid API key"
    exit 1
fi

# Clean up
rm /tmp/truenas.crt /tmp/truenas.key /tmp/response.txt
