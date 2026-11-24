---
name: engineering-rules
description: "Global engineering discipline for writing or changing code in ANY language — context anchoring (verify every API/type/symbol exists before using it; no hallucinated signatures), strict typing at boundaries, and test-first verification. Apply whenever generating, editing, refactoring, migrating, or reviewing code."
license: MIT
compatibility: "Agent Skills open standard (agentskills.io). Part of the sdlc-agents portable set: install the whole set, since skills refer to each other by name. Uses git and the project's own build/test tooling."
metadata:
  source: "skills/engineering-rules/SKILL.md"
  edition: "portable"
---
# Engineering rules (all languages)

Prevent hallucinated code and enforce type safety. (The same rules ship as
`AGENTS.md` for tools that load it always-on; this skill is the on-demand copy.)

## 1. Context anchoring (anti-hallucination)
Before writing code that uses any interface, type, schema, function, constant, CLI flag,
config key, or library/API symbol, **confirm it actually exists and get its real
signature** — read it from the codebase (open the file / grep) or official docs. Never
invent, guess, or assume an API, field name, or signature. If you cannot verify a symbol,
say so and stop or ask. Restate the real interfaces/schemas you build against; prefer
reusing an existing utility over inventing a parallel one.

## 2. Strict typing (every language)
Use the strictest type checking the language offers, with explicit types at every boundary
and return value. No untyped escape hatches without a stated reason.
- **TypeScript:** `strict`; no `any`/implicit any; explicit return types; prefer `unknown`.
- **Python:** full type hints; `mypy`/`pyright` strict; no bare `Any` shortcut.
- **Statically typed (Go, Rust, Java, C#, Kotlin, Swift, C/C++):** no unchecked casts or
  `interface{}`/`Object`/`void*` dodges; handle errors, don't discard them.
- **Dynamic (JS, untyped Python, Ruby, PHP, Lua, shell):** validate inputs/outputs at the
  boundary with a schema/validator (Zod/Pydantic) or explicit assertions.

## 3. Test-first verification
Define the interface/contract and its test suite first, then implement until the tests
pass, using the project's framework (Jest/Vitest, pytest, go test, cargo test, JUnit…).
**Run the tests** — passing tests are the proof, not an assertion. Never report code as
working without running it.
