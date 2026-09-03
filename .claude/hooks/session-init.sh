#!/usr/bin/env bash
# SessionStart hook - print a short stack summary to stdout. Claude Code
# attaches stdout (on exit 0) to the session context.
# Input on stdin: { "session_id", "cwd", "hook_event_name", "source" }.

set -u

cat > /dev/null  # read and ignore stdin JSON

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$REPO_ROOT" 2>/dev/null || exit 0

stack=()

[[ -f "go.mod" ]] && stack+=("Go ($(awk '/^go / {print $2}' go.mod 2>/dev/null || echo "?"))")
[[ -f "package.json" ]] && stack+=("Node/TypeScript")
[[ -f "pyproject.toml" || -f "requirements.txt" ]] && stack+=("Python")
[[ -f "Cargo.toml" ]] && stack+=("Rust")
[[ -d "web" || -d "frontend" ]] && stack+=("Web frontend")
[[ -d "db" || -f "sqlc.yaml" || -f "sqlc.yml" ]] && stack+=("SQL/SQLC")
[[ -f "docker-compose.yml" || -f "docker-compose.yaml" || -f "compose.yaml" || -f "deploy/compose/docker-compose.yml" ]] && stack+=("Docker Compose")
[[ -d ".github/workflows" ]] && stack+=("GitHub Actions")

joined=$(IFS=", "; echo "${stack[*]}")

cat <<EOF
Repo stack detected: ${joined:-unknown}.

Project conventions live in .claude/rules/ (path-scoped where applicable).
Skills available in .claude/skills/.
Subagents available in .claude/agents/ - prefer delegating to them for debugging,
code review, security audit, architecture review, QA strategy, performance
investigation, incident response, and test running.
EOF
