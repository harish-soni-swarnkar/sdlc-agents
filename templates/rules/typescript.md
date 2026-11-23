---
paths:
  - "**/*.{ts,tsx,mts,cts,js,jsx,mjs,cjs}"
---
# TypeScript / JavaScript rules

A floor, not a style guide — where this project already has a convention, follow it.

- Types: `strict` tsconfig; no `any` (use `unknown` and narrow); explicit return types on
  exported functions; no non-null `!` to silence the checker; no `@ts-ignore` (if truly
  unavoidable, `@ts-expect-error` with the reason).
- Boundaries: validate external input (HTTP bodies, env, files, queue messages) with a
  schema (e.g. Zod) and derive the type from it.
- Modules: match the package's module type (`"type"` in package.json); don't mix `require`
  and `import` in one package.
- Async: no floating promises — await or explicitly handle every one.
- Money and precision: never floating point for currency — integer minor units or a decimal
  library.
- Porting from Java: use the TS/Node idiom, don't transliterate Java patterns (getter/setter
  classes, interface-per-class, checked-exception wrappers).
