---
name: upgrade
description: Upgrade a major runtime or platform version (Node 18→22, JDK 8→17, Python major) — baseline, bump, codemods, deprecation sweep, parity proof, CI/Docker alignment.
argument-hint: <target version, e.g. "Node 22"> [repo path]
disable-model-invocation: true
---
Upgrade: $ARGUMENTS

Runs in the main conversation, so it can delegate to the crew at full depth. In plugin installs the agents are namespaced as `sdlc-agents:<name>`. Pass each step's output to the next, and stop at any gate verdict of FAIL / NOT-READY / NO-GO / DIVERGENCES-FOUND — report it instead of continuing.

1. If this repo hasn't been mapped yet, run `onboard` first.
2. Run `upgrade-runtime` with the target version. It owns the whole upgrade: dependency
   audit, baseline, lockstep version bumps, deprecation sweep,
   `.claude/state/UPGRADE_PLAN.md`, and its own `parity-gate` and `release-devops` runs.
   Don't run those again here.
3. Report its verdicts. Only if it reports that a step didn't run (for example, it hit the
   nesting-depth limit) run that one step yourself. Best started inside a worktree session
   (`claude --worktree <name>`) so the upgrade stays off the main working tree.
