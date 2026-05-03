#!/bin/bash
# beforeShellExecution hook — block destructive / irreversible commands,
# ask for explicit confirmation on risky ones.

set -euo pipefail

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.command // empty')

if [[ -z "$command" ]]; then
  echo '{"permission": "allow"}'
  exit 0
fi

deny() {
  local reason="$1"
  cat <<JSON
{
  "permission": "deny",
  "user_message": "Blocked: ${reason}",
  "agent_message": "Command blocked by project policy (${reason}). If this is intentional, the user can run it manually."
}
JSON
  exit 0
}

ask() {
  local reason="$1"
  cat <<JSON
{
  "permission": "ask",
  "user_message": "Risky command (${reason}). Confirm?",
  "agent_message": "This command was flagged as risky (${reason}). Pausing for user confirmation."
}
JSON
  exit 0
}

# Hard deny — irreversible and catastrophic.
if [[ "$command" =~ rm[[:space:]]+-rf?[[:space:]]+/ ]]; then
  deny "rm -rf on root-like path"
fi
if [[ "$command" =~ ^:\(\)\{ ]]; then
  deny "fork bomb pattern"
fi
if [[ "$command" =~ dd[[:space:]]+if=.*of=/dev/ ]]; then
  deny "dd to device"
fi
if [[ "$command" =~ mkfs\. ]]; then
  deny "filesystem format"
fi
if [[ "$command" =~ git[[:space:]]+push[[:space:]]+.*--force[[:space:]]+.*(main|master)[^a-zA-Z0-9] ]]; then
  deny "git push --force to main/master"
fi
if [[ "$command" =~ DROP[[:space:]]+(DATABASE|SCHEMA) ]]; then
  deny "SQL DROP DATABASE/SCHEMA"
fi

# Ask — potentially destructive, sometimes intentional.
if [[ "$command" =~ git[[:space:]]+reset[[:space:]]+--hard ]]; then
  ask "git reset --hard"
fi
if [[ "$command" =~ git[[:space:]]+clean[[:space:]]+-.*f ]]; then
  ask "git clean -f"
fi
if [[ "$command" =~ rm[[:space:]]+-rf? ]]; then
  ask "recursive rm"
fi
if [[ "$command" =~ docker[[:space:]]+(system|volume)[[:space:]]+prune ]]; then
  ask "docker prune"
fi
if [[ "$command" =~ kubectl[[:space:]]+delete ]]; then
  ask "kubectl delete"
fi
if [[ "$command" =~ terraform[[:space:]]+(destroy|apply) ]]; then
  ask "terraform destroy/apply"
fi

echo '{"permission": "allow"}'
