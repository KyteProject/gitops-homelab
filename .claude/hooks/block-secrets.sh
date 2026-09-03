#!/usr/bin/env bash
# PreToolUse hook (matcher: Read|Edit|Write) - deny tool calls targeting files
# that are likely to contain secrets. Exit 2 + stderr blocks the call and
# feeds the message back to Claude.
#
# Input on stdin: { "tool_name", "tool_input": { "file_path": ..., ... }, ... }.

set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

if [[ -z "$file_path" ]]; then
  exit 0
fi

deny_patterns=(
  '\.env($|\.)'
  '/\.env\.'
  # Anchored so it does not swallow ExternalSecret CRs. Every *secret.yaml in
  # this repo is a `kind: ExternalSecret` holding only vault key references and
  # Go templates, never secret material, so 'externalsecret.yaml' must not match
  # while 'secrets.yaml' and 'app-secret.yaml' still do.
  '(^|[/._-])secrets?\.(yaml|yml|json|toml|ini|env)$'
  'credentials\.(json|yaml|yml|toml)$'
  'service[-_]account.*\.json$'
  '\.pem$'
  '\.key$'
  '\.pfx$'
  '\.p12$'
  'id_rsa($|\.)'
  'id_ed25519($|\.)'
  '\.kube/config$'
  # This repo keeps a live cluster admin kubeconfig and Talos client certs at
  # non-standard paths that '\.kube/config$' does not catch.
  '(^|/)kubeconfig$'
  '(^|/)talosconfig$'
  '\.aws/credentials$'
  '\.npmrc$'
  '\.pypirc$'
  '\.netrc$'
)

for pattern in "${deny_patterns[@]}"; do
  if [[ "$file_path" =~ $pattern ]]; then
    echo "Blocked: $file_path matches secret-file pattern (${pattern}). Edit .claude/hooks/block-secrets.sh to adjust." >&2
    exit 2
  fi
done

exit 0
