# Global engineering rules

These apply to all code I ask you to write or change, in **any** programming or
scripting language. They exist to prevent hallucinated code and enforce type safety.

## 1. Context anchoring (anti-hallucination)
Before writing code that uses any interface, type, schema, function, constant, CLI
flag, config key, or library/API symbol, **confirm it actually exists and get its real
signature** — read it from the codebase (open the file / grep for it) or from official
documentation. Never invent, guess, or assume an API, field name, or signature. If you
cannot verify a symbol, say so and stop or ask — do not fabricate it.
- Restate the real interfaces, schemas, and existing utilities you are building against
  before you generate the implementation.
- Prefer reusing an existing utility/type over inventing a parallel one.

## 2. Strict typing (every language)
Use the **strictest type checking the language offers**, with explicit types at every
boundary and return value. No untyped escape hatches without a stated, justified reason.
- **TypeScript:** `strict` mode on; no `any` (and no implicit `any`); explicit function
  return types; prefer `unknown` + narrowing over `any`.
- **Python:** full type hints; pass `mypy`/`pyright` in strict mode; no bare `Any` as a
  shortcut.
- **Statically typed (Go, Rust, Java, C#, Kotlin, Swift, C/C++):** no unchecked casts or
  `interface{}`/`Object`/`void*` shortcuts to dodge the type system; handle errors, don't
  discard them.
- **Dynamic / untyped (JS, untyped Python, Ruby, PHP, Lua, shell):** validate inputs and
  outputs **at the boundary** with a schema/validator (e.g. Zod/Pydantic) or explicit
  assertions; keep internal contracts explicit.

## 3. Test-first verification
Define the **interface/contract and its test suite first**, then write the implementation
until the tests pass. Use the project's existing test framework (Jest/Vitest, pytest, Go
test, cargo test, JUnit, etc.). **Run the tests** — passing tests are the proof a change
works, not an assertion that it does. Never report code as working without running it.

---
These rules come from the sdlc-agents portable edition. Its skills apply them (start
with the `route` skill if you're unsure which skill fits a task).

## Safety rules (always)
Other tools can't enforce these with hooks the way the Claude Code edition does, so follow
them as rules:
- Never read, print, search, or copy the contents of secret files (`.env`, `.env.*` other
  than `.env.example`, `*.pem`, `*.key`, `id_rsa`, `~/.ssh/`, `~/.aws/credentials`,
  `secrets/`). Refer to a key by name, never by value.
- Never force-push (`git push --force` / `-f`); use `--force-with-lease` only when asked.
- Never run a recursive delete on a root, home, or wildcard target, and never run
  destructive SQL (DROP / TRUNCATE) or database resets — write a reviewed migration with a
  rollback instead.
- Never edit an existing (committed) migration — create a new one. Never hand-edit a
  lockfile — regenerate it with the package manager.
