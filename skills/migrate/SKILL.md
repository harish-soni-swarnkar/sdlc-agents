---
name: migrate
description: Port a system to another language or stack (Java→Node, Python→Go, …) with proven behavioral parity — golden baseline first, strangler-fig port, parity gate before cutover.
argument-hint: <source path/stack> to <target stack> [intended differences]
disable-model-invocation: true
---
Migration: $ARGUMENTS

Runs in the main conversation, so it can delegate to the crew at full depth. In plugin installs the agents are namespaced as `sdlc-agents:<name>`. Pass each step's output to the next, and stop at any gate verdict of FAIL / NOT-READY / NO-GO / DIVERGENCES-FOUND — report it instead of continuing.

1. Run `onboard` on the source so the port is planned from an ARCHITECTURE.md inventory.
2. Run `migrate-stack`. It captures the golden baseline (qa-test-engineer), designs the target,
   ports slice by slice, and keeps `.claude/state/MIGRATION_STATE.md` current.
3. Run `parity-gate` — cutover needs PARITY-HELD. Then `review-gate` on the target.
4. Ask before cutover or decommissioning the source. Best started inside
   a worktree session (`claude --worktree <name>`) so the port stays off the main working tree.
