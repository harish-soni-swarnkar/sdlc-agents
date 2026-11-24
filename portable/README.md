# sdlc-agents — portable edition (Agent Skills)

The same 29-specialist SDLC crew as the Claude Code edition, packaged as **Agent Skills** —
the open SKILL.md standard ([agentskills.io](https://agentskills.io)) — so it runs in any
tool that supports it: Codex, Cursor, GitHub Copilot, Gemini CLI, Antigravity, OpenCode,
Goose, Amp, Kiro, Claude Code, and the rest of the ~46 clients listed on agentskills.io.

- `skills/` — 30 skills: the 29 specialists plus `engineering-rules`. Frontmatter uses only
  the spec's fields (`name`, `description`, `license`, `compatibility`, `metadata`).
- `AGENTS.md` — the always-on engineering + safety rules, for tools that read AGENTS.md.
- `install.sh` — no-Node installer. `build.py` / `validate.py` — how this folder is made
  and checked (see "How it's built").

## Install

**Recommended — the cross-agent installer** (Node 22.20+). It detects your tools, puts the
skills in each one's folder, and handles updates:
```bash
npx skills add harish-soni-swarnkar/sdlc-agents/portable
```
> Point it at **`/portable`**. Run against the bare repo, it finds the repo-root `skills/`
> folder first — those are the Claude Code edition's workflow skills, which depend on
> Claude Code subagents and won't work elsewhere.

**Without Node — `install.sh`:**
```bash
./portable/install.sh [--target agents|github|claude|all] [--global] [project-dir]
```

| Target | Folder (project · `--global`) | Read by |
|---|---|---|
| `agents` *(default)* | `.agents/skills` · `~/.agents/skills` | Codex, Cursor, GitHub Copilot CLI & coding agent, Gemini CLI, Antigravity, VS Code local sessions |
| `github` | `.github/skills` · `~/.copilot/skills` | GitHub Copilot in VS Code |
| `claude` | `.claude/skills` · `~/.claude/skills` | Claude Code — but there, use the plugin edition instead |

It refreshes skills it installed before, and never overwrites a same-named skill from
anywhere else. Project installs also copy `AGENTS.md` to the project root (unless one
exists).

## Always-on rules: `AGENTS.md`
Copy `AGENTS.md` to the project root (`install.sh` does this). It's read by Codex, Cursor,
GitHub Copilot, VS Code, Zed, Windsurf, Amp, goose, opencode, and others. Two exceptions:
- **Gemini CLI** reads `GEMINI.md` by default. Add to `.gemini/settings.json`:
  `{ "context": { "fileName": ["AGENTS.md", "GEMINI.md"] } }`
- **Claude Code** reads `AGENTS.md` only when the project has no `CLAUDE.md`. If it has
  one, add a line `@AGENTS.md` to it — or use the plugin edition, which ships these rules.

## Using it
Ask for what you want and the tool picks the matching skill from its description — or name
it ("use the migrate-stack skill"; many tools also accept `/skill-name`). Not sure which
fits? Start with **`route`**: it classifies the task, picks the skills, orders them, and
sizes the gating to the risk (fast path / standard / full pipeline).

Install the **whole set**: the coordinating skills (`route`, the gates, `ship-it`,
`fix-loop`, `migrate-stack`, `upgrade-runtime`, …) apply other skills from the set by name.

## What's different from the Claude Code edition
Same instructions, but these Claude Code mechanisms have no portable equivalent:

| Claude Code edition | Portable edition |
|---|---|
| Each agent runs in its own isolated context | Skills share the conversation's context |
| Gates hand work to separate lens agents | One agent applies each lens skill in turn, as distinct passes |
| Read-only gates/reviewers have no edit tools | "Review-only" is an instruction, not a permission |
| Per-agent model (`opus` / `sonnet`) and effort | Whatever model the tool is running |
| Hooks *enforce* the safety rules (secrets, force-push, destructive commands, immutable migrations) | `AGENTS.md` *states* them as rules — advisory only |
| `/sdlc-agents:<name>` workflow commands | Folded into the orchestrator skills themselves |

If you use Claude Code, the [plugin edition](../README.md) is the stronger choice; this
edition is for every other tool, and for mixed teams. Both editions keep migration and
upgrade ledgers in the same place (`.claude/state/`), so a team mixing tools shares one
ledger.

## How it's built
`agents/*.md` (the Claude Code edition) is the single source of truth. `build.py` converts
each agent into a skill and rewrites the Claude-only passages (delegation, nesting depth,
`claude --worktree`) into portable instructions. Every rewrite must match its source text
exactly once, or the build fails — so an edited agent can't silently ship a stale skill.

```bash
python3 portable/build.py           # regenerate after changing an agent
python3 portable/build.py --check   # fail if the committed output is out of date
python3 portable/validate.py        # spec rules + no Claude-only constructs + references
```

`validate.py` checks: only spec frontmatter fields; `name` rules (lowercase, hyphens,
matches its folder); description and compatibility lengths; files under 500 lines; no
Claude Code-only constructs; every skill a skill names exists in the set. CI also runs the
official `skills-ref` validator.
