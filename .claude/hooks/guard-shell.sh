#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash) - block destructive / irreversible commands,
# escalate risky ones to a permission prompt.
#
# Output protocol (Claude Code):
#   exit 2 + stderr  -> block the command, message goes to Claude
#   stdout JSON      -> structured decision; we use this for "ask"
#   exit 0 silent    -> allow

set -euo pipefail

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')

if [[ -z "$command" ]]; then
  exit 0
fi

deny() {
  local reason="$1"
  echo "Blocked by project policy: ${reason}. If this is intentional, the user can run it manually." >&2
  exit 2
}

ask() {
  local reason="$1"
  jq -nc --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: ("Risky command (" + $reason + "). Confirm before running.")
    }
  }'
  exit 0
}

# Hard deny - irreversible and catastrophic.
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

# Ask - potentially destructive, sometimes intentional.
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

exit 0
