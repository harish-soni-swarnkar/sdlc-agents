---
paths:
  - "**/*.go"
---
# Go rules

A floor, not a style guide — where this project already has a convention, follow it.

- Errors: check every error; wrap with `%w` and context; never discard one with `_ =`
  without a comment saying why.
- Types: no `interface{}`/`any` to dodge the type system — use concrete types or generics.
- Context: take `context.Context` as the first parameter for I/O and honor cancellation.
- Concurrency: every goroutine has an owner and an exit path; no unbounded spawning; run
  tests with `-race`.
- `gofmt` and `go vet` clean.
