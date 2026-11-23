---
name: upgrade
description: Upgrade a major runtime or platform version (Node 18→22, JDK 8→17, Python major) — baseline, bump, codemods, deprecation sweep, parity proof, CI/Docker alignment.
argument-hint: <target version, e.g. "Node 22"> [repo path]
disable-model-invocation: true
---
Upgrade: $ARGUMENTS

Runs in the main conversation, so it can delegate to the crew at full depth. In plugin installs the agents are namespaced as `sdlc-agents:<name>`. Pass each step's output to the next, and stop at any gate verdict of FAIL / NOT-READY / NO-GO / DIVERGENCES-FOUND — report it instead of continuing.

1. If this repo hasn't been mapped yet, run `onboard` first.
2. Run `upgrade-runtime` with the target version. It audits dependencies, captures the
   baseline, bumps every environment, sweeps deprecations, and keeps
   `.claude/state/UPGRADE_PLAN.md` current.
3. Run `parity-gate` (old vs new runtime); then `release-devops` if CI/Docker still need
   aligning. Prefer an isolated git worktree.
