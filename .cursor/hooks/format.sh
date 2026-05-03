#!/bin/bash
# afterFileEdit hook — run a language-appropriate formatter on the edited file.
# Fails open: formatter errors don't block the edit, they just log.

set -uo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.file_path // empty')

# Nothing to do.
if [[ -z "$file_path" || ! -f "$file_path" ]]; then
  exit 0
fi

fmt_log=".cursor/hooks/format.log"
mkdir -p "$(dirname "$fmt_log")"

log() {
  printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*" >> "$fmt_log"
}

case "$file_path" in
  *.go)
    command -v goimports >/dev/null 2>&1 && goimports -w "$file_path" 2>>"$fmt_log" || \
      command -v gofmt >/dev/null 2>&1 && gofmt -w "$file_path" 2>>"$fmt_log"
    ;;
  *.ts|*.tsx|*.js|*.jsx|*.json|*.md|*.yaml|*.yml|*.css|*.scss|*.html)
    if command -v prettier >/dev/null 2>&1; then
      prettier --write --log-level=warn "$file_path" 2>>"$fmt_log"
    elif [[ -f package.json ]] && jq -e '.devDependencies.prettier // .dependencies.prettier' package.json >/dev/null 2>&1; then
      npx --no-install prettier --write --log-level=warn "$file_path" 2>>"$fmt_log"
    fi
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then
      ruff format "$file_path" 2>>"$fmt_log"
      ruff check --fix --quiet "$file_path" 2>>"$fmt_log"
    elif command -v black >/dev/null 2>&1; then
      black --quiet "$file_path" 2>>"$fmt_log"
    fi
    ;;
  *.rs)
    command -v rustfmt >/dev/null 2>&1 && rustfmt --quiet "$file_path" 2>>"$fmt_log"
    ;;
  *.sql)
    command -v sqlfluff >/dev/null 2>&1 && sqlfluff format --quiet "$file_path" 2>>"$fmt_log" || true
    ;;
  *.sh|*.bash)
    command -v shfmt >/dev/null 2>&1 && shfmt -w -i 2 -ci "$file_path" 2>>"$fmt_log"
    ;;
esac

exit 0
