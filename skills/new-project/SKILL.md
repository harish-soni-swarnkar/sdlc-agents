---
name: new-project
description: Build a new project from a brief — design, build, three-lens review, ops readiness, docs. Uses takehome-runner for graded exercises, ship-it otherwise.
argument-hint: <brief, or path to the brief/exercise>
disable-model-invocation: true
---
Brief: $ARGUMENTS

Runs in the main conversation, so it can delegate to the crew at full depth. In plugin installs the agents are namespaced as `sdlc-agents:<name>`. Pass each step's output to the next, and stop at any gate verdict of FAIL / NOT-READY / NO-GO / DIVERGENCES-FOUND — report it instead of continuing.

1. If this is a graded exercise or take-home, run `takehome-runner`; otherwise run `ship-it`.
   Both chain senior-architect → senior-builder → review-gate → sre-reliability → tech-writer.
2. Stop at the architect's open questions and at a review-gate FAIL; ask before continuing.
3. Report what shipped, the gate verdicts, and the known gaps.
