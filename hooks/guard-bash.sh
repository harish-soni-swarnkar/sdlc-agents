#!/usr/bin/env bash
# PreToolUse guard for Bash. Blocks (exit 2, reason on stderr) the commands an automated
# fix-loop / migrate-stack run should never execute unattended:
#   - force-push (--force-with-lease is allowed)
#   - recursive rm on a root / home / wildcard target (normal paths like node_modules are fine)
#   - destructive SQL through a database client (DROP / TRUNCATE, dropdb, db:drop, migrate reset)
#   - printing secret files or the whole environment
# Fail-open if jq is missing: a missing parser shouldn't block every shell command.
set -o pipefail
input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0
block() { echo "Blocked: $1" >&2; exit 2; }

# Force-push
if printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+push' \
  && printf '%s' "$cmd" | grep -Eq -- '--force([[:space:]]|$)|[[:space:]]-f([[:space:]]|$)' \
  && ! printf '%s' "$cmd" | grep -q 'force-with-lease'; then
  block "force-push — use --force-with-lease, or run it by hand."
fi

# Recursive rm on a catastrophic target. Each rm segment is checked on its own, so
# `rm -rf ./build && ls .` is fine while `rm -rf /` or `rm -rf ~` is not.
while IFS= read -r seg; do
  [ -n "$seg" ] || continue
  printf '%s' "$seg" | grep -Eq -- '[[:space:]]-[[:alpha:]]*[rR]|--recursive' || continue
  if printf ' %s ' "$seg" | grep -Eq '[[:space:]](/|/\*|~|~/|~/\*|\$HOME|"\$HOME"|\$HOME/\*|\*|\.|\./|\.\.|\./\*)[[:space:]]'; then
    block "recursive rm on a root/home/wildcard target — run it by hand if you really mean it."
  fi
done < <(printf '%s\n' "$cmd" | grep -oE '(^|[;&|[:space:]])rm[[:space:]][^;&|]*')

# Destructive SQL via a DB client or framework CLI
if printf '%s' "$cmd" | grep -Eiq '(^|[^[:alnum:]_])(psql|mysql|mariadb|sqlite3|sqlcmd|mongosh|mongo|clickhouse-client|cockroach|snowsql|bq)([^[:alnum:]_]|$)' \
  && printf '%s' "$cmd" | grep -Eiq 'drop[[:space:]]+(table|database|schema)|truncate([[:space:]]+table)?[[:space:]]'; then
  block "destructive SQL (DROP/TRUNCATE) — write a reviewed migration with a rollback instead."
fi
if printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])dropdb[[:space:]]|db:drop|prisma[[:space:]]+migrate[[:space:]]+reset'; then
  block "database drop/reset — run it by hand if you really mean it."
fi

# Printing secrets: secret files via the shell, or the whole environment
cleaned=$(printf '%s' "$cmd" | sed -E 's/\.env\.(example|sample|template)//g')
if printf '%s' "$cleaned" | grep -Eq '(^|[;&|[:space:]])(cat|less|more|head|tail|bat|xxd|strings|od)[[:space:]][^;&|]*(\.env([.[:space:]]|$)|\.pem([[:space:]]|$)|\.key([[:space:]]|$)|id_rsa|id_ed25519|/secrets/|\.aws/credentials)'; then
  block "reading a secrets file via the shell — reference the key name, not the value."
fi
if printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])printenv([[:space:]]|$)|(^|[;&|[:space:]])env[[:space:]]*($|[;&|])'; then
  block "printing the environment can leak secrets — reference the variable name instead."
fi
exit 0
