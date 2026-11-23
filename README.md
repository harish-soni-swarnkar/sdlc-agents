# Claude-Agents — a full SDLC agent crew

A portable set of **Claude Code subagents** that cover the whole software lifecycle —
design, build (new *and* existing code), debugging, refactoring, the review lenses and
the gates that combine them, data, security, performance, accessibility, compliance,
cost, operations, release, docs, and the pipelines that chain it all end to end.

They are **true siblings**: every one shares the same standing bar and the same hard
rules, so you can compose them freely and trust the output.

- **Live location (what Claude Code runs):** `~/.claude/agents/`
- **This folder:** the portable master copy — edit here, run `./install.sh` to deploy.

---

## Status & caveats (honest)

**Verified (machine-checked):** all JSON valid; all shell scripts pass `bash -n`; the hook
guards pass the full suite in `tests/test-hooks.sh` (45 block/allow cases, including the
recursive-`rm` guard), and `guard-secrets.sh` was also run with no `jq` on PATH to exercise
its fallback; `session-start.sh` was run
on a real repo, a polyglot repo, and a non-git dir; every agent's frontmatter parses with a
matching `name` and a `model`; the 6 gates and the 2 reviewers have no edit tools;
delegation uses the current `Agent` tool name; `route` references every agent; the MCP
packages exist on npm and are pinned (`@upstash/context7-mcp@4.7.3`,
`@playwright/mcp@0.0.86`). One agent (`senior-auditor`) was smoke-tested end-to-end on a
real repo.

**Not yet done — do before relying on it:** run `claude plugin validate .` (and `--strict`
in CI) — the CLI wasn't available where this was built; exercise the hooks and the
slash-command skills inside a real Claude Code session. The other 28 agents are authored and structurally validated but not each run live.
The verify/format scripts are stack-detecting defaults — adapt the commands per project.

## Install

This bundle is a **native Claude Code plugin** *and* works via a manual script — pick one.

