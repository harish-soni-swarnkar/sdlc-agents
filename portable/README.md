<div align="center">

# 🌍 sdlc-agents — portable edition

**The same 29-specialist SDLC crew, as open-standard Agent Skills — for any AI coding tool.**

30 SKILL.md skills · an always-on `AGENTS.md` · git hooks that enforce · a golden-replay parity harness

[![Agent Skills](../.github/assets/badges/agent-skills.svg)](https://agentskills.io)
[![License: MIT](../.github/assets/badges/license.svg)](../LICENSE)

![Codex](../.github/assets/badges/codex.svg)
![Cursor](../.github/assets/badges/cursor.svg)
![GitHub Copilot](../.github/assets/badges/github-copilot.svg)
![Gemini CLI](../.github/assets/badges/gemini-cli.svg)
![and more](../.github/assets/badges/more-tools.svg)

[Install](#-install) · [Using it](#-using-it) · [The 30 skills](#-the-30-skills) · [What's different](#-whats-different-from-the-claude-code-edition) · [Bundled tools](#-bundled-tools) · [How it's built](#-how-its-built)

[← back to the main README](../README.md)

</div>

---

Built on **Agent Skills** — the open SKILL.md standard ([agentskills.io](https://agentskills.io)) — so it runs in Codex, Cursor, GitHub Copilot, Gemini CLI, Antigravity, OpenCode, Goose, Amp, Kiro, Claude Code, and the rest of the ~46 tools listed there. Every skill passes the **official `skills-ref` validator** in CI.

> [!TIP]
> On **Claude Code**, use the [plugin edition](../README.md) instead — it adds isolated contexts, hard read-only permissions, per-agent models, and hooks that enforce. This edition is for every other tool, and for teams that mix tools.

---

## ⚡ Install

**Recommended — the cross-agent installer** (Node 22.20+). It detects your tools, puts the skills where each one looks, and handles updates:

```bash
npx skills add harish-soni-swarnkar/sdlc-agents/portable
```

> [!IMPORTANT]
> Point it at **`/portable`**. Run against the bare repo, it finds the repo-root `skills/` folder first — the Claude Code edition's workflow commands, which depend on Claude Code subagents and won't work elsewhere.

`npx skills` installs the skills only. For the always-on rules and the git hooks, also run `install.sh` — or copy `AGENTS.md` and `githooks/` yourself.

**Without Node — `install.sh`:**

```bash
./portable/install.sh [--target agents|github|claude|all] [--global] [--git-hooks] [project-dir]
```

| Target | Folder (project · `--global`) | Read by |
|---|---|---|
| `agents` *(default)* | `.agents/skills` · `~/.agents/skills` | Codex, Cursor, GitHub Copilot CLI & coding agent, Gemini CLI, Antigravity, VS Code local sessions |
| `github` | `.github/skills` · `~/.copilot/skills` | GitHub Copilot in VS Code |
| `claude` | `.claude/skills` · `~/.claude/skills` | Claude Code — though there, the plugin edition is better |

It refreshes skills it installed before and **never overwrites** a same-named skill from anywhere else. Project installs also copy `AGENTS.md` to the project root (unless one exists) and the git hooks to `.githooks/` — add `--git-hooks` to turn them on.

### 📜 Always-on rules: `AGENTS.md`

`AGENTS.md` carries the engineering rules (verify every API exists, strict typing, test-first) and the safety rules. `install.sh` puts it at the project root, where Codex, Cursor, GitHub Copilot, VS Code, Zed, Windsurf, Amp, goose, opencode and others read it. Two exceptions:

| Tool | What to do |
|---|---|
| **Gemini CLI** | It reads `GEMINI.md` by default. Add to `.gemini/settings.json`: `{ "context": { "fileName": ["AGENTS.md", "GEMINI.md"] } }` |
| **Claude Code** | It reads `AGENTS.md` only when the project has no `CLAUDE.md`. If it has one, add a line `@AGENTS.md` to it — or use the plugin edition, which ships these rules. |

---

## 🧭 Using it

Ask for what you want and the tool picks the matching skill from its description — or name it: *"use the migrate-stack skill"* (many tools also accept `/skill-name`).

**Not sure which fits? Start with `route`.** It classifies the task, picks the skills, orders them, and sizes the gating to the risk — a fast path for small changes, the full pipeline for anything touching auth, data, APIs, infra, or a release.

> [!NOTE]
> Install the **whole set**. The coordinating skills — `route`, the gates, `ship-it`, `fix-loop`, `migrate-stack`, `upgrade-runtime` — apply other skills from the set by name.

---

## 📚 The 30 skills

| Group | Skills |
|---|---|
| 🏗️ **Build & fix** | `senior-architect` · `senior-builder` · `feature-dev` · `debugger` · `refactorer` · `onboard` |
| 🔬 **Review & quality** | `senior-auditor` · `security-reviewer` · `qa-test-engineer` · `performance-engineer` · `accessibility` |
| ⚙️ **Domain & platform** | `data-engineer` · `compliance-privacy` · `finops-cost` · `release-devops` · `sre-reliability` · `tech-writer` |
| 🚦 **Gates** | `pr-ready` · `review-gate` · `design-gate` · `hardening-gate` · `production-gate` · `parity-gate` |
| 🔁 **Pipelines** | `route` · `ship-it` · `takehome-runner` · `fix-loop` · `migrate-stack` · `upgrade-runtime` |
| 📏 **Rules** | `engineering-rules` — the same rules as `AGENTS.md`, on demand |

What each one does is in the [main README's crew tables](../README.md#-the-crew).

---

## 🔄 What's different from the Claude Code edition

Same instructions. These Claude Code mechanisms have no portable equivalent, so the portable edition handles them like this:

| Claude Code edition | Portable edition |
|---|---|
| Each agent runs in its own isolated context | Skills share the conversation's context |
| Gates hand work to separate lens agents | One agent applies each lens skill in turn, as distinct passes |
| Read-only gates and reviewers have no edit tools | "Review-only" is an instruction, not a permission |
| Per-agent model (`opus` / `sonnet`) and effort | Whatever model the tool is running |
| Hooks *enforce* the safety rules | `AGENTS.md` *states* them; the optional **git hooks** *enforce* the commit- and push-time ones — secrets, existing migrations, force-push |
| Isolated contexts keep long pipelines manageable | Long orchestrators (`migrate-stack`, `upgrade-runtime`, `ship-it`, `takehome-runner`) stop at each ledger or phase boundary, commit, and continue in a fresh conversation |
| `/sdlc-agents:<name>` workflow commands | Folded into the orchestrator skills themselves |

Both editions keep migration and upgrade ledgers in the same place (`.claude/state/`), so a team that mixes tools shares one ledger.

---

## 🧰 Bundled tools

| Tool | Where | What it does |
|---|---|---|
| 🔁 **Golden-replay harness** | `parity-gate` and `qa-test-engineer` skills (`scripts/replay_golden.py`, example cases in `assets/`) | Records an HTTP API's responses from the old system, replays them against the new one, and diffs — volatile fields ignored, approved changes marked INTENDED. Python 3.8+ standard library only. |
| 🪝 **Git hooks** | `githooks/` | **pre-commit** refuses secret files, edits to existing migrations, and staged keys; **pre-push** refuses force-pushes. Git runs them whichever tool made the change. |

---

## 🏭 How it's built

`agents/*.md` — the Claude Code edition — is the **single source of truth**. `build.py` converts each agent into a skill and rewrites the Claude-only passages (delegation, nesting depth, `claude --worktree`) into instructions any tool can follow. Every rewrite must match its source text exactly once, or the build fails — so an edited agent can't silently ship a stale skill.

```bash
python3 portable/build.py           # regenerate after changing an agent
python3 portable/build.py --check   # fail if the committed output is out of date
python3 portable/validate.py        # spec rules, no Claude-only constructs, references
```

`validate.py` checks that each skill uses only the spec's frontmatter fields, follows the `name` rules (lowercase, hyphens, matches its folder), stays within the length limits, keeps bundled files in `scripts/`, `references/`, or `assets/`, contains no Claude Code-only constructs, and names only skills that exist in the set. CI runs it on every push, together with the official **`skills-ref`** validator.

---

<div align="center">

Part of [**sdlc-agents**](../README.md) · MIT licensed

</div>
