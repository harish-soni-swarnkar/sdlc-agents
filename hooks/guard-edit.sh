#!/usr/bin/env bash
# PreToolUse guard for Edit/Write: blocks changes to secret files, lockfiles, and
# already-tracked migrations (exit 2, reason on stderr). New migrations are allowed —
# migrations are append-only. Works without jq (sed fallback), so it never needs to fail
# closed on every edit.
set -o pipefail
input=$(cat)
field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r --arg k "$1" '.tool_input[$k] // empty'
  else
    printf '%s' "$input" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
  fi
}
f=$(field file_path)
[ -n "$f" ] || exit 0
case "$f" in
  *.env.example|*.env.sample|*.env.template) exit 0 ;;
  .env|*/.env|.env.*|*/.env.*|*.env)
    echo "Blocked: $f is a secrets file — change it by hand." >&2; exit 2 ;;
  *-lock.json|*-lock.yaml|*.lock|npm-shrinkwrap.json|*/npm-shrinkwrap.json)
    echo "Blocked: $f is a lockfile — regenerate it with the package manager instead." >&2; exit 2 ;;
  migrations/*|*/migrations/*)
    # Ask the file's own repo (works for worktrees and paths outside the hook's cwd).
    if git -C "$(dirname "$f")" ls-files --error-unmatch -- "$(basename "$f")" >/dev/null 2>&1; then
      echo "Blocked: $f is an existing (tracked) migration — migrations are immutable, create a new one instead." >&2
      exit 2
    fi ;;
esac
exit 0
