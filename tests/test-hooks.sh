#!/usr/bin/env bash
# Block/allow tests for the guard hooks. The guards only pattern-match the command text —
# nothing below is ever executed. Exit code 1 if any case mismatches. Requires jq.
#   ./tests/test-hooks.sh
set -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../hooks" || exit 1
command -v jq >/dev/null 2>&1 || { echo "jq is required to build the test inputs"; exit 1; }
pass=0; fail=0

check() { # $1=expected BLOCK|ALLOW  $2=guard script  $3=tool_input JSON
  printf '%s' "$3" | bash "$2" >/dev/null 2>&1
  local rc=$?   # capture first: a separate `local` statement would reset $? to 0
  local got; got=$([ "$rc" -eq 2 ] && echo BLOCK || echo ALLOW)
  if [ "$got" = "$1" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL ($2): expected $1, got $got: $3"; fi
}
bash_case()   { check "$1" guard-bash.sh "$(jq -nc --arg c "$2" '{tool_input:{command:$c}}')"; }
secret_case() { check "$1" guard-secrets.sh "$(jq -nc --arg k "$2" --arg v "$3" '{tool_input:{($k):$v}}')"; }

# --- guard-bash.sh: recursive rm ---
bash_case ALLOW 'rm -rf node_modules dist'
bash_case ALLOW 'rm -rf ./build && ls .'
bash_case ALLOW 'rm -rf dist/*'
bash_case ALLOW 'rm file.txt'
bash_case BLOCK 'rm -rf /'
bash_case BLOCK 'rm -rf ~'
bash_case BLOCK 'rm -rf $HOME'
bash_case BLOCK 'sudo rm -rf /'
bash_case BLOCK 'rm -rf *'
bash_case BLOCK 'rm -fr .'
bash_case BLOCK 'rm -r ..'
bash_case BLOCK 'rm -rf ./'
bash_case BLOCK 'rm -rf ~/*'
bash_case ALLOW 'rm -rf .next'

# --- guard-bash.sh: force-push ---
bash_case BLOCK 'git push --force origin main'
bash_case BLOCK 'git push -f'
bash_case ALLOW 'git push --force-with-lease'
bash_case ALLOW 'git push origin main'

# --- guard-bash.sh: destructive SQL / DB resets ---
bash_case BLOCK 'psql -c "DROP TABLE users"'
bash_case BLOCK 'mysql -e "truncate table logs"'
bash_case ALLOW 'grep -rn "DROP TABLE" migrations/'
bash_case BLOCK 'dropdb mydb'
bash_case BLOCK 'npx prisma migrate reset'
bash_case BLOCK 'bin/rails db:drop'

# --- guard-bash.sh: printing secrets / environment ---
bash_case BLOCK 'cat .env'
bash_case BLOCK 'cat .env.local'
bash_case ALLOW 'cat .env.example'
bash_case BLOCK 'head -5 certs/server.key'
bash_case BLOCK 'tail ~/.aws/credentials'
bash_case BLOCK 'printenv'
bash_case BLOCK 'printenv DATABASE_URL'
bash_case BLOCK 'env'
bash_case ALLOW 'env CI=true pnpm test'
bash_case ALLOW 'cat README.md'
bash_case ALLOW 'npm test'

# --- guard-secrets.sh ---
secret_case BLOCK file_path .env
secret_case BLOCK file_path /app/.env
secret_case ALLOW file_path /app/.env.example
secret_case BLOCK file_path /app/.env.production
secret_case ALLOW file_path /app/src/server.ts
secret_case BLOCK file_path /app/config/secrets/db.yml
secret_case BLOCK file_path /Users/x/.ssh/id_rsa
secret_case BLOCK file_path /app/certs/server.pem
secret_case BLOCK path /app/.env.local
secret_case ALLOW glob '*.ts'

echo "hook tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
