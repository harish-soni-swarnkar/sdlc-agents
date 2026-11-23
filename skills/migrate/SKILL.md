---
name: migrate
description: Port a system to another language or stack (Java→Node, Python→Go, …) with proven behavioral parity — golden baseline first, strangler-fig port, parity gate before cutover.
argument-hint: <source path/stack> to <target stack> [intended differences]
disable-model-invocation: true
---
Migration: $ARGUMENTS

Runs in the main conversation, so it can delegate to the crew at full depth. In plugin installs the agents are namespaced as `sdlc-agents:<name>`. Pass each step's output to the next, and stop at any gate verdict of FAIL / NOT-READY / NO-GO / DIVERGENCES-FOUND — report it instead of continuing.

1. If the source has no ARCHITECTURE.md inventory yet, run `onboard` on it.
2. Run `migrate-stack`, passing the inventory. It owns the whole port: golden baseline
   (qa-test-engineer), target design, slice-by-slice port, `.claude/state/MIGRATION_STATE.md`,
   and its own `parity-gate` and `review-gate` runs. Don't run those gates again here.
3. Report its verdicts. Cutover needs PARITY-HELD. Only if it reports that a gate didn't run
   (for example, it hit the nesting-depth limit) run that one gate yourself.
4. Ask before cutover or decommissioning the source. Best started inside
   a worktree session (`claude --worktree <name>`) so the port stays off the main working tree.
