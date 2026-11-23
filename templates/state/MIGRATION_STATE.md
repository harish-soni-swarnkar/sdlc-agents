# Migration state — <source stack> → <target stack>

Living ledger for a cross-stack port. `migrate-stack` creates it at
`.claude/state/MIGRATION_STATE.md` when a port starts and updates it after every slice;
`parity-gate` reads "Intended differences" from it. Keep it committed so the team and every
new session resume with zero drift.

## Status
- Phase: <baseline | porting | parity | cutover | done>
- Last updated: <date> — <who / which session>

## Golden baseline
- Location: <path to the characterization suite / recorded snapshots>
- Captured against: <source commit / version>

## Target mappings
| Source component | Target component | Notes |
|---|---|---|

## Completed slices
| Slice | Parity verdict | Cutover state (flag / route / shadow) | Date |
|---|---|---|---|

## Intended differences
<Every deliberate behavior change from the source, approved. Anything not listed must match.>

## Decisions
<Architectural decisions made during the port, with the reason — e.g. "BigDecimal → decimal.js across billing".>

## Cutover & rollback
- Strategy per slice: <feature flag | proxy route | shadow traffic | dual-write>
- Rollback position: <how to flip back right now>

## Blockers
