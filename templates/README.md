# Project templates — deterministic enforcement & tooling

Markdown agents are *advisory*; these files are *deterministic* — the harness runs them
whether or not the model "remembers." They are **per-project** (stacks differ), so they are
**templates you copy into each repo and adapt** — not installed globally by `install.sh`.
All JSON files are **clean, valid JSON** (no comment keys), so they pass Claude Code's
schema validation as-is — this file is the documentation.

> Requires **`jq`** (hooks parse the event JSON on stdin with it).

## Install into a project
One command (from the project root, or pass its path). It copies the files, makes the hooks
executable, never overwrites an existing `settings.json` / `.mcp.json` / rules file /
`.worktreeinclude`, and refuses a destination that doesn't exist:
```
/path/to/Claude-Agents/templates/setup-project.sh [--standalone] [--git-hooks] [project-dir]
```
Pick the mode to match how the project gets the agents:
- **default — plugin companion** (`settings.json`): the project has the `sdlc-agents` plugin
  enabled. The plugin already registers the guard, format, SessionStart, and PreCompact
  hooks, so the project settings carry only what a plugin can't ship — the permissions
  deny-list and the opt-in Stop test gate. Wiring the same hooks in both places would make
  each fire twice.
- **`--standalone`** (`settings.standalone.json`): the project does NOT use the plugin
  (agents installed with `install.sh`). The project settings carry the full hook set.

Or by hand:
```
<project>/.claude/settings.json   <- from templates/settings.json (or settings.standalone.json)
<project>/.claude/hooks/*.sh      <- from ../hooks/*.sh (the plugin's hooks — single source; chmod +x)
<project>/.mcp.json               <- from templates/.mcp.json
<project>/.claude/rules/*.md      <- from templates/rules/*.md
<project>/.worktreeinclude        <- from templates/.worktreeinclude
<project>/.claude/harness/        <- from templates/harness/ (replay_golden.py + cases.example.json)
<project>/.githooks/              <- from templates/githooks/ (enable: git config core.hooksPath .githooks)
```

## Hooks and scripts — stack-aware, not hardcoded
(The full set below is what `--standalone` installs; in companion mode the plugin provides
all of it except the Stop gate.)
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

## Path-scoped rules (`rules/` → `<project>/.claude/rules/`)
`typescript.md`, `java.md`, `python.md`, `go.md` — each has a `paths:` frontmatter, so it
loads only when Claude reads or edits a matching file. In a hybrid Java→Node repo the Java
rules load for `*.java` and the TS rules for `*.ts`, instead of everything loading always.
They're a floor, not a style guide: each one defers to an existing project convention.
Plugins can't ship rules files (only projects and users can), which is why these are
templates. Delete the ones for stacks the project doesn't use.

## Golden-replay harness (`harness/` → `<project>/.claude/harness/`)
`replay_golden.py` is a dependency-free (Python 3.8+ stdlib) record/replay tool for HTTP APIs,
so `qa-test-engineer`, `migrate-stack`, and `parity-gate` don't improvise a test runner each
time:
```
python3 .claude/harness/replay_golden.py record --base-url http://localhost:8080 --cases cases.json --out golden.json
python3 .claude/harness/replay_golden.py replay --base-url http://localhost:8081 --golden golden.json
```
Write the cases (method, path, headers, body) once — see `cases.example.json`. Replay compares
status, chosen headers, and the body; JSON is compared as parsed values after dropping
volatile `json_paths` (timestamps, generated ids). A case marked `intended_difference` reports
INTENDED instead of failing. Exit 0 = all match, 1 = divergence, 2 = unreachable or bad file.

## Git hooks (`githooks/` → `<project>/.githooks/`)
The one piece of enforcement that works whichever tool made the change — Cursor, Copilot,
Codex, or a terminal — because git runs it:
- **pre-commit** refuses secret files (`.env*` except `.env.example`, keys, `secrets/`),
  edits/deletes/renames of an existing migration (new migrations are fine), and staged
  private keys or AWS access key ids.
- **pre-push** refuses a push that would rewrite the remote's history (a force-push).

`setup-project.sh --git-hooks` turns them on by setting `core.hooksPath` — only if the project
doesn't already use one (e.g. Husky or Lefthook); otherwise call the two scripts from your
existing hook setup. Bypass deliberately with `--no-verify`.

## Long-running migrations & upgrades — state that survives compaction
A Java→Node port or a Node 18→22 upgrade across many modules spans days and many context
compactions. Keep a **living ledger** in the repo so every new session/subagent resumes
with zero drift:
- `.claude/state/MIGRATION_STATE.md` (ports) or `.claude/state/UPGRADE_PLAN.md` (runtime
  upgrades), next to the golden baseline and parity results — update after each
  module/slice: completed items, target mappings, architectural decisions, known blockers.
- `migrate-stack` and `upgrade-runtime` maintain it; the PreCompact hook reminds; the
  SessionStart hook surfaces that it exists.
- Run risky upgrades and ports in a **worktree session**: start Claude with
  `claude --worktree <name>`. Everything happens on branch `worktree-<name>` under
  `.claude/worktrees/`, which you merge normally. `.worktreeinclude` (installed by
  `setup-project.sh`) copies gitignored files such as `.env` into the worktree so the app
  and tests run there.
- Per-agent `isolation: worktree` frontmatter exists, but the docs don't describe how a
  subagent's worktree changes get back to the parent (or whether plugin agents honor it),
  so this kit doesn't force it on long-running agents — the session-level worktree is the
  documented, mergeable path.

## Local overrides (per developer, gitignored)
- `<project>/CLAUDE.local.md` — personal instructions (not committed).
- `<project>/.claude/settings.local.json` — personal settings/permissions (not committed).
Add both to the project's `.gitignore`. (This bundle's own `.gitignore` already ignores
them if you version-control the folder.)

## Why these aren't global
A hook running `pnpm test` would break a Python/Go repo. Enforcement that runs commands
must match the stack — hence per-repo templates with auto-detecting scripts. Only the
secrets **deny-list** is safe globally (and it already is).
