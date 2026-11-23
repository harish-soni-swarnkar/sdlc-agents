#!/usr/bin/env bash
# PreToolUse guard for Read/Grep: blocks reading secret files (exit 2, reason on stderr).
# This is the plugin-portable stand-in for a permissions deny-list — a plugin can't ship
# settings.json permissions, but it can ship this hook.
# Works without jq (falls back to sed), so it never fails open and never blocks every Read.
set -o pipefail
input=$(cat)
field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r --arg k "$1" '.tool_input[$k] // empty'
  else
    printf '%s' "$input" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
  fi
}
for t in "$(field file_path)" "$(field path)" "$(field glob)"; do
  [ -n "$t" ] || continue
  case "$t" in
    *.env.example|*.env.sample|*.env.template) ;;
    .env|*/.env|.env.*|*/.env.*|*.env|.env\*|*/.env\*|*.pem|*.key|*.p12|*.keystore|*id_rsa|*id_ed25519|\
    .ssh|*/.ssh|*/.ssh/*|.aws|*/.aws|*/.aws/*|secrets|*/secrets|secrets/*|*/secrets/*)
      echo "Blocked: $t looks like a secrets file — reference the key name, don't read the value." >&2
      exit 2 ;;
  esac
done
exit 0
