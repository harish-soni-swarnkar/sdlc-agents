#!/usr/bin/env bash
# Runs templates/githooks/pre-commit and pre-push against throwaway git repos (in a temp
# dir) and checks what they allow and refuse. Fake secrets are assembled at runtime so no
# key-shaped string ever appears in this file. Exit 1 on any mismatch.
set -uo pipefail
HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../templates/githooks" && pwd)"
work=$(mktemp -d)
pass=0; fail=0
expect() { # $1=allow|refuse  $2=description  $3...=command
  local want="$1" what="$2"; shift 2
  if "$@" >/dev/null 2>&1; then got=allow; else got=refuse; fi
  if [ "$got" = "$want" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: expected $want, got $got — $what"; fi
}

repo="$work/repo"; remote="$work/remote.git"
git init -q "$repo" && git init -q --bare "$remote"
cd "$repo"
git config user.email t@example.com && git config user.name tester
git config core.hooksPath "$HOOKS"
git remote add origin "$remote"

c() { git add -A && git commit -q -m "$1"; }

echo hi > README.md;                       expect allow  "ordinary file"            c "readme"
echo 'X=1' > .env;                          expect refuse ".env"                      c "env"
git reset -q .env && rm .env
echo 'X=' > .env.example;                   expect allow  ".env.example"              c "example"
mkdir -p config && echo k > config/server.pem; expect refuse "*.pem"                  c "pem"
git reset -q config/server.pem; rm config/server.pem
mkdir -p db/migrations && echo 'create table a();' > db/migrations/001_init.sql
                                            expect allow  "new migration"             c "m1"
echo '-- edit' >> db/migrations/001_init.sql; expect refuse "edit existing migration"  c "edit m1"
git checkout -q HEAD -- db/migrations/001_init.sql   # restore index AND worktree from HEAD
git rm -q db/migrations/001_init.sql || { echo "setup failed: git rm"; exit 1; }
[ "$(git diff --cached --name-status)" = "D	db/migrations/001_init.sql" ] || { echo "setup failed: delete not staged"; exit 1; }
                                            expect refuse "delete existing migration" git commit -q -m "rm m1"
git checkout -q HEAD -- db/migrations/001_init.sql
echo 'create table b();' > db/migrations/002_add_b.sql; expect allow "second new migration" c "m2"
printf '%s\n' "-----BEGIN RSA PRIV""ATE KEY-----" > notes.txt; expect refuse "private key content" c "key"
git reset -q notes.txt; rm notes.txt
printf 'id=%s\n' "AKIA""ABCDEFGHIJKLMNOP" > cfg.txt; expect refuse "AWS access key id" c "aws"
git reset -q cfg.txt; rm cfg.txt

branch=$(git symbolic-ref --short HEAD)
expect allow  "push a new branch"         git push -q origin "$branch"
echo more >> README.md && c "more"
expect allow  "fast-forward push"         git push -q origin "$branch"
git commit -q --amend -m "rewritten"
expect refuse "force-push (history rewrite)" git push -q --force origin "$branch"

echo "githook tests: $pass passed, $fail failed  (scratch repos in $work)"
[ "$fail" -eq 0 ]
