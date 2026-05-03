#!/bin/bash
# beforeReadFile hook — deny reads of files that are likely to contain secrets.
# Configured with failClosed: true so a hook failure blocks the read.

set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.file_path // empty')

if [[ -z "$file_path" ]]; then
  echo '{"permission": "allow"}'
  exit 0
fi

# Patterns that should never be fed to the model.
deny_patterns=(
  '\.env($|\.)'
  '/\.env\.'
  'secrets?\.(yaml|yml|json|toml|ini|env)$'
  'credentials\.(json|yaml|yml|toml)$'
  'service[-_]account.*\.json$'
  '\.pem$'
  '\.key$'
  '\.pfx$'
  '\.p12$'
  'id_rsa($|\.)'
  'id_ed25519($|\.)'
  '\.kube/config$'
  '\.aws/credentials$'
  '\.npmrc$'
  '\.pypirc$'
  '\.netrc$'
)

for pattern in "${deny_patterns[@]}"; do
  if [[ "$file_path" =~ $pattern ]]; then
    cat <<JSON
{
  "permission": "deny",
  "user_message": "Blocked: $file_path matches a secret-file pattern (${pattern}). Edit .cursor/hooks/block-secrets.sh to adjust."
}
JSON
    exit 0
  fi
done

echo '{"permission": "allow"}'
