#!/bin/bash
# sessionStart hook — inject a short stack summary into the conversation context.
# Runs fire-and-forget; the response's additional_context is attached to the
# initial system context for the session.

set -u

cat > /dev/null  # read and ignore stdin JSON

REPO_ROOT="${CURSOR_PROJECT_DIR:-$(pwd)}"
cd "$REPO_ROOT" 2>/dev/null || exit 0

stack=()

[[ -f "go.mod" ]] && stack+=("Go ($(awk '/^go / {print $2}' go.mod 2>/dev/null || echo "?"))")
[[ -f "package.json" ]] && stack+=("Node/TypeScript")
[[ -f "pyproject.toml" || -f "requirements.txt" ]] && stack+=("Python")
[[ -f "Cargo.toml" ]] && stack+=("Rust")
[[ -d "web" || -d "frontend" ]] && stack+=("Web frontend")
[[ -d "db" || -f "sqlc.yaml" || -f "sqlc.yml" ]] && stack+=("SQL/SQLC")
[[ -f "docker-compose.yml" || -f "docker-compose.yaml" || -f "compose.yaml" ]] && stack+=("Docker Compose")
[[ -d ".github/workflows" ]] && stack+=("GitHub Actions")

joined=$(IFS=", "; echo "${stack[*]}")

cat <<JSON
{
  "additional_context": "Repo stack detected: ${joined:-unknown}. Conventions live in .cursor/rules/. Skills available in .cursor/skills/. Subagents available in .cursor/agents/ — prefer delegating to them for debugging, code review, security audit, architecture review, QA strategy, performance investigation, incident response, and test running."
}
JSON
