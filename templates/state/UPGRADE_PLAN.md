# Upgrade plan — <runtime> <from> → <to>

Living ledger for a runtime/platform upgrade. `upgrade-runtime` creates it at
`.claude/state/UPGRADE_PLAN.md` when an upgrade starts and updates it after every stage;
`parity-gate` reads "Intended differences" from it. Keep it committed.

## Status
- Stage: <audit | baseline | bump | codemods | deprecations | parity | ci-align | done>
- Last updated: <date> — <who / which session>

## Golden baseline
- Location: <path to the characterization suite>
- Captured on: <old runtime version>

## Version pins changed
| File / setting | Old | New |
|---|---|---|

## Dependencies
| Package | Problem (deprecated / abandoned / incompatible / native addon) | Action |
|---|---|---|

## Deprecations
- Resolved: <list>
- Deferred (conscious, temporary): <list with reason>

## Intended differences
<Behavior changes the new runtime forces, recorded explicitly. Anything not listed must match.>

## Blockers
