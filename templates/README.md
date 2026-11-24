<div align="center">

# 🧰 Per-project kit

**Deterministic guardrails and tooling for any repo — one command, nothing overwritten.**

Hooks that *enforce* · a golden-replay parity harness · git hooks for every tool · path-scoped rules · pinned MCP servers

[![License: MIT](../.github/assets/badges/license.svg)](../LICENSE)
[![Claude Code plugin](../.github/assets/badges/claude-code-plugin.svg)](../README.md#-quick-start)

[What you get](#-what-you-get) · [Install](#-install) · [Hooks](#-hooks-that-enforce) · [Harness](#-golden-replay-harness) · [Git hooks](#-git-hooks) · [Rules](#-path-scoped-rules) · [Long migrations](#-long-running-migrations--upgrades)

[← back to the main README](../README.md)

</div>

---

Agent instructions are *advisory*. Everything here is *deterministic*: Claude Code or git runs it whether or not the model "remembers". It's **per-project** because test, format, and lint commands differ by stack, so each repo gets its own copy, adapted to it.

> [!NOTE]
> Requires **`jq`** (the hooks read their event JSON with it). All JSON files are clean, valid JSON with no comment keys, so they pass Claude Code's schema validation as-is.

---

## ✨ What you get

| Piece | What it does | Works in |
|---|---|---|
| 🔒 **Hooks & settings** | Block secret reads, force-push, destructive commands, edits to existing migrations; auto-format; optional "tests must pass" gate | Claude Code |
| 🔁 **Golden-replay harness** | Record an HTTP API's responses, replay them against the new system, diff — the parity oracle for ports and upgrades | Anywhere (Python 3.8+) |
| 🪝 **Git hooks** | Refuse committing secrets or keys, editing an existing migration, and force-pushing | **Any tool** — git runs them |
| 🧭 **Path-scoped rules** | TS/JS, Java, Python, Go conventions that load only for matching files | Claude Code |
| 🔌 **`.mcp.json`** | Pinned context7 (live library docs) + Playwright (real browser checks) | Claude Code |
| 🌳 **`.worktreeinclude`** | Copies `.env`-style files into a worktree session so the app runs there | Claude Code |

---

## ⚡ Install

From the project root (or pass its path):

```bash
/path/to/sdlc-agents/templates/setup-project.sh [--standalone] [--git-hooks] [project-dir]
```

It copies the files and makes the scripts executable. It **never overwrites** an existing `settings.json`, `.mcp.json`, rules file, or `.worktreeinclude`, and it refuses a destination that doesn't exist.

| Option | Use it when |
|---|---|
| *(default)* — **plugin companion** | The project has the `sdlc-agents` plugin enabled. The plugin already registers the guard, format, session-start, and pre-compact hooks, so the project settings add only what a plugin can't ship: the permissions deny-list and the opt-in test gate. *(Wiring the same hooks in both places would make each fire twice.)* |
| `--standalone` | The project does **not** use the plugin (agents installed with `install.sh`). The project settings carry the full hook set. |
| `--git-hooks` | Also turn on the git hooks, by setting `core.hooksPath` — only if the project doesn't already use one, so an existing Husky or Lefthook setup is left alone. |

<details>
<summary><b>Install by hand instead</b></summary>

```text
<project>/.claude/settings.json   <- templates/settings.json  (or settings.standalone.json)
<project>/.claude/hooks/*.sh      <- ../hooks/*.sh            (the plugin's hooks — single source; chmod +x)
<project>/.mcp.json               <- templates/.mcp.json
<project>/.claude/rules/*.md      <- templates/rules/*.md
<project>/.worktreeinclude        <- templates/.worktreeinclude
<project>/.claude/harness/        <- templates/harness/        (replay_golden.py + cases.example.json)
<project>/.githooks/              <- templates/githooks/       (enable: git config core.hooksPath .githooks)
```

</details>

---

## 🔒 Hooks that enforce

The hooks call scripts from the plugin's `hooks/` folder, so one template works for Node, Python, Java, Go, and Rust — even several side by side in a mid-migration repo. This is the full set `--standalone` installs; in companion mode the plugin provides all of it except the test gate.

| When | Script | What it does | If `jq` is missing |
|---|---|---|---|
| Before Edit / Write | `guard-edit.sh` | Blocks edits to `.env*` (not `.env.example`), lockfiles, and existing migrations — new migrations are fine | Still works (sed fallback) |
| Before Read / Grep | `guard-secrets.sh` | Blocks reading secret files and folders (`.env*`, keys, `~/.ssh`, `~/.aws`, `secrets/`) | Still works (sed fallback) |
| Before Bash | `guard-bash.sh` | Blocks force-push, recursive `rm` on `/` `~` or wildcards, `DROP`/`TRUNCATE` through a DB client, `dropdb` / `db:drop` / `prisma migrate reset`, and printing secrets or the environment | Lets the command through |
| After Edit / Write | `format.sh` | Formats the file by type — prettier · ruff · gofmt · rustfmt · google-java-format | Never blocks |
| Session start | `session-start.sh` | One-line snapshot: branch, detected stacks, Node / `.nvmrc` / `engines.node`, last commit, ledger — and a hint when Java and Node coexist | — |
| Before compaction | *(inline)* | Reminds Claude to flush the migration/upgrade ledger so long jobs don't lose decisions | — |
| Turn end *(opt-in)* | `verify.sh` | Runs every detected stack's typecheck and tests and **blocks "done" until green** | — |

The test gate is hardened two ways. It won't loop: it exits cleanly if it already blocked once (`stop_hook_active`). And it skips turns with no file changes, so a plain question never triggers the test suite.

The settings also carry a **permissions deny-list** that blocks Read, Grep, and shell access to `.env*`, keys, and `secrets/` (`.env.example` stays readable). It's worth adding the same list to your user-level `~/.claude/settings.json` too, since it's the one guard that's safe in every project.

> [!TIP]
> If the defaults don't fit a project, edit `verify.sh` and `format.sh`. They're ordinary shell scripts.

> [!WARNING]
> Hooks run shell commands automatically. Read them before enabling them in a project.

---

## 🔁 Golden-replay harness

`replay_golden.py` (standard library only) records what the **old** system returns and diffs the **new** one against it. That gives `qa-test-engineer`, `migrate-stack`, and `parity-gate` a ready-made parity oracle instead of a test runner improvised each time.

```bash
python3 .claude/harness/replay_golden.py record --base-url http://localhost:8080 --cases cases.json --out golden.json
python3 .claude/harness/replay_golden.py replay --base-url http://localhost:8081 --golden golden.json
```

- Write the cases once (method, path, headers, body) — see `cases.example.json`.
- Replay compares **status, chosen headers, and the body**. JSON is compared as parsed values after dropping volatile fields such as timestamps and generated ids.
- A case marked `intended_difference` reports **INTENDED** instead of failing — that's how approved changes from the ledger stay visible.

| Exit code | Meaning |
|---|---|
| `0` | every case matches (or is intended) |
| `1` | at least one divergence |
| `2` | a system couldn't be reached, or a bad cases/golden file |

---

## 🪝 Git hooks

The one guardrail that works **whichever tool made the change** — Cursor, Copilot, Codex, or a terminal — because git runs it.

| Hook | Refuses |
|---|---|
| **pre-commit** | Secret files (`.env*` except `.env.example`, keys, `secrets/`) · edits, deletes, or renames of an existing migration (new ones are fine) · staged private keys or AWS access key ids |
| **pre-push** | A push that would rewrite the remote's history — a force-push |

Turn them on with `setup-project.sh --git-hooks`. If the project already uses Husky or Lefthook, call `.githooks/pre-commit` and `.githooks/pre-push` from that setup instead. To bypass deliberately, use `--no-verify`.

---

## 🧭 Path-scoped rules

`typescript.md` · `java.md` · `python.md` · `go.md` — each has a `paths:` frontmatter, so it loads **only when Claude reads or edits a matching file**. In a hybrid Java → Node repo, the Java rules apply to `*.java` and the TS rules to `*.ts`, instead of everything loading all the time.

They're a minimum standard, not a style guide: each one defers to the project's existing conventions. Delete the ones for stacks you don't use. *(Plugins can't ship rules files — only projects and users can — which is why these are templates.)*

---

## 🔌 MCP servers

| Server | Version | What it's for |
|---|---|---|
| **context7** | `@upstash/context7-mcp@4.7.3` | Live, version-correct library docs — code-gen works from real signatures, not memory |
| **playwright** | `@playwright/mcp@0.0.86` | A real browser, for `qa-test-engineer` and `accessibility` checks |

Both are pinned and verified on npm. Bump the versions deliberately.

---

## 🧠 Long-running migrations & upgrades

A Java → Node port or a Node 18 → 22 upgrade can span days and many context compactions. A **living ledger** in the repo lets every new session resume with zero drift:

- **The ledger** — `.claude/state/MIGRATION_STATE.md` (ports) or `.claude/state/UPGRADE_PLAN.md` (upgrades), next to the golden baseline and parity results. `migrate-stack` and `upgrade-runtime` keep it current; the pre-compact hook reminds; the session-start hook shows that it exists. Reference skeletons live in `state/`.
- **Run it in a worktree session** — start Claude with `claude --worktree <name>`. Everything lands on branch `worktree-<name>`, which you merge normally, and `.worktreeinclude` brings in `.env` and similar files so the app and tests run there.

<details>
<summary><b>Why not per-agent worktree isolation?</b></summary>

Agents can declare `isolation: worktree`, but the docs don't describe how a subagent's worktree changes get back to the parent, or whether plugin agents honor it. So this kit doesn't force it on long-running agents — the session-level worktree is the documented path, and its result is a branch you merge normally.

</details>

---

## 🏠 Local overrides

Per-developer files that should **never** be committed:

- `<project>/CLAUDE.local.md` — personal instructions
- `<project>/.claude/settings.local.json` — personal settings and permissions

Add both to the project's `.gitignore`.

---

## ❓ Why per-project, not global

A hook that runs `pnpm test` would break a Python or Go repo. Anything that runs commands has to match the stack, so it lives in each repo, driven by scripts that detect the stack. The one piece that's safe everywhere is the secrets **deny-list**, which is worth adding to your user-level settings as well.

---

<div align="center">

Part of [**sdlc-agents**](../README.md) · MIT licensed

</div>
