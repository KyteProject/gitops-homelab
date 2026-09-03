#!/usr/bin/env bash
# SubagentStop hook - append a JSON line per subagent completion to a local
# audit log. Stdin carries the event JSON (session_id, cwd, hook_event_name,
# subagent type, transcript_path, etc.).

set -uo pipefail

input=$(cat)

audit_dir="${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/state"
audit_log="${audit_dir}/subagent-audit.jsonl"
mkdir -p "$audit_dir"

ts=$(date -u +%FT%TZ)

printf '%s\n' "$(jq -c --arg ts "$ts" '. + {hook_ts: $ts}' <<<"$input" 2>/dev/null \
  || printf '{"hook_ts":"%s","raw":%s}' "$ts" "$(printf '%s' "$input" | jq -R -s .)")" \
  >> "$audit_log"

exit 0
