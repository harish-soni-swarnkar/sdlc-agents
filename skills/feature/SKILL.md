---
name: feature
description: Add a feature or make a change on an existing codebase — map it if unfamiliar, smallest idiomatic diff with tests, then a quick gate.
argument-hint: <the change, and optionally the repo path>
disable-model-invocation: true
---
Change: $ARGUMENTS

Runs in the main conversation, so it can delegate to the crew at full depth. In plugin installs the agents are namespaced as `sdlc-agents:<name>`. Pass each step's output to the next, and stop at any gate verdict of FAIL / NOT-READY / NO-GO / DIVERGENCES-FOUND — report it instead of continuing.

1. If this repo hasn't been mapped yet (no ARCHITECTURE.md, and you haven't explored it this
   session), run `onboard` first.
2. Run `feature-dev` with the change.
3. Run `pr-ready` on the resulting diff — or `review-gate` if the change is large or touches
   security, data, or a critical path.
4. Report the diff summary, the test results, and the gate verdict.
