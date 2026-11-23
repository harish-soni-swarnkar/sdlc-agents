---
name: review
description: Full three-lens review (quality, security, adversarial QA) with one merged verdict; optionally fix the findings and re-verify.
argument-hint: [target — path, branch, PR, or diff; defaults to the current changes]
disable-model-invocation: true
---
Target: $ARGUMENTS (if empty, review the current branch's changes)

Runs in the main conversation, so it can delegate to the crew at full depth. In plugin installs the agents are namespaced as `sdlc-agents:<name>`. Pass each step's output to the next, and stop at any gate verdict of FAIL / NOT-READY / NO-GO / DIVERGENCES-FOUND — report it instead of continuing.

1. Run `review-gate` on the target. It merges senior-auditor, security-reviewer, and
   qa-test-engineer into one PASS / CONDITIONAL / FAIL verdict.
2. If the verdict isn't PASS, ask whether to fix. On yes, run `fix-loop` (bounded; it asks
   before its first edit).
