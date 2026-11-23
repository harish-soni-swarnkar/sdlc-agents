---
name: release
description: Pre-release production gate — full battery of lenses plus proof that tests, coverage, scans, and CI actually pass, as one READY / NOT-READY verdict.
argument-hint: [target] [context: public/internal, SLA, load, data sensitivity]
disable-model-invocation: true
---
Release: $ARGUMENTS

Runs in the main conversation, so it can delegate to the crew at full depth. In plugin installs the agents are namespaced as `sdlc-agents:<name>`. Pass each step's output to the next, and stop at any gate verdict of FAIL / NOT-READY / NO-GO / DIVERGENCES-FOUND — report it instead of continuing.

1. Run `production-gate` with the target and production context.
2. If the verdict is NOT-READY or CONDITIONAL, list the blockers and ask whether to run
   `fix-loop` on them.
