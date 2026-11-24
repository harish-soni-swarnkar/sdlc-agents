---
name: start
description: "Entry point. Describe any task; the route agent picks the right agents and order, then the sequence runs from the main conversation on your go."
argument-hint: "<describe the task, optionally a repo path>"
disable-model-invocation: true
---
Task: $ARGUMENTS

Runs in the main conversation, so it can delegate to the crew at full depth. In plugin installs the agents are namespaced as `sdlc-agents:<name>`. Pass each step's output to the next, and stop at any gate verdict of FAIL / NOT-READY / NO-GO / DIVERGENCES-FOUND — report it instead of continuing.

1. Run the `route` agent with the task above. It classifies the work and lays out the
   ordered workflow with one invocation per step.
2. Show the plan and ask the user to confirm before running anything that writes code.
3. On go, run each step yourself via the Agent tool, one agent per step, in order.
