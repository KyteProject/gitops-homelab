---
apiVersion: v1
kind: Namespace
metadata:
  name: security
---
apiVersion: v1
kind: Secret
metadata:
  name: onepassword-secret
  namespace: security
stringData:
  1password-credentials.json: op://homelab/1password/OP_CREDENTIALS_JSON
  token: op://homelab/1password/OP_CONNECT_TOKEN
