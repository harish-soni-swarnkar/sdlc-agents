# Project templates — deterministic enforcement & tooling

Markdown agents are *advisory*; these files are *deterministic* — the harness runs them
whether or not the model "remembers." They are **per-project** (stacks differ), so they are
**templates you copy into each repo and adapt** — not installed globally by `install.sh`.
Both JSON files are **clean, valid JSON** (no comment keys), so they pass Claude Code's
schema validation as-is — this file is the documentation.

> Requires **`jq`** (hooks parse the event JSON on stdin with it).

## Install into a project
One command (from the project root, or pass its path) — copies the files and makes the
hooks executable, without clobbering an existing `settings.json` / `.mcp.json`:
```
/path/to/Claude-Agents/templates/setup-project.sh [project-dir]
```
Or by hand:
```
<project>/.claude/settings.json   <- from templates/settings.json
<project>/.claude/hooks/*.sh      <- from ../hooks/*.sh (the plugin's hooks — single source; chmod +x)
<project>/.mcp.json               <- from templates/.mcp.json
```

## `settings.json` + hook scripts — stack-aware, not hardcoded
The hooks call scripts from the plugin's `hooks/` folder (copied into the project), so the
same template works for Node, Python, Java, Go, Rust — and for a **polyglot /
mid-migration tree** (e.g. a Java sidecar beside a new Node service) it checks **all**
stacks present, not just one.

- **permissions.deny** — blocks `Read` **and `Grep`** on `.env*`, keys, secrets.
  (`.env.example` stays readable.) Mirrored globally in `~/.claude/settings.json`.
- **PreToolUse, Edit|Write (fail-closed)** — blocks edits to `.env*` (not `.env.example`),
  lockfiles, and already-tracked migrations (new migrations are allowed). If `jq` is
  missing it **blocks** rather than letting edits through.
- **PreToolUse, Read|Grep → `guard-secrets.sh`** — blocks reading secret files. Works
  without `jq` (sed fallback), so it neither fails open nor blocks every Read.
- **PreToolUse, Bash → `guard-bash.sh`** — blocks force-push (`--force-with-lease` is
  allowed), recursive `rm` on root/home/wildcard targets, DROP/TRUNCATE through a DB client,
  `dropdb`/`db:drop`/`prisma migrate reset`, and printing secret files or the environment.
  Fail-open if `jq` is missing.
- **PostToolUse → `hooks/format.sh`** — formats the written file by extension
  (prettier · ruff · gofmt · rustfmt · google-java-format). Fail-open, never blocks.
- **Stop → `hooks/verify.sh`** — detects every stack present and runs each one's
  typecheck/tests; **blocks completion (exit 2) until green**. Hardened:
  - **loop-protection** — exits 0 if `stop_hook_active` is already true (no infinite loop);
  - **no-op skip** — exits 0 when not a git repo or `git status --porcelain` is empty
    (pure Q&A turns don't trigger the suite).
- **SessionStart → `session-start.sh`** — injects a one-line snapshot (branch, stacks
  detected at root and depth-1, Node / `.nvmrc` / `engines.node`, last commit, ledger, and a
  hint when Java and Node coexist) so `route` can classify the work immediately.
- **PreCompact** — reminds Claude to flush the migration/upgrade ledger before the context
  is compacted, so long jobs don't lose decisions.

Edit `verify.sh` / `format.sh` to match the project's exact commands if the defaults don't
fit; they're ordinary shell scripts.

## `.mcp.json`
- **context7** (`@upstash/context7-mcp@4.7.3`) — live library/API docs in context (grounds
  code-gen in real signatures).
- **playwright** (`@playwright/mcp@0.0.86`) — real browser for `qa-test-engineer` /
  `accessibility`.
Both verified on the npm registry and pinned; bump the versions deliberately.

## Long-running migrations & upgrades — state that survives compaction
A Java→Node port or a Node 18→22 upgrade across many modules spans days and many context
compactions. Keep a **living ledger** in the repo so every new session/subagent resumes
with zero drift:
- `MIGRATION_STATE.md` (ports) or `UPGRADE_PLAN.md` (runtime upgrades) — update after each
  module/slice: completed items, target mappings, architectural decisions, known blockers.
- `migrate-stack` and `upgrade-runtime` maintain it; the PreCompact hook reminds; the
  SessionStart hook surfaces that it exists.
- Run risky upgrades in an **isolated git worktree** (`--worktree`, or an agent with
  `isolation: "worktree"`) so a broken dependency never dirties the main tree.

## Local overrides (per developer, gitignored)
- `<project>/CLAUDE.local.md` — personal instructions (not committed).
- `<project>/.claude/settings.local.json` — personal settings/permissions (not committed).
Add both to the project's `.gitignore`. (This bundle's own `.gitignore` already ignores
them if you version-control the folder.)

## Why these aren't global
A hook running `pnpm test` would break a Python/Go repo. Enforcement that runs commands
must match the stack — hence per-repo templates with auto-detecting scripts. Only the
secrets **deny-list** is safe globally (and it already is).
