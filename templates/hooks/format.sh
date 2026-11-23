#!/usr/bin/env bash
# Stack-aware formatter (used by the PostToolUse hook).
# Reads the hook event JSON on stdin, formats the file just written, by extension.
# Fail-open: never blocks, skips silently if the formatter isn't installed.
set -uo pipefail
input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
[ -n "$f" ] && [ -f "$f" ] || exit 0
case "$f" in
  *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.scss|*.html|*.md|*.yaml|*.yml)
    npx --no-install prettier --write "$f" 2>/dev/null || true ;;
  *.py)   command -v ruff >/dev/null 2>&1 && ruff format "$f" 2>/dev/null || true ;;
  *.go)   command -v gofmt >/dev/null 2>&1 && gofmt -w "$f" 2>/dev/null || true ;;
  *.rs)   command -v rustfmt >/dev/null 2>&1 && rustfmt "$f" 2>/dev/null || true ;;
  *.java) command -v google-java-format >/dev/null 2>&1 && google-java-format -i "$f" 2>/dev/null || true ;;
esac
exit 0
