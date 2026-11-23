---
paths:
  - "**/*.java"
---
# Java rules

A floor, not a style guide — where this project already has a convention, follow it.

- Types: no raw generic types; no unchecked casts except with a one-line, justified
  `@SuppressWarnings`.
- Nulls: return `Optional` for "may be absent"; don't use `Optional` as a parameter or field.
- Money: `BigDecimal` with an explicit scale and `RoundingMode`; never `double`.
- Resources: try-with-resources for anything `AutoCloseable`.
- Exceptions: no empty catch blocks; don't catch `Exception`/`Throwable` broadly except at a
  boundary that logs and maps or rethrows.
- Concurrency: prefer `java.util.concurrent` over hand-rolled synchronization; document
  thread-safety on shared types.
