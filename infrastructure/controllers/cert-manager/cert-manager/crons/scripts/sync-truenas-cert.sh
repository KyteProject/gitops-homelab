#!/bin/sh

# Get the certificate from the kubernetes secret
kubectl get secret -n cert-manager truenas-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/truenas.crt
kubectl get secret -n cert-manager truenas-tls -o jsonpath='{.data.tls\.key}' | base64 -d > /tmp/truenas.key

# Copy to TrueNAS using the API
curl -k -X POST \
  "https://tank.omux.io/api/v2.0/certificate" \
  -H "Authorization: Bearer ${TRUENAS_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "letsencrypt",
    "certificate": "'$(cat /tmp/truenas.crt | sed 's/$/\\n/' | tr -d '\n')'",
    "privatekey": "'$(cat /tmp/truenas.key | sed 's/$/\\n/' | tr -d '\n')'"
  }'

# Clean up
rm /tmp/truenas.crt /tmp/truenas.key
