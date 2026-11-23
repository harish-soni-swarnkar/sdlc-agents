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
<project>/.claude/settings.json      <- from templates/settings.json
<project>/.claude/hooks/verify.sh    <- from templates/hooks/verify.sh   (chmod +x)
<project>/.claude/hooks/format.sh    <- from templates/hooks/format.sh   (chmod +x)
<project>/.mcp.json                  <- from templates/.mcp.json
```

## `settings.json` + `hooks/` — stack-aware, not hardcoded
The hooks call two **auto-detecting** scripts, so the same template works for Node, Python,
Java, Go, Rust — and for a **polyglot / mid-migration tree** (e.g. a Java sidecar beside a
new Node service) it checks **all** stacks present, not just one.

- **permissions.deny** — blocks `Read` **and `Grep`** on `.env*`, keys, secrets.
  (`.env.example` stays readable.) Mirrored globally in `~/.claude/settings.json`.
- **PreToolUse (fail-closed)** — blocks edits to protected paths (`.env*`, lockfiles,
  `migrations/`). If `jq` is missing it **blocks** rather than letting edits through.
- **PostToolUse → `hooks/format.sh`** — formats the written file by extension
  (prettier · ruff · gofmt · rustfmt · google-java-format). Fail-open, never blocks.
- **Stop → `hooks/verify.sh`** — detects every stack present and runs each one's
  typecheck/tests; **blocks completion (exit 2) until green**. Hardened:
  - **loop-protection** — exits 0 if `stop_hook_active` is already true (no infinite loop);
  - **no-op skip** — exits 0 when not a git repo or `git status --porcelain` is empty
    (pure Q&A turns don't trigger the suite).
- **SessionStart** — injects lightweight repo health (branch, Node/Python version, last
  commit, whether a migration/upgrade ledger exists) as the session opens.
- **PreCompact** — reminds Claude to flush the migration/upgrade ledger before the context
  is compacted, so long jobs don't lose decisions.

Edit `verify.sh` / `format.sh` to match the project's exact commands if the defaults don't
fit; they're ordinary shell scripts.

## `.mcp.json`
- **context7** — live library/API docs in context (grounds code-gen in real signatures).
- **playwright** — real browser for `qa-test-engineer` / `accessibility`.
Verify package names and pin versions before relying on them.

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