### A) As a plugin (recommended for teams / multiple machines)
It has `.claude-plugin/plugin.json` (name: **`sdlc-agents`**), so Claude Code discovers
`agents/`, `hooks/hooks.json`, and `skills/` automatically. Install it through a plugin
marketplace / `claude plugin` (validate first with `claude plugin validate .`). Components
are **namespaced** under the plugin, so you invoke e.g. `sdlc-agents:route`.
- Agents load from `agents/*.md`; the guardrail hooks from `hooks/hooks.json`; the workflow
  slash commands and the global engineering rules from `skills/` (a plugin-root `CLAUDE.md`
  isn't loaded, so in plugin mode the rules are the **`engineering-rules` skill**);
  **context7** (live library docs) from the root `.mcp.json`.
- A plugin can't ship a `permissions` deny-list, so the plugin ships hooks that do the same
  job: `guard-secrets.sh` blocks Read/Grep of secret files and `guard-bash.sh` blocks
  printing them via the shell. A deny-list in `~/.claude/settings.json` or a project's
  `settings.json` still adds a second layer.

### B) Manual / global (simplest for solo use)
```bash
./install.sh
```
Copies `agents/*.md` into `~/.claude/agents/` (flat, un-namespaced — invoke as `route`),
installs the README there, and installs the always-on rules to `~/.claude/CLAUDE.md`
(only if one isn't already there — never clobbers). Re-run any time; new agents are picked
up automatically.

Package the kit for sharing — only from a clean, committed tree. It runs the hook tests
and `claude plugin validate . --strict`, then zips HEAD with `git archive` (tracked files
only, so local files never leak). Without the `claude` CLI it refuses unless you pass
`--skip-validate`:
```bash
./release.sh
```

Then in any Claude Code chat:

```
Use the <agent-name> agent. <your target + context>
```

---

## The shared standing bar

Every agent holds the same line, so quality doesn't depend on which one you call:

- **Verify by running** — claim only what was actually executed; paste real output.
- **No hallucination · no overcommit · no bypassing** — real findings only, stay in
  scope, fix root causes (never stub/skip/loosen to look green).
- **Evidence** — findings cite `file:line` / repro / a number, with a confidence tag.
- **Ask before anything irreversible.**
- **Incremental commits, real messages, no attribution/co-author lines.**
- **Terse WHY-comments**, no change-log narration.

---

## AI code-gen discipline (all languages)

Three rules that prevent hallucinated code and enforce type safety — the code-writing
agents **apply** them, the auditor **checks** them, and they're also set globally in
`~/.claude/CLAUDE.md` (Claude Code's `.cursorrules` equivalent, auto-loaded everywhere):

1. **Context anchoring** — before using any interface, type, schema, function, flag, or
   library symbol, confirm it exists and get its real signature from the codebase or
   official docs. Never invent or guess an API.
2. **Strict typing** — the language's strictest checking, explicit types at every
   boundary/return, no untyped escape hatches (TS `strict`/no `any`; Python hints +
   mypy/pyright strict; Go/Rust/Java/C#/… types enforced; dynamic langs validate at the
   boundary with schemas/assertions).
3. **Test-first verification** — define the interface/contract and tests first, implement
   to green, and **run the tests** — passing tests are the proof, not an assertion.

---

## The lifecycle

```
          design-gate                               production-gate
       (validate the plan)                      (full battery + proof)
             │                                          ▲
             ▼                                          │
  senior-architect ─► senior-builder ─► review-gate ─► hardening-gate ─► SHIP
     (design)            (build new)    (3-lens +      (security + ops
                                         conditional)    + conditional)
                                            │
  feature-dev ───────────────────────────► │   (change/feature on existing code)
     (brownfield)                           ▼
                                        fix-loop
                                   (fix findings + re-verify)

  pr-ready = fast diff check, anytime before committing
  debugger · refactorer · performance-engineer · data-engineer · accessibility ·
  compliance-privacy · finops-cost · release-devops · sre-reliability · tech-writer
            = specialists you call directly as the work needs them
```

---

## Specialists (do one job)

### Core — build & fix

| Agent | Use it to… | Writes code? |
|---|---|---|
| **senior-architect** | shape the problem before code: requirements, trade-offs, design, ADRs, scale | no |
| **senior-builder** | build a **new** app from a brief to the full bar: tested, documented | yes |
| **feature-dev** | add a feature / change on an **existing** codebase — smallest idiomatic diff | yes |
| **debugger** | root-cause a bug / crash / flaky test / incident, fix the cause + add a regression test | yes (fix) |
| **refactorer** | pay down debt, run migrations & dependency/framework upgrades — behavior-preserving | yes |
| **onboard** | map an unfamiliar/legacy repo before editing → writes ARCHITECTURE.md inventory | doc only |

### Review & quality lenses

| Agent | Use it to… | Writes code? |
|---|---|---|
| **senior-auditor** | broad code-quality / design / SDLC review by reading the code | never (no edit tools) |
| **security-reviewer** | defensive security + STRIDE: OWASP, authz, secrets, supply chain (CVEs, licenses, deprecated packages) | never (no edit tools) |
| **qa-test-engineer** | adversarial testing — break it: edge cases, concurrency, crash/resume; failing tests | tests |
| **performance-engineer** | latency, throughput, bottlenecks, memory leaks, N+1, scale cliffs — measure then optimize | opt. |
| **accessibility** | WCAG 2.2 AA: keyboard, screen reader, contrast, focus, forms, motion | opt. |

### Domain & platform

| Agent | Use it to… | Writes code? |
|---|---|---|
| **data-engineer** | schema design, safe migrations, indexing & query tuning, integrity, transactions | yes |
| **compliance-privacy** | GDPR/DPDP/CCPA/HIPAA/PCI: PII mapping, consent, retention/deletion, rights (advisory) | no* |
| **finops-cost** | cloud spend: right-sizing, waste, egress/storage, commitments, guardrails (advisory) | opt. |
| **release-devops** | CI/CD pipelines, release strategy, rollback, IaC, Dependabot/Renovate | yes |
| **sre-reliability** | production readiness: observability, deploy/rollback, SLOs, runbooks, recovery | ops cfg |
| **tech-writer** | README / HLD / LLD / DECISIONS / API docs + the extend-me handover doc | docs |

\* review-only by default; applies fixes only if you explicitly ask. The two code
reviewers (`senior-auditor`, `security-reviewer`) have no edit tools at all — their fixes go
through `fix-loop`.

---

## Orchestrators (compose the specialists)

### Gates — read-only, give a verdict (pick by weight)

| Agent | Runs | Verdict |
|---|---|---|
| **pr-ready** | light auditor + QA, **diff only** — the fast lane | READY / NOT-READY |
| **review-gate** | auditor + security + QA (+ data / accessibility when the change touches them) | PASS / CONDITIONAL / FAIL |
| **design-gate** | architect + security (+ data / compliance when the design calls for it), pre-build | PROCEED / REVISE |
| **hardening-gate** | security + sre (+ release-devops / compliance / finops when the launch calls for it) | GO / NO-GO |
| **production-gate** | **full battery** (auditor + security + QA + performance + sre) **+ conditional lenses** (data, compliance, accessibility, finops, release-devops) **+** verifies tests/coverage/build/lint/typecheck/dep-vuln-scan/secrets/CI actually pass | READY / CONDITIONAL / NOT-READY |
| **parity-gate** | the golden/characterization suite run against **both** old & new (or source & target), diffing behavior | PARITY-HELD / DIVERGENCES-FOUND |

Conditional lenses run **only when they apply** — no auditing accessibility on an API
with no UI, or compliance on a system with no personal data. Each gate states which it
ran and which it skipped.

### Pipelines & loops — write-capable

| Agent | Chains | For |
|---|---|---|
| **ship-it** | architect → builder → review-gate → sre → tech-writer | a **new** project, brief → shipped repo |
| **takehome-runner** | ship-it + rubric focus + deliverables (zip, conceptualisation.md, transcript reminder) | graded **take-home** exercises |
| **feature-dev** | understand → change → test → docs → self-gate | a **change** on existing code |
| **fix-loop** | review-gate → builder fixes → re-gate (bounded) | turning findings into a verified **PASS** |
| **migrate-stack** | capture golden tests → architect → builder/data-engineer → verify parity → gate | **porting any language/framework to any other** (Java→Node, Python→Go, …) with proven behavioral parity |
| **upgrade-runtime** | baseline → bump → codemods → deprecation sweep → parity → CI/Docker align | **major runtime/platform upgrade** (Node 18→22, JDK 8→17, Python major) |

---

## Slash commands (plugin installs)

Agents are delegated to, not typed as commands — so the plugin ships thin workflow skills as
explicit entry points. They run in the main conversation (full delegation depth), name the
flow, and hand off to the orchestrators above. They only run when you type them.

| Command | Runs |
|---|---|
| `/sdlc-agents:start <task>` | `route` → the planned sequence, on your go |
| `/sdlc-agents:new-project <brief>` | `ship-it` (or `takehome-runner` for graded exercises) |
| `/sdlc-agents:feature <change>` | `onboard` if unmapped → `feature-dev` → `pr-ready` |
| `/sdlc-agents:fix <symptom>` | `debugger` → `pr-ready` |
| `/sdlc-agents:migrate <src> to <target>` | `onboard` → `migrate-stack` → `parity-gate` → `review-gate` |
| `/sdlc-agents:upgrade <version>` | `onboard` if unmapped → `upgrade-runtime` → `parity-gate` → `release-devops` |
| `/sdlc-agents:review [target]` | `review-gate` → `fix-loop` on request |
| `/sdlc-agents:release [target]` | `production-gate` → `fix-loop` on request |

With the manual `install.sh`, skills aren't installed — say "Use the route agent…" instead.

## Which do I use?

**Not sure? Start with `route`.** Describe the task and it picks the agent(s), lays out the
ordered workflow with the exact invocations, names the one orchestrator that covers it (if
any), and offers to run the sequence:
```
Use the route agent. <describe your task + optional repo path>
```
Or pick directly:

- **New project** → `ship-it` (or `takehome-runner` for an exercise)
- **Change / feature on existing code** → `feature-dev`
- **Something's broken** → `debugger`
- **Unfamiliar / legacy repo — map it before editing** → `onboard`
- **Clean up / internal refactor / dep bumps** → `refactorer`
- **Major runtime upgrade (Node 18→22, JDK, Python major)** → `upgrade-runtime`
- **Port to another language/stack (e.g. Java→Node)** → `migrate-stack`
- **It's slow / leaking** → `performance-engineer`
- **DB / schema / migration / slow query** → `data-engineer`
- **UI usable by everyone** → `accessibility`
- **Privacy / regulatory** → `compliance-privacy`
- **Cloud bill too high** → `finops-cost`
- **Pipeline / deploy / rollback** → `release-devops`
- **About to commit** → `pr-ready`
- **Full review** → `review-gate` · **fix what it finds** → `fix-loop`
- **Before a real release** → `production-gate`
- **Prove behavior unchanged after an upgrade / port / refactor** → `parity-gate`
- **Document it** → `tech-writer`

**Gate = read-only (safe to trust); pipeline/loop = writes.** That separation is the
point — a gate can never quietly change your code to pass itself.

---

## Coverage map (every production check has an owner)

| Check | Owner |
|---|---|
| Security / vulnerabilities | `security-reviewer` |
| Supply-chain / Dependabot | `security-reviewer` flags · `release-devops` configures · `production-gate` verifies |
| Race conditions | `qa-test-engineer` + `senior-auditor` |
| Performance / bottlenecks / memory leaks | `performance-engineer` |
| Database / schema / migrations / queries | `data-engineer` |
| Accessibility (WCAG) | `accessibility` |
| Privacy / compliance | `compliance-privacy` |
| Cloud cost | `finops-cost` |
| CI/CD · release · rollback · IaC | `release-devops` |
| Unit tests | `senior-builder` / `feature-dev` write · `qa` extends |
| Automation / integration / e2e | `qa-test-engineer` |
| Coverage gate · build · lint · typecheck · CI | `production-gate` (verifies by running) |
| Production readiness | `sre-reliability` + `hardening-gate` + `production-gate` |

---

## Deterministic enforcement & tooling (beyond the prompts)

Markdown agents are *advisory*; these layers are *deterministic* / infrastructural:

- **Global secrets deny-list** — `~/.claude/settings.json` denies `Read` **and `Grep`** on
  `.env*`, keys, and secrets across every project (`.env.example` stays readable).
  Installed.
- **Per-project templates** (`templates/`, copy into each repo — not auto-installed; clean
  valid JSON, no comment keys; need `jq`):
  - `settings.json` (plugin companion, the default) — only the secrets deny-list and the
    opt-in Stop test gate, because the plugin already registers the other hooks and
    wiring them twice would make each fire twice.
  - `settings.standalone.json` (`setup-project.sh --standalone`, for projects without the
    plugin) — the deny-list plus hooks that call the scripts in the plugin's `hooks/` (the
    single source — `setup-project.sh` copies them into the project's `.claude/hooks/`):
    - PreToolUse: **fail-closed** block of edits to secrets/lockfiles/tracked migrations;
      `guard-secrets.sh` (Read/Grep of secret files); `guard-bash.sh` (force-push,
      recursive `rm` on root/home/wildcard targets, DROP/TRUNCATE through a DB client,
      `dropdb`/`db:drop`/`prisma migrate reset`, printing secrets or the environment).
    - PostToolUse → `format.sh` (formats by file type).
    - Stop → `verify.sh` (**auto-detects every stack present**, root and depth-1 — Node,
      Py, Java, Go, Rust — and runs each one's tests; `stop_hook_active` loop-protection +
      `git status` no-op skip). Opt-in per project, which is why it isn't in the plugin.
    - SessionStart → `session-start.sh` (branch, detected stacks, runtime versions, ledger,
      and a hint when Java and Node coexist); PreCompact (flush-the-ledger reminder).
  - `rules/` — path-scoped rules (TS/JS, Java, Python, Go) that load only for matching
    files, so a hybrid Java→Node repo gets the right conventions per file.
  - `.worktreeinclude` — copies `.env`-style gitignored files into a
    `claude --worktree <name>` session, the recommended way to run a port or upgrade off
    the main tree.
  - `.mcp.json` — pinned **context7** + **playwright** (real browser for
    `qa`/`accessibility`). The plugin itself auto-wires only context7; playwright stays
    opt-in because it launches browsers.
  - Install them into a project with `templates/setup-project.sh [--standalone]
    [project-dir]` (copies the files, makes the hooks executable, won't clobber existing
    config, refuses a nonexistent path). The global `install.sh` installs **agents** only —
    per-project hooks are separate by design.
  - In target projects, the `.claude/state/` ledger is tracked by git by default, which is
    intended: migration state is shared across the team and survives branch switches.
  - See `templates/README.md` for details.

## Model routing (cost vs. judgment)

Each agent pins a `model:` so the bundle is predictable regardless of the session default:
- **`opus`** (12) — judgment-critical: senior-architect, senior-builder, feature-dev,
  debugger, refactorer, senior-auditor, security-reviewer, qa-test-engineer,
  performance-engineer, data-engineer, migrate-stack, upgrade-runtime.
- **`sonnet`** (17) — orchestration / advisory / ops / docs: route, onboard, all 6 gates,
  ship-it, takehome-runner, fix-loop, sre-reliability, release-devops, tech-writer,
  compliance-privacy, accessibility, finops-cost.

`effort: high` is set on senior-architect, senior-auditor, and migrate-stack.
`memory: project` is set on senior-architect and onboard, so they keep architectural
decisions and repo maps across sessions (stored in the project's `.claude/agent-memory/`).

Rationale: never downgrade an agent that writes or deeply reviews code; save cost on
orchestration and advisory work (the gates delegate the heavy lifting to the `opus`
specialists anyway). Edit any `model:` line to re-tune.

## Roster at a glance

**17 specialists** · **12 orchestrators** = **29 agents** · entry point: **`route`**

Specialists: senior-architect · senior-builder · feature-dev · debugger · refactorer ·
onboard · senior-auditor · security-reviewer · qa-test-engineer · performance-engineer ·
accessibility · data-engineer · compliance-privacy · finops-cost · release-devops ·
sre-reliability · tech-writer

Orchestrators: route (router / entry point) · pr-ready · review-gate · design-gate ·
hardening-gate · production-gate · parity-gate · ship-it · takehome-runner · feature-dev* ·
fix-loop · migrate-stack · upgrade-runtime
(*feature-dev is both a brownfield pipeline and the go-to for existing-code changes.)

---

## License

MIT — see [LICENSE](LICENSE). Free to use, modify, and redistribute.
