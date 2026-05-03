#!/bin/bash
# subagentStop hook — append a JSON line per subagent completion for observability.

set -uo pipefail

input=$(cat)

audit_dir=".cursor/hooks/state"
audit_log="${audit_dir}/subagent-audit.jsonl"
mkdir -p "$audit_dir"

ts=$(date -u +%FT%TZ)

# Keep the line compact: timestamp + the original payload.
printf '%s\n' "$(jq -c --arg ts "$ts" '. + {hook_ts: $ts}' <<<"$input" 2>/dev/null || printf '{"hook_ts":"%s","raw":%s}' "$ts" "$(printf '%s' "$input" | jq -R -s .)")" >> "$audit_log"

# No follow-up by default.
echo '{}'
