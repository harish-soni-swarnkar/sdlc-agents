#!/usr/bin/env bash
# SessionStart: print a one-line repo/stack snapshot. SessionStart stdout is added to the
# session context, so `route` can tell a Java→Node migration from a Node 18→22 upgrade
# without exploring first. Read-only and quiet on failure.
set -o pipefail
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

stacks=""
scan() { # $1=dir  $2=label prefix
  local d="$1" p="$2"
  [ -f "$d/package.json" ] && stacks="$stacks ${p}node"
  { [ -f "$d/pom.xml" ] || [ -f "$d/build.gradle" ] || [ -f "$d/build.gradle.kts" ]; } && stacks="$stacks ${p}java"
  { [ -f "$d/pyproject.toml" ] || [ -f "$d/requirements.txt" ] || [ -f "$d/setup.cfg" ]; } && stacks="$stacks ${p}python"
  [ -f "$d/go.mod" ] && stacks="$stacks ${p}go"
  [ -f "$d/Cargo.toml" ] && stacks="$stacks ${p}rust"
  return 0
}
scan . ""
for d in */; do
  [ -d "$d" ] || continue
  case "$d" in node_modules/|.git/|dist/|build/|target/|vendor/|.venv/|venv/|coverage/) continue ;; esac
  scan "${d%/}" "${d%/}:"
done
stacks="${stacks# }"

nvmrc=""; [ -f .nvmrc ] && nvmrc=$(tr -d '[:space:]' < .nvmrc)
engines=""; [ -f package.json ] && command -v jq >/dev/null 2>&1 && engines=$(jq -r '.engines.node // empty' package.json 2>/dev/null)
hint=""
case " $stacks " in *java*) case " $stacks " in *node*) hint=" | hint=java+node present (possible Java→Node migration)" ;; esac ;; esac
ledger=none
[ -f .claude/state/MIGRATION_STATE.md ] && ledger=.claude/state/MIGRATION_STATE.md
[ -f .claude/state/UPGRADE_PLAN.md ] && ledger=.claude/state/UPGRADE_PLAN.md

echo "[repo] branch=$(git branch --show-current 2>/dev/null) | stacks=${stacks:-none} | node=$(node -v 2>/dev/null || echo none) | .nvmrc=${nvmrc:-none} | engines.node=${engines:-none} | last=$(git log -1 --oneline 2>/dev/null) | ledger=${ledger}${hint}"
exit 0
