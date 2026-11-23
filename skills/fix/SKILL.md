---
name: fix
description: Diagnose and fix a bug, crash, flaky test, or incident at its root cause, with a regression test, then a quick gate.
argument-hint: <symptom, error, failing test, or incident notes>
disable-model-invocation: true
---
Symptom: $ARGUMENTS

Runs in the main conversation, so it can delegate to the crew at full depth. In plugin installs the agents are namespaced as `sdlc-agents:<name>`. Pass each step's output to the next, and stop at any gate verdict of FAIL / NOT-READY / NO-GO / DIVERGENCES-FOUND — report it instead of continuing.

1. Run `debugger` with the symptom. It reproduces, proves the root cause, applies the minimal
   fix, and adds a regression test that fails before and passes after.
2. If the root cause is still a leading hypothesis, stop and report — don't ship a guessed fix.
3. Run `pr-ready` on the fix diff and report the verdict.
