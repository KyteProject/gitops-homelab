#!/bin/bash
# beforeReadFile hook — deny reads of files that are likely to contain secrets.
# Configured with failClosed: true so a hook failure blocks the read.

set -euo pipefail

emit_allow() {
  echo '{"permission":"allow"}'
}

emit_deny() {
  local path="$1"
  local pattern="$2"

  # Build JSON safely to avoid invalid escaping from regex patterns.
  jq -nc \
    --arg p "$path" \
    --arg pat "$pattern" \
    '{
      permission: "deny",
      user_message: ("Blocked: " + $p + " matches a secret-file pattern (" + $pat + "). Edit .cursor/hooks/block-secrets.sh to adjust.")
    }'
}

input="$(cat || true)"
file_path="$(
  printf '%s' "$input" \
    | jq -r '.file_path // .path // empty' 2>/dev/null \
    || true
)"

if [[ -z "$file_path" ]]; then
  emit_allow
  exit 0
fi

# Patterns that should never be fed to the model.
deny_patterns=(
  '\.env($|\.)'
  '/\.env\.'
  '(^|/)secrets?\.(yaml|yml|json|toml|ini|env)$'
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
    emit_deny "$file_path" "$pattern"
    exit 0
  fi
done

emit_allow
